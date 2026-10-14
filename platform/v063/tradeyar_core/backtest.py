"""Research-only closed-bar SMA backtest with next-open execution and explicit costs.

No real orders, no broker connectivity. Assumes mid-price OHLC and constant modeled
spread/slippage; intrabar stops, variable spreads, swaps and fills are NOT modeled.
"""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime,timezone
from pathlib import Path
from math import isfinite, sqrt
from statistics import fmean, pstdev
from .ingest import parse_utc
from .core import fingerprint
import csv

@dataclass(frozen=True)
class Bar:
    open_time: datetime
    close_time: datetime
    available_at: datetime
    open: float
    high: float
    low: float
    close: float
    volume: int


def read_bars_csv(path) -> list[Bar]:
    """Accept MT5-style time,OHLCV. Bar closes are inferred from spacing or timeframe."""
    from .ingest import iter_closed_bars
    # For research, user must choose the timeframe explicitly in other paths;
    # here infer a fixed interval only for uniform intraday CSVs, without changing dates.
    path=Path(path).expanduser().resolve()
    with path.open(newline='',encoding='utf-8-sig') as f:
        rdr=csv.DictReader(f)
        if not rdr.fieldnames or not ({'time','open_time'} & set(rdr.fieldnames)):
            raise ValueError('Expected a timestamped OHLC CSV')
        rows=list(rdr)
    if len(rows)<3:
        raise ValueError('At least three candles are needed')
    name='time' if 'time' in rdr.fieldnames else 'open_time'
    times=[parse_utc(r[name]) for r in rows]
    for i in range(1,len(times)):
        if times[i]<=times[i-1]:
            raise ValueError('Timestamps must be strictly increasing')
    # Only fixed intraday/day intervals can be inferred. Fail closed on irregular series.
    seconds=(times[1]-times[0]).total_seconds()
    if seconds not in (60,300,900,1800,3600,14400,86400):
        raise ValueError('Cannot infer timeframe; use uniform M1/M5/M15/M30/H1/H4/D1 bars')
    bars=[]
    from datetime import timedelta
    for index,r in enumerate(rows):
        start=times[index]; end=start+timedelta(seconds=seconds)
        available=parse_utc(r['available_at']) if r.get('available_at') else end
        if available<end:
            raise ValueError('Observation available before candle close')
        try:
            o,h,l,c=(float(r[v]) for v in ('open','high','low','close'))
            volume=int(r.get('volume') or 0)
        except (TypeError,KeyError,ValueError) as exc:
            raise ValueError(f'Invalid numeric value in bar {index}') from exc
        if not all(isfinite(x) and x>0 for x in (o,h,l,c)) or l>min(o,c) or h<max(o,c) or volume<0:
            raise ValueError(f'Invalid OHLCV in bar {index}')
        bars.append(Bar(start,end,available,o,h,l,c,volume))
    return bars


def _check_bars(bars):
    if len(bars)<4: raise ValueError('At least four bars are needed')
    last=None
    for b in bars:
        if last is not None and b.open_time < last:
            raise ValueError('Overlapping or unordered bars')
        if b.available_at < b.close_time: raise ValueError('Future leakage: available before close')
        if min(b.open,b.high,b.low,b.close)<=0 or b.low>min(b.open,b.close) or b.high<max(b.open,b.close):
            raise ValueError('Invalid OHLC')
        last=b.close_time


def _metrics(trades, total_bars, assumptions):
    pnls=[t['pnl_pips'] for t in trades]
    total=sum(pnls)
    running=0.0; peak=0.0; drawdown=0.0
    for v in pnls:
        running+=v;peak=max(peak,running);drawdown=max(drawdown,peak-running)
    gains=sum(p for p in pnls if p>0)
    losses=-sum(p for p in pnls if p<0)
    sd=pstdev(pnls) if len(pnls)>1 else 0.0
    return {
        'trades':len(pnls), 'total_pnl_pips':round(total,5),
        'expectancy_pips':round(fmean(pnls),5) if pnls else None,
        'win_rate':round(sum(1 for p in pnls if p>0)/len(pnls),6) if pnls else None,
        'profit_factor':round(gains/losses,5) if losses>0 else None,
        'max_closed_trade_drawdown_pips':round(drawdown,5),
        'trade_sharpe_unannualized':round(fmean(pnls)/sd,5) if sd>0 else None,
        'bars':total_bars,
        'research_only': True,
        'trade_authorized':False,
        'assumptions':assumptions,
    }


def backtest_sma(bars:list[Bar],fast:int=10,slow:int=30,spread_pips:float=1.5,
                 pip_size:float=.0001,slippage_pips:float=.2,
                 commission_pips_per_side:float=0.0,start_at:int=0) -> dict:
    _check_bars(bars)
    if not (2<=fast<slow<=1000 and slow<len(bars)-1):
        raise ValueError('Require 2 <= fast < slow <= 1000 and enough bars')
    if not (isfinite(spread_pips) and isfinite(pip_size) and isfinite(slippage_pips)
            and isfinite(commission_pips_per_side)) or min(spread_pips,slippage_pips,commission_pips_per_side)<0 or pip_size<=0:
        raise ValueError('Nonnegative costs and a positive pip_size are required')
    if start_at<0 or start_at>=len(bars)-1:
        raise ValueError('Invalid OOS start')
    closes=[b.close for b in bars]
    prefix=[0.0]
    for p in closes: prefix.append(prefix[-1]+p)
    def sma(i,n):return (prefix[i+1]-prefix[i+1-n])/n
    position=0; entry_price=0.0; entry_time=None; entry_i=None
    trades=[];entry_signals=0; skipped_late=0
    last_side_cost=commission_pips_per_side*pip_size
    execution_buffer=(spread_pips/2+slippage_pips)*pip_size
    def fill(mid,action):
        return mid+execution_buffer if action==1 else mid-execution_buffer
    for i in range(max(slow-1,start_at),len(bars)-1):
        # The decision is evaluated only after bar i CLOSE. Order fills at i+1 OPEN.
        if bars[i].available_at>bars[i+1].open_time:
            skipped_late+=1
            continue
        current=sma(i,fast)-sma(i,slow)
        previous=sma(i-1,fast)-sma(i-1,slow) if i>=slow else 0.0
        if i==max(slow-1,start_at):
            desired=1 if current>0 else -1 if current<0 else 0
        else:
            desired=1 if previous<=0<current else -1 if previous>=0>current else 0
        if desired==0 or desired==position:
            continue
        entry_signals+=1
        next_bar=bars[i+1]
        if position!=0:
            exit_price=fill(next_bar.open,-position)
            pnl=(exit_price-entry_price)*position/pip_size-2*commission_pips_per_side
            trades.append({'side':'LONG' if position==1 else 'SHORT',
                           'entry_at_utc':entry_time.isoformat(),
                           'exit_at_utc':next_bar.open_time.isoformat(),
                           'entry_price':round(entry_price,10),'exit_price':round(exit_price,10),
                           'pnl_pips':round(pnl,6),'entry_bar_index':entry_i,
                           'exit_bar_index':i+1,'reason':'REVERSAL'})
        position=desired;entry_price=fill(next_bar.open,position)
        entry_time=next_bar.open_time; entry_i=i+1
    if position!=0:
        # Explicit end-of-test close is modeled at last candle CLOSE, not an intrabar limit fill.
        last=bars[-1]
        exit_price=fill(last.close,-position)
        pnl=(exit_price-entry_price)*position/pip_size-2*commission_pips_per_side
        trades.append({'side':'LONG' if position==1 else 'SHORT',
                       'entry_at_utc':entry_time.isoformat(),'exit_at_utc':last.close_time.isoformat(),
                       'entry_price':round(entry_price,10),'exit_price':round(exit_price,10),
                       'pnl_pips':round(pnl,6),'entry_bar_index':entry_i,
                       'exit_bar_index':len(bars)-1,'reason':'END_OF_DATA_MARK'})
    assumptions={'execution':'next_bar_open','signal_uses':'closed_and_available_bars_only',
                 'price_source':'mid OHLC assumed','spread_pips':spread_pips,
                 'slippage_pips_per_side':slippage_pips,'pip_size':pip_size,
                 'commission_pips_per_side':commission_pips_per_side,
                 'variable_spread':False,'tick_fills':False,'swap':False,
                 'end_of_data_mark':True,'max_drawdown_basis':'closed_trade_equity',
                 'warning':'Research estimate, not execution-grade or broker validated'}
    metrics=_metrics(trades,len(bars),assumptions)
    metrics.update({'fast':fast,'slow':slow,'entry_signals':entry_signals,
                    'skipped_late_signals':skipped_late,
                    'dataset_fingerprint':fingerprint([{'t':b.open_time.isoformat(),
                           'o':b.open,'h':b.high,'l':b.low,'c':b.close} for b in bars]),
                    'trade_ledger':trades})
    return metrics
