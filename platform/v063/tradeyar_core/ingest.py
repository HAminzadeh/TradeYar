"""Strict, restart-safe closed-bar CSV importer with immutable revisions.

Does not download third-party data. The operator supplies a permitted local export.
Times are UTC (MT5 `time` is the bar open timestamp); only closed bars are accepted.
"""
from __future__ import annotations
import csv
from datetime import datetime, timezone, timedelta
import calendar
import hashlib
import math
from pathlib import Path
from uuid import uuid4
from .core import Settings, fingerprint, safe_symbol, utcnow
from .storage import connect

FRAME_SECONDS = {'M1':60, 'M5':300, 'M15':900, 'M30':1800, 'H1':3600,
                 'H4':14400, 'D1':86400, 'W1':604800}
VALID_FRAMES = set(FRAME_SECONDS) | {'MN1'}


def parse_utc(value: str) -> datetime:
    value = str(value).strip()
    if value.isdigit():
        v=int(value)
        # Epoch milliseconds are accepted only when explicit magnitude indicates milliseconds.
        if v > 99999999999:
            v /= 1000
        return datetime.fromtimestamp(v, timezone.utc)
    stamp = datetime.fromisoformat(value.replace('Z','+00:00'))
    if stamp.tzinfo is None:
        raise ValueError('Naive timestamp disallowed; include +00:00')
    return stamp.astimezone(timezone.utc)


def next_close(start:datetime,frame:str) -> datetime:
    if frame in FRAME_SECONDS:
        return start + timedelta(seconds=FRAME_SECONDS[frame])
    if frame == 'MN1':
        year,month=(start.year+1,1) if start.month==12 else (start.year,start.month+1)
        day=min(start.day,calendar.monthrange(year,month)[1])
        return start.replace(year=year,month=month,day=day)
    raise ValueError('Unknown timeframe: '+frame)


def file_hash(path:Path) -> str:
    sha=hashlib.sha256()
    with path.open('rb') as f:
        while block:=f.read(1024*1024):
            sha.update(block)
    return sha.hexdigest()


def iter_closed_bars(path, timeframe, now=None):
    """Yield validated bars without loading the entire history into memory."""
    now = now or datetime.now(timezone.utc)
    last = None
    with Path(path).open(newline='',encoding='utf-8-sig') as handle:
        reader=csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError('Missing CSV header')
        fields=set(reader.fieldnames)
        tfield='time' if 'time' in fields else 'open_time'
        if not {tfield,'open','high','low','close','volume'}.issubset(fields):
            raise ValueError('Expected time/open_time,open,high,low,close,volume')
        for line,row in enumerate(reader,start=2):
            try:
                start=parse_utc(row[tfield]); close_time=next_close(start,timeframe)
                available=parse_utc(row['available_at']) if row.get('available_at') else close_time
                if available < close_time:
                    raise ValueError('available_at before close_time')
                if close_time > now:
                    raise ValueError('Open/incomplete candle')
                if last is not None and start <= last:
                    raise ValueError('Non-increasing/duplicate candle time')
                o,h,l,c=[float(row[k]) for k in ('open','high','low','close')]
                volume=int(row['volume'])
                if any((not math.isfinite(x) or x<=0) for x in (o,h,l,c)):
                    raise ValueError('Non-finite or non-positive price')
                if volume<0 or l>min(o,c) or h<max(o,c) or l>h:
                    raise ValueError('Invalid OHLC/volume')
            except (KeyError,TypeError,ValueError,OverflowError,OSError) as ex:
                raise ValueError(f'Invalid row {line}: {ex}') from ex
            last=start
            bar={'open_time':start,'close_time':close_time,'available_at':available,
                 'open':o,'high':h,'low':l,'close':c,'volume':volume}
            hash_input={'open_time':start.isoformat(),'close_time':close_time.isoformat(),
                        'available_at':available.isoformat(),'open':o,'high':h,'low':l,
                        'close':c,'volume':volume}
            bar['value_hash']=fingerprint(hash_input)
            yield bar


def _upsert_bar(cur, provider, symbol, frame, bar):
    key=(provider,symbol,frame,bar['open_time'])
    cur.execute('''SELECT revision,value_hash FROM tradeyar_market.market_bars
                   WHERE provider=%s AND symbol=%s AND timeframe=%s AND open_time=%s FOR UPDATE''',key)
    prev=cur.fetchone()
    if prev and prev[1] == bar['value_hash']:
        return 'duplicate'
    version=(prev[0]+1) if prev else 1
    params=(bar['close_time'],bar['available_at'],bar['open'],bar['high'],bar['low'],bar['close'],bar['volume'],version,bar['value_hash'])
    if prev:
        cur.execute('''UPDATE tradeyar_market.market_bars SET
                       close_time=%s,available_at=%s,open_price=%s,high_price=%s,
                       low_price=%s,close_price=%s,tick_volume=%s,revision=%s,
                       value_hash=%s,received_at=NOW()
                       WHERE provider=%s AND symbol=%s AND timeframe=%s AND open_time=%s''',params+key)
    else:
        cur.execute('''INSERT INTO tradeyar_market.market_bars
                       (provider,symbol,timeframe,open_time,close_time,available_at,
                        open_price,high_price,low_price,close_price,tick_volume,revision,value_hash)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)''',key+params)
    import json
    cur.execute('''INSERT INTO tradeyar_market.market_bar_versions
                   (provider,symbol,timeframe,open_time,revision,row_values,value_hash)
                   VALUES (%s,%s,%s,%s,%s,%s::jsonb,%s)''',
                key+(version,json.dumps({'open':bar['open'],'high':bar['high'],
                    'low':bar['low'],'close':bar['close'],'volume':bar['volume'],
                    'close_time':bar['close_time'].isoformat(),
                    'available_at':bar['available_at'].isoformat()}),bar['value_hash']))
    return 'corrected' if prev else 'inserted'


def ingest_csv(filename:str,symbol:str,timeframe:str,provider:str,
               permission_status:str='UNVERIFIED',allow_unverified:bool=False,batch_size:int=1000) -> dict:
    symbol=safe_symbol(symbol)
    timeframe=timeframe.upper().strip()
    provider=provider.strip()
    if timeframe not in VALID_FRAMES or not provider or len(provider)>120:
        raise ValueError('Unsupported timeframe or provider')
    permission_status=permission_status.strip().upper()
    if permission_status not in ('ALLOWED','UNVERIFIED','RESTRICTED','EXPIRED'):
        raise ValueError('Permission status must be ALLOWED/UNVERIFIED/RESTRICTED/EXPIRED')
    if permission_status in ('RESTRICTED','EXPIRED') or (permission_status=='UNVERIFIED' and not allow_unverified):
        raise ValueError('Data permission not cleared; pass ALLOWED or explicitly acknowledge unverified local data')
    path=Path(filename).expanduser().resolve()
    if not path.is_file() or path.suffix.lower()!='.csv':
        raise ValueError('CSV path missing or not .csv')
    if batch_size<1 or batch_size>10000:
        raise ValueError('batch_size out of range')
    run_id=str(uuid4()); source_id=f'{provider}:{symbol}:{timeframe}'
    checksum=file_hash(path)
    counters={'inserted':0,'corrected':0,'duplicate':0}
    with connect('timeseries') as db:
        with db.cursor() as cur:
            count=0
            for bar in iter_closed_bars(path,timeframe):
                counters[_upsert_bar(cur,provider,symbol,timeframe,bar)]+=1
                count+=1
                if count % batch_size == 0:
                    db.commit()
            db.commit()
    # Metadata runs are append-only. If this fails after timeseries commit, rerun is safe/idempotent.
    with connect('metadata') as db:
        with db.cursor() as cur:
            cur.execute('''INSERT INTO tradeyar_core.data_sources(source_id,provider,dataset_kind,permission_status)
                           VALUES (%s,%s,'MARKET_BARS',%s)
                           ON CONFLICT(source_id) DO NOTHING''',
                        (source_id,provider,permission_status))
            cur.execute('''INSERT INTO tradeyar_core.ingestion_runs
                (run_id,source_id,dataset_hash,started_at,finished_at,status,
                 inserted_count,corrected_count,duplicate_count)
                VALUES (%s,%s,%s,NOW(),NOW(),'COMPLETED',%s,%s,%s)''',
                (run_id,source_id,checksum,counters['inserted'],counters['corrected'],counters['duplicate']))
            import json
            cur.execute('''INSERT INTO tradeyar_core.outbox_events
                (event_id,aggregate_type,aggregate_id,payload)
                VALUES (%s,'MARKET_INGEST',%s,%s::jsonb)''',
                (str(uuid4()),run_id,json.dumps({'source_id':source_id,'checksum':checksum,'counts':counters})))
    return {'run_id':run_id,'source':source_id,'file_sha256':checksum,
            'counts':counters,'research_only':True,'trading_authorized':False}
