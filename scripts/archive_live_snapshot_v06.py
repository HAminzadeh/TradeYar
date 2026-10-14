#!/usr/bin/env python3
"""Append read-only rolling MT5 bar snapshots to permanent monthly archives.

A restart or repeated snapshot never duplicates candles; previously seen history is
preserved on disk and optionally synchronized to PostgreSQL after each changed month.
Do NOT run multiple writers for the same symbol/timeframe archive simultaneously.
"""
import argparse,csv,json,os,sys
from pathlib import Path
from datetime import datetime,timezone
from collections import defaultdict
from collect_mt5_history_v06 import (read_rows,write_atomic,digest,archive_previous,atomic_json,SYMBOLS,FRAMES)

def archive_snapshot(snapshot,symbol,frame,archive_root):
    if symbol not in SYMBOLS or frame not in FRAMES:raise ValueError('Unsupported symbol or timeframe')
    snapshot=Path(snapshot).expanduser().resolve()
    if snapshot.name!=f'{symbol}_{frame}.csv':raise ValueError('Snapshot filename does not match symbol/timeframe')
    source_rows=read_rows(snapshot)
    if not source_rows:raise ValueError('Empty incoming snapshot')
    root=Path(archive_root).expanduser().resolve()/symbol/frame
    manifest_path=root/'_manifest.json'
    old_manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    if old_manifest and (old_manifest.get('symbol')!=symbol or old_manifest.get('timeframe')!=frame):raise ValueError('Archive identity mismatch')
    entries={x['month']:x for x in old_manifest.get('periods',[]) if 'month' in x}
    grouped=defaultdict(dict)
    for ts,row in source_rows.items():grouped[datetime.fromtimestamp(ts,timezone.utc).strftime('%Y-%m')][ts]=row
    touched=[];conflicts=0
    for month,values in sorted(grouped.items()):
        root.mkdir(parents=True,exist_ok=True)
        dest=root/(month+'.csv');p=entries.get(month,{})
        if dest.exists() and p.get('sha256') and digest(dest)!=p['sha256']:
            raise ValueError('Archived file changed externally: '+str(dest))
        old=read_rows(dest) if dest.exists() else {}
        merged={**old,**values}
        revised=sum(1 for k,v in values.items() if k in old and old[k]!=v);conflicts+=revised
        if merged!=old:
            if old:archive_previous(dest,root)
            write_atomic(dest,[merged[k] for k in sorted(merged)])
            touched.append(month)
        ordered=sorted(merged)
        entries[month]={'month':month,'status':'PARTIAL' if month==datetime.now(timezone.utc).strftime('%Y-%m') else 'IMPORTED',
          'bars':len(ordered),'firstUtc':datetime.fromtimestamp(ordered[0],timezone.utc).isoformat(),
          'lastUtc':datetime.fromtimestamp(ordered[-1],timezone.utc).isoformat(),
          'sha256':digest(dest),'relativePath':dest.name,
          'windowStartUtc':datetime.fromtimestamp(ordered[0],timezone.utc).isoformat(),
          'windowEndUtc':datetime.fromtimestamp(ordered[-1]+1,timezone.utc).isoformat()}
    out={**old_manifest,'source':'MT5_TERMINAL_READ_ONLY','symbol':symbol,'timeframe':frame,
      'collectedUtc':datetime.now(timezone.utc).isoformat(),'verifiedBrokerProvenance':False,'tenYearCoverageVerified':False,
      'periods':[entries[k] for k in sorted(entries)],
      'totalBars':sum(x.get('bars',0) for x in entries.values()),
      'monthsWithoutBars':sum(not x.get('bars') for x in entries.values())}
    atomic_json(manifest_path,out)
    return root,touched,conflicts

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--file',required=True)
    p.add_argument('--symbol',required=True,choices=sorted(SYMBOLS))
    p.add_argument('--timeframe',required=True,choices=sorted(FRAMES))
    p.add_argument('--archive-root',default=str(Path(os.getenv('LOCALAPPDATA',str(Path.home())))/'TradeYar'/'history'))
    p.add_argument('--no-db-sync',action='store_true')
    args=p.parse_args()
    try:
        root,touched,conflicts=archive_snapshot(args.file,args.symbol,args.timeframe,args.archive_root)
        print('[ARCHIVE]',root,'changed months:',touched,'bar revisions:',conflicts)
        if os.getenv('TRADEYAR_PG_DSN') and touched and not args.no_db_sync:
            from import_history_postgres_v06 import import_folder
            import_folder(root,only_months=set(touched))
        elif not os.getenv('TRADEYAR_PG_DSN'):
            print('[PENDING] Local data secured. Set TRADEYAR_PG_DSN to sync PostgreSQL.')
        return 0
    except Exception as e:print('[FAILED] Snapshot archive:',str(e),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
