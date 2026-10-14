import math
from datetime import datetime,timedelta,timezone
from pathlib import Path
import tempfile
import unittest
from tradeyar_core.backtest import Bar,backtest_sma,read_bars_csv
from tradeyar_core.walkforward import walkforward_sma


def make_bars(n=950):
    t=datetime(2022,1,1,tzinfo=timezone.utc)
    out=[]
    for i in range(n):
        # Deterministic, alternating regimes. Not historical forex data.
        v=1.10 + .00008*i + .007*math.sin(i/14)
        o=v; c=v + .0001*math.sin(i/5)
        out.append(Bar(t+timedelta(hours=i),t+timedelta(hours=i+1),
                       t+timedelta(hours=i+1),o,max(o,c)+.0002,
                       min(o,c)-.0002,c,30))
    return out

class BacktestTests(unittest.TestCase):
    def test_reproducible(self):
        b=make_bars(350); a=backtest_sma(b); c=backtest_sma(b)
        self.assertEqual(a,c)
        self.assertFalse(a['trade_authorized'])
        self.assertGreater(a['trades'],0)
    def test_costs_never_improve_same_ledger(self):
        b=make_bars(350)
        cheap=backtest_sma(b,spread_pips=0,slippage_pips=0)
        expensive=backtest_sma(b,spread_pips=2,slippage_pips=1)
        self.assertEqual(cheap['trades'],expensive['trades'])
        self.assertGreater(cheap['total_pnl_pips'],expensive['total_pnl_pips'])
    def test_delayed_data_cannot_signal(self):
        b=make_bars(350)
        delayed=[Bar(x.open_time,x.close_time,x.close_time+timedelta(days=3),
                     x.open,x.high,x.low,x.close,x.volume) for x in b]
        x=backtest_sma(delayed)
        self.assertEqual(x['trades'],0)
        self.assertGreater(x['skipped_late_signals'],0)
    def test_walkforward(self):
        x=walkforward_sma(make_bars(950),train_bars=400,test_bars=100,embargo_bars=15)
        self.assertGreaterEqual(len(x['folds']),3)
        for f in x['folds']:
            self.assertLess(f['train_interval'][1],f['test_interval'][0])
    def test_bad_fast(self):
        with self.assertRaises(ValueError): backtest_sma(make_bars(150),50,10)
    def test_csv_validates_prices(self):
        with tempfile.TemporaryDirectory() as d:
            f=Path(d)/'bad.csv'
            f.write_text('time,open,high,low,close,volume\n1704067200,1,2,.5,1.1,3\n1704070800,1,2,.5,1.1,3\n1704074400,1,0.5,.5,1.1,3\n')
            with self.assertRaises(ValueError): read_bars_csv(f)
if __name__=='__main__': unittest.main()
