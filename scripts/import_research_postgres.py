#!/usr/bin/env python3
"""Explicit opt-in: import TradeYar local JSONL research logs into PostgreSQL.
Install psycopg separately and set TRADEYAR_PG_DSN in *local environment* (never Git).
Before importing, execute infrastructure/db/v05_knowledge.sql with approved DB admin.
"""
import argparse
import json
import os
from pathlib import Path
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--file', required=True, help='Full path to research-runs.jsonl')
    args = p.parse_args()
    dsn = os.getenv('TRADEYAR_PG_DSN')
    if not dsn:
        print('TRADEYAR_PG_DSN not configured; import aborted', file=sys.stderr)
        return 2
    try:
        import psycopg
    except ImportError:
        print('Install psycopg in approved Python environment (not installed automatically)', file=sys.stderr)
        return 3
    path = Path(args.file).expanduser().resolve()
    if not path.is_file():
        print('JSONL log unavailable', file=sys.stderr)
        return 4
    inserted = 0
    with psycopg.connect(dsn, connect_timeout=5) as conn:
        with conn.cursor() as cur:
            with path.open(encoding='utf-8') as stream:
                for line in stream:
                    if not line.strip():
                        continue
                    r = json.loads(line)
                    cur.execute('''INSERT INTO tradeyar_research.research_runs
                        (run_id,symbol,timeframe,strategy_id,dataset_sha256,source,total_bars,created_at,training_metrics,held_out_metrics,warning,validated)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb,%s::jsonb,%s,FALSE)
                        ON CONFLICT (run_id) DO NOTHING''',
                        (r['runId'],r['symbol'],r['timeframe'],r['strategy'],r['dataHashSha256'],
                         r['source'],r['totalBars'],r['atUtc'],json.dumps(r['trainingPeriod']),
                         json.dumps(r['heldOutPeriod']),r['warning']))
                    inserted += cur.rowcount
    print(f'Imported {inserted} new research runs; no models trained or approved')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
