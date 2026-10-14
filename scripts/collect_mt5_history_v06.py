#!/usr/bin/env python3
"""Resume-safe read-only MT5 OHLC archive, by UTC month (not market-order code).

Existing verified historical shards are reused without another MT5 download.
The active month is refreshed and merged; prior revisions are saved under _revisions/.
A local immutable archive remains usable when PostgreSQL is offline. An optional
TRADEYAR_PG_DSN triggers an automatic synchronization after collection.
"""
import argparse
import calendar
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

SYMBOLS={'EURUSD','GBPUSD','USDJPY','XAUUSD'}
FRAMES={'M1','M5','M15','M30','H1','H4','D1','W1','MN1'}
HEADER=['time','open','high','low','close','volume']
FRAME_SECONDS={'M1':60,'M5':300,'M15':900,'M30':1800,'H1':3600,'H4':14400,'D1':86400,'W1':604800}

def definitely_closed(ts,frame,asof):
    # Conservative completion check. MT5 exchange/broker session boundaries still
    # require independent validation for daily and larger frames.
    if frame=='MN1':
        moment=datetime.fromtimestamp(ts,timezone.utc)
        end=datetime(moment.year+(moment.month==12),moment.month%12+1,1,tzinfo=timezone.utc)
        return end<=asof
    return ts+FRAME_SECONDS[frame]<=asof.timestamp()


def utc_months(start,end):
    year,month=start.year,start.month
    while (year,month)<=(end.year,end.month):
        left=datetime(year,month,1,tzinfo=timezone.utc)
        right=datetime(year+(month==12),month%12+1,1,tzinfo=timezone.utc)
        if left<end and right>start:yield left,max(left,start),min(right,end),right
        year,month=right.year,right.month

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def read_rows(path):
    rows={};last=-1
    with path.open(newline='',encoding='utf-8-sig') as f:
        reader=csv.DictReader(f)
        if reader.fieldnames!=HEADER:raise ValueError('Unexpected CSV columns: '+str(path))
        for row in reader:
            ts=int(row['time']);o=float(row['open']);h=float(row['high']);l=float(row['low']);c=float(row['close']);v=int(row['volume'])
            if ts<=last or not all(map(__import__('math').isfinite,(o,h,l,c))) or min(o,h,l,c)<=0 or l>min(o,c) or h<max(o,c) or v<0:
                raise ValueError('Invalid, unordered or duplicated bar: '+str(path))
            rows[ts]=(ts,o,h,l,c,v);last=ts
    return rows

def write_atomic(path,rows):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix='.tradeyar-',suffix='.csv',dir=str(path.parent))
    try:
        with os.fdopen(fd,'w',newline='',encoding='utf-8') as f:
            w=csv.writer(f,lineterminator='\n');w.writerow(HEADER);w.writerows(rows)
            f.flush();os.fsync(f.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def atomic_json(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix='.manifest-',suffix='.json',dir=str(path.parent))
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:
            json.dump(obj,f,ensure_ascii=False,indent=2);f.flush();os.fsync(f.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def archive_previous(path,root):
    sha=digest(path);revision=root/'_revisions'/f'{path.stem}-{sha}.csv'
    revision.parent.mkdir(parents=True,exist_ok=True)
    if not revision.exists():
        import shutil
        shutil.copy2(path,revision)
    return str(revision)

def collect(args,provider=None):
    now=datetime.now(timezone.utc)
    try:past=now.replace(year=now.year-args.years)
    except ValueError:past=now.replace(year=now.year-args.years,day=28)
    root=Path(args.output_dir).expanduser().resolve()/args.symbol/args.timeframe
    old_manifest=root/'_manifest.json';prior={}
    if old_manifest.is_file():
        saved=json.loads(old_manifest.read_text(encoding='utf-8'))
        if saved.get('symbol')!=args.symbol or saved.get('timeframe')!=args.timeframe:raise ValueError('Archive manifest identity mismatch')
        prior={x['month']:x for x in saved.get('periods',[]) if 'month' in x}
    intervals=list(utc_months(past,now));total=0;missing=0;fetched=0;cached=0;results=[]
    if provider is None:
        try:import MetaTrader5 as mt5
        except ImportError:raise RuntimeError('Official MetaTrader5 Python binding unavailable; install via approved source')
        if not mt5.initialize():raise RuntimeError('MT5 terminal cannot initialize: '+str(mt5.last_error()))
        try:
            if mt5.account_info() is None:raise RuntimeError('MT5 terminal not logged into an account')
            if not mt5.symbol_select(args.symbol,True):raise RuntimeError('MT5 symbol unavailable')
            tf=getattr(mt5,'TIMEFRAME_'+args.timeframe)
            def _provider(start,end):return mt5.copy_rates_range(args.symbol,tf,start,end)
            return collect_with_provider(args,now,past,intervals,root,prior,_provider)
        finally:mt5.shutdown()
    return collect_with_provider(args,now,past,intervals,root,prior,provider)

def collect_with_provider(args,now,past,intervals,root,prior,provider):
    total=0;missing=0;fetched=0;cached=0;results=[]
    for month_start,start,end,month_end in intervals:
        label=month_start.strftime('%Y-%m');dest=root/(label+'.csv');p=prior.get(label,{})
        is_active=(month_start.year,month_start.month)==(now.year,now.month)
        if dest.is_file():
            existing_hash=digest(dest)
            if p.get('sha256') and existing_hash!=p['sha256']:
                raise ValueError('Previously archived file has changed unexpectedly: '+str(dest))
            old=read_rows(dest)
        else:old={}
        # A historical month with a valid archived shard never needs re-downloading,
        # unless --force is explicitly requested; active/partial month is refreshed.
        if old and not is_active and not args.force:
            rows=old;cached+=1;status='CACHED';changes=False
        else:
            # For the active month request only new bars plus a short revision
            # overlap, rather than downloading the entire current month again.
            query_start=start
            if is_active and old and not args.force:
                overlap_days=14 if args.timeframe in ('W1','MN1') else 3
                query_start=max(start,datetime.fromtimestamp(max(old)-overlap_days*86400,timezone.utc))
            raw=provider(query_start,end)
            fresh={}
            if raw is not None:
                for x in sorted(raw,key=lambda z:int(z['time'])):
                    ts=int(x['time']);o=float(x['open']);h=float(x['high']);l=float(x['low']);c=float(x['close']);v=int(x['tick_volume'])
                    if ts<start.timestamp() or ts>=end.timestamp() or not definitely_closed(ts,args.timeframe,now):continue
                    if not all(map(__import__('math').isfinite,(o,h,l,c))) or min(o,h,l,c)<=0 or l>min(o,c) or h<max(o,c) or v<0:raise ValueError('Invalid MT5 bar in '+label)
                    fresh[ts]=(ts,o,h,l,c,v)
            rows={**old,**fresh}  # preserve all existing bars and add new ones
            changes=bool(fresh) and rows!=old
            if changes:
                if old:archive_previous(dest,root)
                write_atomic(dest,[rows[k] for k in sorted(rows)])
            fetched+=1;status='PARTIAL' if is_active else ('IMPORTED' if rows else 'MISSING')
        if not rows:
            missing+=1;results.append({'month':label,'bars':0,'status':'MISSING','warning':'NO_AVAILABLE_HISTORY'});continue
        if not dest.exists():write_atomic(dest,[rows[k] for k in sorted(rows)])
        ordered=sorted(rows)
        total+=len(rows)
        results.append({'month':label,'status':status,'bars':len(rows),'firstUtc':datetime.fromtimestamp(ordered[0],timezone.utc).isoformat(),
                        'lastUtc':datetime.fromtimestamp(ordered[-1],timezone.utc).isoformat(),
                        'sha256':digest(dest),'relativePath':dest.name,
                        'windowStartUtc':start.isoformat(),'windowEndUtc':end.isoformat(),
                        'cachedWithoutDownload':status=='CACHED'})
        print(f'{label}: {len(rows)} bars ({status})',flush=True)
    manifest={'source':'MT5_TERMINAL_READ_ONLY','symbol':args.symbol,'timeframe':args.timeframe,
      'requestedStartUtc':past.isoformat(),'requestedEndUtc':now.isoformat(),'collectedUtc':datetime.now(timezone.utc).isoformat(),
      'requestedMonths':len(intervals),'monthsWithoutBars':missing,'monthsDownloadedOrRetried':fetched,'monthsReadFromArchive':cached,
      'totalBars':total,'verifiedBrokerProvenance':False,'tenYearCoverageVerified':False,'periods':results}
    atomic_json(root/'_manifest.json',manifest)
    print('Manifest saved:',root/'_manifest.json',flush=True)
    return manifest

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--symbol',choices=sorted(SYMBOLS),required=True)
    p.add_argument('--timeframe',choices=sorted(FRAMES),required=True)
    p.add_argument('--years',type=int,default=10)
    p.add_argument('--output-dir',default=os.path.join(os.getenv('LOCALAPPDATA',str(Path.home())), 'TradeYar','history'))
    p.add_argument('--dry-run',action='store_true')
    p.add_argument('--force',action='store_true',help='Explicitly re-fetch previously archived months; preserve old data in revisions')
    p.add_argument('--no-db-sync',action='store_true',help='Only write local history; do not sync even with configured DSN')
    args=p.parse_args()
    if args.years not in range(1,21):p.error('--years must be 1..20')
    now=datetime.now(timezone.utc)
    try:past=now.replace(year=now.year-args.years)
    except ValueError:past=now.replace(year=now.year-args.years,day=28)
    if args.dry_run:
        print(json.dumps({'symbol':args.symbol,'timeframe':args.timeframe,'startUtc':past.isoformat(),'endUtc':now.isoformat(),
                          'archive':str(Path(args.output_dir).expanduser().resolve()/args.symbol/args.timeframe),'dryRun':True},indent=2));return 0
    try:manifest=collect(args)
    except (ValueError,RuntimeError) as ex:print('Collection stopped; prior archive preserved:',ex,file=sys.stderr);return 2
    if not args.no_db_sync:
        if os.getenv('TRADEYAR_PG_DSN'):
            from import_history_postgres_v06 import import_folder
            try:import_folder(Path(args.output_dir).expanduser().resolve()/args.symbol/args.timeframe)
            except Exception as ex:
                print('POSTGRES SYNC PENDING; local archive remains intact:',str(ex),file=sys.stderr)
                return 7
        else:print('LOCAL ARCHIVE SAVED; PostgreSQL sync pending: set TRADEYAR_PG_DSN and run import_history_postgres_v06.py',flush=True)
    return 0 if manifest['totalBars'] else 6

if __name__=='__main__':raise SystemExit(main())
