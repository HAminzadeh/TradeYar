#!/usr/bin/env python3
"""Verify + idempotently synchronize archived MT5 bars to PostgreSQL (psycopg 3).

Uses local _manifest.json; skips SHA-256 imports already committed, preserves conflicting
bar revisions, and never downloads anything. Atomic transaction per monthly shard.
"""
import argparse,csv,hashlib,json,os,re,sys,uuid
from datetime import datetime,timezone,date
from decimal import Decimal,InvalidOperation
from pathlib import Path

TIMEFRAMES={'M1','M5','M15','M30','H1','H4','D1','W1','MN1'}
SYMBOLS={'EURUSD','GBPUSD','USDJPY','XAUUSD'}
HEAD=['time','open','high','low','close','volume']

def sha256(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def read_and_validate(path,entry):
    rows=[];last=0
    with path.open(newline='',encoding='utf-8-sig') as f:
        reader=csv.DictReader(f)
        if reader.fieldnames!=HEAD:raise ValueError('Unexpected CSV columns: '+str(path))
        for r in reader:
            ts=int(r['time']);o,h,l,c=[Decimal(r[x]) for x in ['open','high','low','close']];vol=int(r['volume'])
            if ts<=last or ts>datetime.now(timezone.utc).timestamp()+300 or vol<0 or any(not x.is_finite() or x<=0 for x in (o,h,l,c)) or l>min(o,c) or h<max(o,c) or l>h:
                raise ValueError('Malformed/duplicate bar in '+str(path))
            rows.append((datetime.fromtimestamp(ts,timezone.utc),o,h,l,c,vol));last=ts
    if len(rows)!=entry['bars']:raise ValueError('Bar count mismatch: '+path.name)
    if not rows:raise ValueError('Unexpected empty historical shard')
    return rows

def verified_shards(root,only_months=None):
    # Windows TEMP can use 8.3 short aliases (e.g. C:\Users\ABC123~1), while
    # Path.resolve() below expands filenames to long paths. Compare canonical
    # directories to avoid falsely rejecting intact monthly archive shards.
    root=Path(root).expanduser().resolve(strict=True)
    manifest=json.loads((root/'_manifest.json').read_text(encoding='utf-8'))
    symbol=manifest.get('symbol');frame=manifest.get('timeframe')
    if symbol not in SYMBOLS or frame not in TIMEFRAMES:raise ValueError('Unknown symbol or timeframe in manifest')
    valid=[];seen=set()
    for e in manifest.get('periods',[]):
        month=e.get('month','')
        if not re.fullmatch(r'\d{4}-(0[1-9]|1[0-2])',month):raise ValueError('Invalid period')
        if month in seen:raise ValueError('Duplicate month manifest entry: '+month)
        seen.add(month)
        if not e.get('bars'):continue
        if only_months is not None and month not in only_months:continue
        filename=e.get('relativePath','')
        if filename!=month+'.csv':raise ValueError('Invalid shard name')
        path=(root/filename).resolve()
        if path.parent!=root or not path.is_file():raise ValueError('Missing or escaping shard '+filename)
        digest=sha256(path)
        if digest!=e.get('sha256'):raise ValueError('SHA mismatch: '+filename)
        rows=read_and_validate(path,e)
        valid.append((month,path,digest,e,rows))
    return manifest,valid

def import_folder(folder,dsn=None,only_months=None):
    root=Path(folder).expanduser().resolve()
    manifest,shards=verified_shards(root,only_months=only_months)
    dsn=dsn or os.getenv('TRADEYAR_PG_DSN')
    if not dsn:raise RuntimeError('TRADEYAR_PG_DSN not configured; files validated and retained locally')
    try:import psycopg
    except ImportError as ex:raise RuntimeError('Install approved psycopg>=3 package before PostgreSQL import') from ex
    inserted=0;skipped=0;conflicts=0;sync_id=str(uuid.uuid4());symbol=manifest['symbol'];frame=manifest['timeframe']
    with psycopg.connect(dsn,connect_timeout=8) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute('INSERT INTO tradeyar_research.data_sync_runs_v06(sync_id,source_type) VALUES(%s,%s)',(sync_id,'MONTHLY_OHLC'))
        for month,path,digest,entry,rows in shards:
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute('SELECT bar_count FROM tradeyar_research.history_imports WHERE import_sha256=%s',(digest,))
                    stored=cur.fetchone()
                    if stored:
                        if stored[0]!=len(rows):raise ValueError('Same content hash recorded with different bar count')
                        skipped+=1
                    else:
                        cur.execute('INSERT INTO tradeyar_research.history_imports(import_sha256,symbol,timeframe,file_name,bar_count,provider,verified_provenance) VALUES(%s,%s,%s,%s,%s,%s,FALSE)',
                                    (digest,symbol,frame,path.name,len(rows),manifest['source']))
                        cur.execute('CREATE TEMP TABLE tradeyar_stage (event_at TIMESTAMPTZ,o NUMERIC(22,10),h NUMERIC(22,10),l NUMERIC(22,10),c NUMERIC(22,10),volume BIGINT) ON COMMIT DROP')
                        with cur.copy('COPY tradeyar_stage(event_at,o,h,l,c,volume) FROM STDIN') as cp:
                            for row in rows:cp.write_row(row)
                        cur.execute('''INSERT INTO tradeyar_research.history_bar_revisions(symbol,timeframe,event_at,import_sha256,o,h,l,c,volume)
                          SELECT %s,%s,s.event_at,%s,s.o,s.h,s.l,s.c,s.volume FROM tradeyar_stage s
                          JOIN tradeyar_research.history_bars x ON x.symbol=%s AND x.timeframe=%s AND x.event_at=s.event_at
                          WHERE (x.o,x.h,x.l,x.c,x.volume) IS DISTINCT FROM (s.o,s.h,s.l,s.c,s.volume)
                          ON CONFLICT DO NOTHING''',(symbol,frame,digest,symbol,frame))
                        conflicts+=cur.rowcount
                        cur.execute('''INSERT INTO tradeyar_research.history_bars(symbol,timeframe,event_at,o,h,l,c,volume,import_sha256)
                          SELECT %s,%s,s.event_at,s.o,s.h,s.l,s.c,s.volume,%s FROM tradeyar_stage s WHERE TRUE
                          ON CONFLICT(symbol,timeframe,event_at) DO NOTHING''',(symbol,frame,digest))
                        inserted+=cur.rowcount
                    first=datetime.fromisoformat(entry['windowStartUtc']) if entry.get('windowStartUtc') else datetime.fromisoformat(month+'-01T00:00:00+00:00')
                    end=datetime.fromisoformat(entry['windowEndUtc']) if entry.get('windowEndUtc') else datetime.fromisoformat(month+'-28T23:59:59+00:00')
                    cur.execute('''INSERT INTO tradeyar_research.history_collection_periods(symbol,timeframe,period_month,window_start_utc,window_end_utc,status,source,row_count,latest_import_sha256)
                      VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
                      ON CONFLICT(symbol,timeframe,period_month) DO UPDATE SET
                      window_start_utc=EXCLUDED.window_start_utc,window_end_utc=EXCLUDED.window_end_utc,
                      status=EXCLUDED.status,source=EXCLUDED.source,row_count=EXCLUDED.row_count,
                      latest_import_sha256=EXCLUDED.latest_import_sha256,checked_at=now()''',
                      (symbol,frame,month+'-01',first,end,'PARTIAL' if entry['status']=='PARTIAL' else 'IMPORTED',manifest['source'],len(rows),digest))
            print(f'{month}: DB committed; {len(rows)} archived bars; {"cached" if stored else "new shard"}',flush=True)
        # Persist known gaps too; no silent claims of ten-year coverage.
        with conn.transaction():
            with conn.cursor() as cur:
                for e in manifest.get('periods',[]):
                    if e.get('bars'):continue
                    month=e['month'];first=datetime.fromisoformat(month+'-01T00:00:00+00:00')
                    right=datetime(first.year+(first.month==12),first.month%12+1,1,tzinfo=timezone.utc)
                    cur.execute('''INSERT INTO tradeyar_research.history_collection_periods
                      (symbol,timeframe,period_month,window_start_utc,window_end_utc,status,source,row_count)
                      VALUES(%s,%s,%s,%s,%s,'MISSING',%s,0)
                      ON CONFLICT(symbol,timeframe,period_month) DO UPDATE SET
                      status='MISSING',checked_at=now()
                      WHERE tradeyar_research.history_collection_periods.row_count=0''',
                      (symbol,frame,month+'-01',first,right,manifest['source']))
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute('UPDATE tradeyar_research.data_sync_runs_v06 SET finished_at=now(),files_checked=%s,rows_inserted=%s,discrepancies=%s,note=%s WHERE sync_id=%s',
                           (len(shards),inserted,conflicts,'All data comes from a locally logged-in MT5 export; broker provenance unverified',sync_id))
    print(f'[SYNC] inserted={inserted}, skippedShards={skipped}, preservedRevisions={conflicts}, run={sync_id}')
    return {'rowsInserted':inserted,'shardsAlreadyImported':skipped,'revisionsPreserved':conflicts,'syncId':sync_id}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--folder',required=True,help='Symbol/timeframe folder with _manifest.json')
    p.add_argument('--verify-only',action='store_true')
    args=p.parse_args();root=Path(args.folder).expanduser().resolve()
    try:
        manifest,shards=verified_shards(root)
        print(f'[CHECK] {len(shards)} verified history shards, {sum(len(x[-1]) for x in shards)} bars')
        if args.verify_only:return 0
        import_folder(root)
        return 0
    except Exception as e:print('[FAILED]',str(e),file=sys.stderr);return 2

if __name__=='__main__':raise SystemExit(main())
