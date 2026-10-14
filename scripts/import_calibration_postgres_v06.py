#!/usr/bin/env python3
"""Idempotent PostgreSQL ingestion of all local v0.6 calibration JSON reports.

Designed to retry after an outage; JSON originals remain on disk. No fabricated ML
training and no changes to real-money execution state.
"""
import argparse,json,os,sys
from pathlib import Path

def import_reports(folder,dsn=None):
    dsn=dsn or os.getenv('TRADEYAR_PG_DSN')
    if not dsn:raise RuntimeError('TRADEYAR_PG_DSN must be configured locally')
    try:import psycopg
    except ImportError as e:raise RuntimeError('Install approved psycopg3 package') from e
    root=Path(folder).expanduser().resolve();files=sorted(root.glob('v06-*.json'));imported=0
    with psycopg.connect(dsn,connect_timeout=8) as conn:
        for path in files:
            r=json.loads(path.read_text(encoding='utf-8'))
            if path.name!=f"v06-{r['runId']}.json":raise ValueError('Research report path/id mismatch')
            if len(r.get('rows',[]))!=20:raise ValueError('Incomplete 20-strategy research run '+path.name)
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute('''INSERT INTO tradeyar_research.calibration_runs_v06
                      (run_id,symbol,timeframe,style,source,dataset_sha256,processed_bars,covered_years,independent_validation,ten_year_training_complete,created_at,report_json)
                      VALUES(%s,%s,%s,%s,%s,%s,%s,%s,FALSE,FALSE,%s,%s::jsonb) ON CONFLICT(run_id) DO NOTHING''',
                      (r['runId'],r['symbol'],r['timeframe'],r['style'],r['source'],r['datasetSha256'],r['processedBars'],r['coveredYearsInProcessedWindow'],r['createdAtUtc'],json.dumps(r)))
                    imported+=cur.rowcount
                    for item in r['rows']:
                        cur.execute('''INSERT INTO tradeyar_research.calibration_strategy_results_v06
                          (run_id,strategy_id,selected_preset,training_metrics,validation_metrics,heldout_metrics)
                          VALUES(%s,%s,%s,%s::jsonb,%s::jsonb,%s::jsonb) ON CONFLICT DO NOTHING''',
                          (r['runId'],item['strategy'],item['chosenTrainingOnlyPreset'],json.dumps(item['training']),json.dumps(item['validation']),json.dumps(item['heldOut'])))
            print('[SYNC]',path.name)
        # Persist one analysis result per closed bar; derived rows are idempotent.
        events=root/'analysis-events-v06.jsonl'
        imported_snapshots=0
        if events.exists():
            with events.open(encoding='utf-8') as stream:
                for line in stream:
                    if not line.strip():continue
                    event=json.loads(line)
                    if len(event.get('strategies',[]))!=20:raise ValueError('Incomplete strategy event')
                    with conn.transaction():
                        with conn.cursor() as cur:
                            cur.execute("""INSERT INTO tradeyar_research.analysis_snapshots_v06
                              (symbol,timeframe,style,event_at,engine_version,source,decision,payload)
                              VALUES(%s,%s,%s,%s,%s,%s,%s,%s::jsonb)
                              ON CONFLICT DO NOTHING""",
                              (event['symbol'],event['effectiveTimeframe'],event['style'],event['lastClosedBarUtc'],
                               event['engineVersion'],event['source'],event['decision'],json.dumps(event)))
                            imported_snapshots+=cur.rowcount
                            for row in event['strategies']:
                                cur.execute("""INSERT INTO tradeyar_research.analysis_strategy_signals_v06
                                  (symbol,timeframe,style,event_at,engine_version,strategy_id,signal,independently_validated,reason)
                                  VALUES(%s,%s,%s,%s,%s,%s,%s,FALSE,%s)
                                  ON CONFLICT DO NOTHING""",
                                  (event['symbol'],event['effectiveTimeframe'],event['style'],event['lastClosedBarUtc'],
                                   event['engineVersion'],row['id'],row['signal'],row.get('reason','')))
    print(f'[DONE] {len(files)} calibration files, {imported} new runs, {imported_snapshots} new analysis snapshots; original files preserved')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--folder',default=os.getenv('TRADEYAR_RESEARCH_DIR',str(Path.home()/'.tradeyar'/'research')))
    args=p.parse_args()
    try:import_reports(args.folder)
    except Exception as e:print('[FAILED]',str(e),file=sys.stderr);return 2
    return 0
if __name__=='__main__':raise SystemExit(main())
