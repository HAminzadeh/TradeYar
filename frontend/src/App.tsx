import { useEffect, useMemo, useState } from 'react';
import { CandlestickSeries, createChart, type IChartApi, type UTCTimestamp } from 'lightweight-charts';
import { translations, type Locale } from './i18n/translations';
import { moduleNamesFa } from './i18n/moduleNames';

type ModuleRow = { id: string; name: string; status: string };
type Candle = { time: number; open: number; high: number; low: number; close: number; volume: number };
type Quote = { symbol: string; bid: number; ask: number; source: string };
function getDefaultLocale(): Locale {
  try { return localStorage.getItem('tradeyar.locale') === 'en' ? 'en' : 'fa'; }
  catch { return 'fa'; }
}

function CandleChart({ candles }: { candles: Candle[] }) {
  const [element, setElement] = useState<HTMLDivElement | null>(null);
  useEffect(() => {
    if (!element || !candles.length) return;
    const chart: IChartApi = createChart(element, {
      width: element.clientWidth, height: 310,
      layout: { background: { color: '#141f32' }, textColor: '#b8c6df' },
      grid: { vertLines: { color: '#223149' }, horzLines: { color: '#223149' } },
      timeScale: { timeVisible: true, secondsVisible: false }
    });
    const series = chart.addSeries(CandlestickSeries, {
      upColor: '#31c48d', downColor: '#f87171', borderVisible: false,
      wickUpColor: '#31c48d', wickDownColor: '#f87171'
    });
    series.setData(candles.map(c => ({ ...c, time: c.time as UTCTimestamp })));
    chart.timeScale().fitContent();
    const observer = new ResizeObserver(() => chart.applyOptions({ width: element.clientWidth }));
    observer.observe(element);
    return () => { observer.disconnect(); chart.remove(); };
  }, [element, candles]);
  return <div ref={setElement} className="chart" />;
}

export default function App() {
  const [locale, setLocale] = useState<Locale>(getDefaultLocale);
  const [health, setHealth] = useState('...');
  const [modules, setModules] = useState<ModuleRow[]>([]);
  const [candles, setCandles] = useState<Candle[]>([]);
  const [quote, setQuote] = useState<Quote | null>(null);
  const t = translations[locale];
  const direction = locale === 'fa' ? 'rtl' : 'ltr';
  useEffect(() => {
    document.documentElement.lang = locale === 'fa' ? 'fa-IR' : 'en-US';
    document.documentElement.dir = direction;
    try { localStorage.setItem('tradeyar.locale', locale); } catch { /* disabled storage */ }
  }, [locale, direction]);
  useEffect(() => {
    const read = async () => {
      const fetchJson = async (url: string) => {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      };
      setHealth('...');
      setHealth(await fetchJson('/api/health').then(x => x.status as string).catch(() => 'OFFLINE'));
      setModules(await fetchJson('/api/modules').catch(() => []));
      setCandles(await fetchJson('/api/market/candles?symbol=EURUSD&limit=100').then(x => x.candles as Candle[]).catch(() => []));
      setQuote(await fetchJson('/api/market/quote?symbol=EURUSD').catch(() => null));
    };
    void read();
  }, []);
  const grouped = useMemo(() => modules.slice().sort((a,b) => a.id.localeCompare(b.id)), [modules]);
  return <div className="shell" dir={direction}>
    <aside className="sidebar">
      <div className="brand">◈ {t.app}<small>TradeYar v0.2</small></div>
      <div className="aside-label">{t.categories}</div>
      <div className="module-nav">{grouped.map(m => <div className="module-link" key={m.id}>
        <span className="module-id">{m.id}</span><span>{locale === 'fa' ? moduleNamesFa[m.id] ?? m.name : m.name}</span>
      </div>)}</div>
    </aside>
    <main className="main">
      <header className="topbar">
        <div><h1>{t.title}</h1><p>{t.note}</p></div>
        <div className="language-control"><span>{t.language}</span>
          <button type="button" aria-label="Switch language" onClick={() => setLocale(locale === 'fa' ? 'en' : 'fa')}>
            {locale === 'fa' ? 'English' : 'فارسی'}
          </button>
        </div>
      </header>
      <div className="info-grid">
        <article className="info-card"><span>{t.connection}</span><strong>{health === 'READY' ? t.ready : t.disconnected}</strong><small>{health}</small></article>
        <article className="info-card"><span>{t.modules}</span><strong>{modules.length} / 20</strong><small>{t.demo}</small></article>
        <article className="info-card"><span>{t.price}</span><strong dir="ltr">{quote ? quote.bid.toFixed(5) : '—'}</strong><small>{quote?.source ?? t.unavailable}</small></article>
        <article className="info-card"><span>{t.live}</span><strong>{t.locked}</strong><small>LOCKED</small></article>
      </div>
      <section className="surface">
        <div className="surface-head"><h2>{t.chart}</h2><span className="warning">{t.marketSource}</span></div>
        {candles.length ? <CandleChart candles={candles}/> : <p>{t.unavailable}</p>}
      </section>
      <p className="footer-warning">{t.disclaimer}</p>
    </main>
  </div>;
}