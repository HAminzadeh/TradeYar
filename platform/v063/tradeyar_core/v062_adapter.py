"""Read-only, version-aware adapter to TradeYar v0.6.2 monthly archives.
Uses the official v0.6.2 manifest verifier, not a second downloader.
No broker trading API and no vendor data fetching.
"""
from __future__ import annotations
from pathlib import Path
import hashlib
import importlib.util
import json
import re
from datetime import datetime, timezone, timedelta
from .core import fingerprint

FRAMES={'M1':60,'M5':300,'M15':900,'M30':1800,'H1':3600,'H4':14400}


def _load_v062(project_root: Path):
    source = project_root/'scripts'/'import_history_postgres_v06.py'
    if not source.is_file():
        raise FileNotFoundError('TradeYar v0.6.2 history verifier absent: '+str(source))
    spec = importlib.util.spec_from_file_location('tradeyar_v062_history_verifier',source)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verified_history(project_root, archive_folder, max_rows=2_000_000):
    """Validate manifest SHA, fixed fields and timestamps with existing v0.6.2 code."""
    if max_rows < 120: raise ValueError('max_rows too small')
    verifier=_load_v062(Path(project_root).resolve())
    manifest,shards=verifier.verified_shards(Path(archive_folder))
    n=sum(len(rows) for *_,rows in shards)
    if n>max_rows:raise ValueError('Archive exceeds local validation cap; split symbol/timeframe')
    source=manifest.get('source','UNKNOWN')
    if source != 'MT5_TERMINAL_READ_ONLY': raise ValueError('Only v0.6.2 read-only MT5 archive is currently accepted')
    return {'manifest':manifest,'shards':shards,'rows':n,'source':source}


def sync_timescale(project_root, archive_folder, dsn, max_rows=2_000_000):
    """Additive projection only: no changes to the v0.6.2 PostgreSQL archive.
    Exact duplicate rows ignored; revised values recorded in revisions table,
    never silently overwrite original. Use a separate Timescale DSN.
    """
    if not dsn:raise ValueError('TRADEYAR_TS_DSN required')
    info=verified_history(project_root,archive_folder,max_rows)
    try:import psycopg
    except ImportError as e:raise RuntimeError('psycopg 3 must be installed in the local venv') from e
    manifest=info['manifest']; frame=manifest['timeframe']
    if frame not in FRAMES:raise ValueError('Projection currently supports M1..H4 only; calendar daily/weekly handling pending')
    interval=timedelta(seconds=FRAMES[frame]); now=datetime.now(timezone.utc)
    inserted=0;revised=0;ignored=0
    with psycopg.connect(dsn,connect_timeout=8) as conn:
        for month,path,sha,entry,rows in info['shards']:
            with conn.transaction():
                with conn.cursor() as cur:
                    for at,o,h,l,c,vol in rows:
                        close=at+interval
                        if close>now:raise ValueError('Incomplete/future bar in historical archive')
                        vals={'o':str(o),'h':str(h),'l':str(l),'c':str(c),'volume':int(vol)}
                        value_hash=fingerprint(vals)
                        key=(info['source'],manifest['symbol'],frame,at)
                        cur.execute('''INSERT INTO tradeyar_market.market_bars
                          (provider,symbol,timeframe,open_time,close_time,available_at,open_price,high_price,low_price,close_price,tick_volume,value_hash)
                          VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',
                          (*key,close,close,o,h,l,c,vol,value_hash))
                        if cur.rowcount: inserted+=1;continue
                        cur.execute('''SELECT value_hash FROM tradeyar_market.market_bars
                          WHERE provider=%s AND symbol=%s AND timeframe=%s AND open_time=%s''',key)
                        original=cur.fetchone()
                        if not original:raise RuntimeError('Timescale projection conflict without matching key')
                        if original[0]==value_hash:ignored+=1;continue
                        # Version 1 of this alternative value; revision rows are immutable by content hash.
                        cur.execute('''INSERT INTO tradeyar_market.market_bar_observations
                          (provider,symbol,timeframe,open_time,content_hash,source_archive_sha256,row_values)
                          VALUES(%s,%s,%s,%s,%s,%s,%s::jsonb)
                          ON CONFLICT DO NOTHING''',(*key,value_hash,sha,json.dumps(vals)))
                        revised+=cur.rowcount
    return {'inserted':inserted,'duplicate':ignored,'new_alternate_observations':revised,
            'source':info['source'],'symbol':manifest['symbol'],'timeframe':frame,
            'trade_authorized':False}
