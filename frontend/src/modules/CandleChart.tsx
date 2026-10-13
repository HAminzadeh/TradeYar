import { useEffect, useRef } from 'react';
import { CandlestickSeries, createChart, type UTCTimestamp } from 'lightweight-charts';

export type Candle = {time:number;open:number;high:number;low:number;close:number;volume:number};

export default function CandleChart({ candles }: { candles: Candle[] }) {
  const container = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    if (!container.current || !candles.length) return;
    const chart = createChart(container.current, {
      width: container.current.clientWidth, height: 400,
      layout: {background: {color: '#142239'}, textColor: '#adbed7'},
      grid: {vertLines: {color: '#22344e'}, horzLines: {color: '#22344e'}},
      timeScale: {timeVisible: true, secondsVisible: false},
    });
    const series = chart.addSeries(CandlestickSeries, {
      upColor: '#35c999', downColor: '#f47784', borderVisible: false,
      wickUpColor: '#35c999', wickDownColor: '#f47784',
    });
    series.setData([...candles].sort((a,b) => a.time-b.time).map(c => ({
      time: c.time as UTCTimestamp, open:c.open, high:c.high, low:c.low, close:c.close,
    })));
    chart.timeScale().fitContent();
    const observer = new ResizeObserver(() => {
      if (container.current) chart.applyOptions({width:container.current.clientWidth});
    });
    observer.observe(container.current);
    return () => { observer.disconnect(); chart.remove(); };
  }, [candles]);
  return <div ref={container} className="candle-chart" aria-label="Demo candlestick chart" dir="ltr" />;
}
