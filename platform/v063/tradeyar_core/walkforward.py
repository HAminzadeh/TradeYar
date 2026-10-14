"""Expanding chronology-safe rolling windows with locked train/test boundaries."""
from __future__ import annotations
from .backtest import backtest_sma

DEFAULT_GRID=((5,20),(5,30),(10,30),(10,50),(15,50))

def walkforward_sma(bars, train_bars=600, test_bars=200, embargo_bars=10,
                    param_grid=DEFAULT_GRID,spread_pips=1.5,pip_size=.0001):
    if train_bars<100 or test_bars<30 or embargo_bars<0:
        raise ValueError('Invalid temporal window settings')
    if not param_grid:
        raise ValueError('Empty parameter grid')
    folds=[]
    # Windows advance by one test block. Embargo bars are neither training labels nor OOS scores.
    anchor=0
    while anchor+train_bars+embargo_bars+test_bars<=len(bars):
        end_train=anchor+train_bars
        start_test=end_train+embargo_bars
        end_test=start_test+test_bars
        training=bars[anchor:end_train]
        ranked=[]
        for fast,slow in param_grid:
            if fast>=slow or slow>=len(training)-1:
                raise ValueError('Invalid candidate')
            r=backtest_sma(training,fast,slow,spread_pips,pip_size)
            ranked.append((r['total_pnl_pips'],r['trades'],-fast,-slow,fast,slow))
        # Candidate selection uses ONLY training metrics; ties deterministic.
        winner=max(ranked)
        chosen_fast,chosen_slow=winner[-2:]
        # Preserve warmup from train, but order entry only after OOS begins.
        warmup=bars[max(0,start_test-chosen_slow-2):end_test]
        offset=start_test-max(0,start_test-chosen_slow-2)
        test_result=backtest_sma(warmup,chosen_fast,chosen_slow,
                                 spread_pips,pip_size,start_at=offset)
        folds.append({'train_interval':[bars[anchor].open_time.isoformat(),bars[end_train-1].close_time.isoformat()],
                      'test_interval':[bars[start_test].open_time.isoformat(),bars[end_test-1].close_time.isoformat()],
                      'embargo_bars':embargo_bars,'chosen_fast':chosen_fast,'chosen_slow':chosen_slow,
                      'train_pnl_pips':round(winner[0],5),
                      'test_pnl_pips':test_result['total_pnl_pips'],
                      'test_trades':test_result['trades'],'test_win_rate':test_result['win_rate'],
                      'test_dataset_hash':test_result['dataset_fingerprint']})
        anchor+=test_bars
    if not folds:
        raise ValueError('Insufficient history for one full train/embargo/test window')
    return {'method':'rolling_train_test_with_embargo','folds':folds,
            'aggregate_oos_pnl_pips':round(sum(x['test_pnl_pips'] for x in folds),5),
            'research_only':True,'trade_authorized':False,
            'limitations':'Repeated parameter selection and overlapping training do not create an untouched final holdout.'}
