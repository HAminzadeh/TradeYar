#!/usr/bin/env python3
"""Optional v0.6.2 verified archive -> TimescaleDB additive sync. No vendor downloads."""
import argparse, os, sys
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--project',required=True)
p.add_argument('--folder',required=True)
p.add_argument('--verify-only',action='store_true')
a=p.parse_args()
sys.path.insert(0,str(Path(a.project).resolve()/'platform'/'v063'))
from tradeyar_core.v062_adapter import verified_history,sync_timescale
try:
 if a.verify_only:
  info=verified_history(a.project,a.folder)
  print('Verified source=',info['source'],'rows=',info['rows'],'shards=',len(info['shards']))
 else:
  print(sync_timescale(a.project,a.folder,os.getenv('TRADEYAR_TS_DSN','')))
except Exception as e:
 print('v063 sync failed: '+str(e),file=sys.stderr);raise SystemExit(1)
