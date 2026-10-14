"""Run and persist immutable research-only backtests in the metadata PostgreSQL DB."""
from __future__ import annotations
import argparse
import json
from uuid import uuid4
from pathlib import Path
from .backtest import read_bars_csv,backtest_sma
from .storage import connect


def persist_backtest(csv_path,symbol,timeframe,fast=10,slow=30,
                     spread_pips=1.5,pip_size=.0001,slippage_pips=.2):
    bars=read_bars_csv(csv_path)
    metrics=backtest_sma(bars,fast,slow,spread_pips,pip_size,slippage_pips)
    run_id=str(uuid4())
    ledger=metrics.pop('trade_ledger')
    with connect('metadata') as db:
        with db.cursor() as cur:
            cur.execute('''INSERT INTO tradeyar_platform_research.backtest_runs
                (run_id,symbol,timeframe,dataset_hash,strategy,strategy_params,
                 cost_assumptions,result_metrics,trade_ledger)
                VALUES (%s,%s,%s,%s,%s,%s::jsonb,%s::jsonb,%s::jsonb,%s::jsonb)''',
                (run_id,symbol,timeframe,metrics['dataset_fingerprint'],'SMA_CROSS',
                 json.dumps({'fast':fast,'slow':slow}),json.dumps(metrics['assumptions']),
                 json.dumps(metrics),json.dumps(ledger)))
    return {'run_id':run_id,'status':'RESEARCH_RECORDED','metrics':metrics,
            'recorded_trades':len(ledger),'trade_authorized':False}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--file',required=True)
    p.add_argument('--symbol',required=True)
    p.add_argument('--timeframe',required=True)
    p.add_argument('--fast',type=int,default=10)
    p.add_argument('--slow',type=int,default=30)
    p.add_argument('--spread-pips',type=float,default=1.5)
    p.add_argument('--pip-size',type=float,default=.0001)
    p.add_argument('--slippage-pips',type=float,default=.2)
    a=p.parse_args()
    print(json.dumps(persist_backtest(a.file,a.symbol,a.timeframe,a.fast,a.slow,
           a.spread_pips,a.pip_size,a.slippage_pips),indent=2))
