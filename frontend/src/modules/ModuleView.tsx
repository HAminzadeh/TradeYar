import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { api, post, put, pretty } from './api';
import CandleChart, {type Candle} from './CandleChart';
import { formatNumber, nameOf, type Locale, modules } from './catalog';

type AnyObj = Record<string, any>;
export type ModuleProps = {
  id: string; locale: Locale; setLocale: (v:Locale)=>void;
  theme:'dark'|'light'; setTheme:(v:'dark'|'light')=>void;
  symbol:string; setSymbol:(s:string)=>void; navigate:(s:string)=>void;
};

function useRemote(path: string | null) {
  const [data,setData] = useState<any>(null);
  const [error,setError] = useState('');
  const [loading,setLoading] = useState(false);
  const refresh = useCallback(async () => {
    if (!path) return;
    setLoading(true); setError('');
    try {setData(await api(path));} catch(e) {setError(String(e instanceof Error ? e.message : e)); setData(null);} finally {setLoading(false);}
  },[path]);
  useEffect(()=>{void refresh();},[refresh]);
  return {data,error,loading,refresh};
}
const strings = {
  fa:{refresh:'بروزرسانی',load:'در حال دریافت…',error:'خطا',submit:'ثبت',save:'ذخیره تنظیمات',demo:'دمو / اطلاعات آزمایشی',raw:'جزئیات پاسخ API',empty:'داده‌ای ثبت نشده',symbol:'نماد',strategy:'استراتژی',risk:'محاسبه حجم',evaluate:'ارزیابی',run:'اجرای بک‌تست',create:'ایجاد سفارش آزمایشی',check:'بررسی هشدارها',verify:'آزمایش قفل سفارش',read:'فقط خواندنی',selected:'بخش انتخاب‌شده',noBroker:'هیچ سفارش واقعی ارسال نمی‌شود.',source:'منبع',status:'وضعیت',reload:'بازخوانی',limited:'این قابلیت هنوز برای محیط واقعی آماده نیست.'},
  en:{refresh:'Refresh',load:'Loading…',error:'Error',submit:'Submit',save:'Save settings',demo:'Demo / synthetic data',raw:'API response details',empty:'No records yet',symbol:'Symbol',strategy:'Strategy',risk:'Calculate size',evaluate:'Evaluate',run:'Run backtest',create:'Create paper order',check:'Check alerts',verify:'Verify order lock',read:'Read-only',selected:'Selected module',noBroker:'No real orders can be submitted.',source:'Source',status:'Status',reload:'Reload',limited:'This feature is not ready for production.'},
};
function Section({title,children,aside}:{title:string;children:ReactNode;aside?:ReactNode}) {
  return <section className="module-panel"><div className="panel-heading"><h3>{title}</h3>{aside}</div>{children}</section>;
}
function ErrorText({error}:{error:string}){return error?<p className="ui-error" role="alert">{error}</p>:null;}
function Loading({loading,locale}:{loading:boolean;locale:Locale}){return loading?<p className="muted">{strings[locale].load}</p>:null;}
function Raw({data,locale}:{data:any;locale:Locale}){
  if(data===null || data===undefined) return null;
  return <details className="raw-data"><summary>{strings[locale].raw}</summary><pre dir="ltr">{pretty(data)}</pre></details>;
}
function Table({rows,locale}:{rows:AnyObj[];locale:Locale}) {
  if(!rows.length) return <p className="muted">{strings[locale].empty}</p>;
  const keys=Object.keys(rows[0]);
  return <div className="table-scroll"><table><thead><tr>{keys.map(k=><th key={k}>{k}</th>)}</tr></thead><tbody>{rows.map((r,i)=><tr key={String(r.id??i)}>{keys.map(k=><td key={k} dir={typeof r[k]==='string' && /[A-Za-z0-9]/.test(r[k])?'auto':undefined}>{typeof r[k]==='object'?pretty(r[k]):String(r[k]??'—')}</td>)}</tr>)}</tbody></table></div>;
}
function Facts({data}:{data:AnyObj|null}) {
  if(!data) return null;
  return <div className="fact-grid">{Object.entries(data).filter(([,v])=>v===null || ['string','number','boolean'].includes(typeof v)).map(([k,v])=><div className="fact" key={k}><span>{k}</span><strong dir="auto">{typeof v==='number'?formatNumber(v):String(v??'—')}</strong></div>)}</div>;
}
function RequestPanel({path,title,locale,select}:{path:string;title:string;locale:Locale;select?:(data:any)=>ReactNode}) {
  const remote=useRemote(path);const s=strings[locale];
  return <Section title={title} aside={<button onClick={()=>void remote.refresh()} className="btn-small">{s.refresh}</button>}>
    <Loading loading={remote.loading} locale={locale}/><ErrorText error={remote.error}/>
    {remote.data!==null&&(select?select(remote.data):<Facts data={remote.data}/>)}
    <Raw locale={locale} data={remote.data}/>
  </Section>;
}
function SymbolPicker({symbol,setSymbol,locale}:{symbol:string;setSymbol:(s:string)=>void;locale:Locale}) {
  return <label className="control">{strings[locale].symbol}<select dir="ltr" value={symbol} onChange={e=>setSymbol(e.target.value)}>
    {['EURUSD','GBPUSD','USDJPY','XAUUSD'].map(x=><option key={x}>{x}</option>)}
  </select></label>;
}
function BusyButton({loading,children,onClick}:{loading:boolean;children:ReactNode;onClick:()=>void}){
  return <button disabled={loading} onClick={onClick}>{loading?'…':children}</button>;
}
function useAction(){
  const [out,setOut]=useState<any>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false);
  const run=async(action:()=>Promise<any>)=>{
    setBusy(true);setError('');setOut(null);
    try {const response=await action();setOut(response);return response;}catch(e){setError(e instanceof Error?e.message:String(e));return null;}finally{setBusy(false);}
  };
  return {out,error,busy,run};
}
function ActionOutput({action,locale}:{action:ReturnType<typeof useAction>;locale:Locale}){
  return <><ErrorText error={action.error}/>{action.out!==null&&<><Facts data={action.out}/><Raw data={action.out} locale={locale}/></>}</>;
}

function Dashboard({locale,navigate}:{locale:Locale;navigate:(s:string)=>void}) {
  const health=useRemote('/api/health');
  const registry=useRemote('/api/modules');
  const quote=useRemote('/api/market/quote?symbol=EURUSD');
  const bars=useRemote('/api/market/candles?symbol=EURUSD&limit=100');
  const candles:Candle[]=bars.data?.candles??[];
  return <>
    <div className="overview-grid">
      <div className="fact"><span>{locale==='fa'?'وضعیت سرور':'Backend'}</span><strong>{health.data?.status??'—'}</strong></div>
      <div className="fact"><span>{locale==='fa'?'تعداد ماژول‌ها':'Module count'}</span><strong>{Array.isArray(registry.data)?registry.data.length:'—'} / 20</strong></div>
      <div className="fact"><span>{locale==='fa'?'قیمت نمایشی EURUSD':'EURUSD demo bid'}</span><strong dir="ltr">{quote.data?.bid??'—'}</strong></div>
      <div className="fact"><span>{locale==='fa'?'معامله واقعی':'Live trading'}</span><strong>LOCKED</strong></div>
    </div>
    <Section title={locale==='fa'?'نمودار آزمایشی EUR/USD':'EUR/USD demo chart'} aside={<button className="btn-small" onClick={()=>void bars.refresh()}>{strings[locale].refresh}</button>}>
      <p className="warning-line">SYNTHETIC_DEMO — {strings[locale].noBroker}</p>
      <ErrorText error={health.error||registry.error||bars.error||quote.error}/>
      {candles.length?<CandleChart candles={candles}/>:<p className="muted">{strings[locale].empty}</p>}
    </Section>
    <Section title={locale==='fa'?'ورود به ماژول‌ها':'Open a module'}>
      <div className="module-summary">{modules.map(m=><button className="summary-tile" key={m.id} onClick={()=>navigate(m.id)}>
        <b dir="ltr">{m.id}</b><span>{m[locale]}</span><small>{m.mode}</small>
      </button>)}</div>
    </Section>
  </>;
}
function LanguageSettings({locale,setLocale,theme,setTheme}:{locale:Locale;setLocale:(x:Locale)=>void;theme:'dark'|'light';setTheme:(x:'dark'|'light')=>void}) {
  return <Section title={locale==='fa'?'تنظیمات رابط و زبان':'Language and display'}>
    <div className="form-row"><label className="control">{locale==='fa'?'زبان':'Language'}<select value={locale} onChange={e=>setLocale(e.target.value as Locale)}><option value="fa">فارسی (RTL)</option><option value="en">English (LTR)</option></select></label>
      <label className="control">{locale==='fa'?'پوسته':'Theme'}<select value={theme} onChange={e=>setTheme(e.target.value as 'dark'|'light')}><option value="dark">Dark</option><option value="light">Light</option></select></label></div>
    <p className="muted">{locale==='fa'?'این تنظیمات در همین مرورگر ذخیره می‌شوند.':'These settings are saved in this browser.'}</p>
  </Section>;
}
function Preferences({locale}:{locale:Locale}){
  const info=useRemote('/api/preferences');const action=useAction();const [serverLocale,setServerLocale]=useState('fa-IR'),[serverTheme,setServerTheme]=useState('dark');
  useEffect(()=>{const pref=info.data?.preferences;if(pref){setServerLocale(pref.locale);setServerTheme(pref.theme);}},[info.data]);
  return <Section title={locale==='fa'?'تنظیمات آزمایشی سرور':'Server preferences (demo)'}>
    <p className="warning-line">{locale==='fa'?'این تنظیمات فعلاً بین کاربران مشترک‌اند و فقط در حافظه ذخیره می‌شوند.':'Preferences are shared and in-memory. Authentication is not implemented.'}</p>
    <div className="form-row"><label className="control">Locale<select value={serverLocale} onChange={e=>setServerLocale(e.target.value)}><option value="fa-IR">fa-IR</option><option value="en-US">en-US</option></select></label>
      <label className="control">Theme<select value={serverTheme} onChange={e=>setServerTheme(e.target.value)}><option value="dark">dark</option><option value="light">light</option></select></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(async()=>{const r=await put('/api/preferences',{locale:serverLocale,theme:serverTheme});await info.refresh();return r;})}>{strings[locale].save}</BusyButton></div>
    <Loading loading={info.loading} locale={locale}/><ErrorText error={info.error}/><ActionOutput action={action} locale={locale}/><Raw data={info.data} locale={locale}/>
  </Section>;
}
function Market({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const quote=useRemote(`/api/market/quote?symbol=${symbol}`);
  const bars=useRemote(`/api/market/candles?symbol=${symbol}&limit=100`);
  const candles: Candle[]=bars.data?.candles??[];
  return <><Section title={locale==='fa'?'قیمت نماد و کندل‌ها':'Quote and candles'} aside={<SymbolPicker symbol={symbol} setSymbol={setSymbol} locale={locale}/>}>
    <p className="warning-line">SYNTHETIC_DEMO — {strings[locale].limited}</p>
    <div className="actions"><button className="btn-small" onClick={()=>{void quote.refresh();void bars.refresh();}}>{strings[locale].refresh}</button></div>
    <ErrorText error={quote.error||bars.error}/><Facts data={quote.data}/>
    <p className="muted">{locale==='fa'?'تعداد کندل‌ها':'Candle count'}: {candles.length}</p><Table locale={locale} rows={candles.slice(-8).reverse() as unknown as AnyObj[]}/>
  </Section></>;
}
function Charts({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const remote=useRemote(`/api/charts/series?symbol=${symbol}`);const candles:Candle[]=remote.data?.candles??[];
  return <Section title={locale==='fa'?'نمودار کندل‌ها':'Candlestick chart'} aside={<SymbolPicker symbol={symbol} setSymbol={setSymbol} locale={locale}/>}>
    <p className="warning-line">SYNTHETIC_DEMO / H1 — {strings[locale].limited}</p>
    <button className="btn-small" onClick={()=>void remote.refresh()}>{strings[locale].refresh}</button>
    <ErrorText error={remote.error}/><Loading loading={remote.loading} locale={locale}/>
    {candles.length>0?<CandleChart candles={candles}/>:<p className="muted">{strings[locale].empty}</p>}
    <Raw data={{symbol,source:remote.data?.source,resolution:remote.data?.resolution,candleCount:candles.length}} locale={locale}/>
  </Section>;
}
function Strategies({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const catalog=useRemote('/api/strategies');const [strategy,setStrategy]=useState('SMA_CROSS');const action=useAction();
  const rows:any[]=Array.isArray(catalog.data)?catalog.data:[];
  return <><Section title={locale==='fa'?'ارزیابی استراتژی':'Strategy evaluation'}>
    <div className="form-row"><SymbolPicker locale={locale} symbol={symbol} setSymbol={setSymbol}/>
      <label className="control">{strings[locale].strategy}<select value={strategy} onChange={e=>setStrategy(e.target.value)}>{rows.map(r=><option key={r.id} value={r.id}>{r.id}{r.implemented?' ✓':' — planned'}</option>)}</select></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(()=>api(`/api/strategies/evaluate?symbol=${symbol}&strategy=${strategy}`))}>{strings[locale].evaluate}</BusyButton></div>
    <ActionOutput action={action} locale={locale}/>
    <p className="warning-line">{locale==='fa'?'فقط موارد دارای implemented=true منطق ارزیابی دارند؛ این خروجی توصیه مالی نیست.':'Only implemented=true has evaluation logic; not financial advice.'}</p>
  </Section><Section title={locale==='fa'?'فهرست ۲۰ استراتژی':'20-strategy catalog'}><ErrorText error={catalog.error}/><Table rows={rows} locale={locale}/></Section></>;
}
function Backtest({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const [spread,setSpread]=useState(1.5);const action=useAction();
  return <Section title={locale==='fa'?'بک‌تست آزمایشی SMA':'Synthetic SMA backtest'}>
    <div className="form-row"><SymbolPicker symbol={symbol} setSymbol={setSymbol} locale={locale}/>
      <label className="control">Spread (pips)<input type="number" min={0} max={100} step="0.1" value={spread} onChange={e=>setSpread(Number(e.target.value))}/></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(()=>api(`/api/backtest/run?symbol=${symbol}&strategy=SMA_CROSS&spreadPips=${spread}`))}>{strings[locale].run}</BusyButton></div>
    <p className="warning-line">{locale==='fa'?'نتایج با داده ساختگی و مدل محدود محاسبه می‌شوند و بیانگر عملکرد واقعی نیستند.':'Synthetic prices and limited fill model; results do not predict actual performance.'}</p>
    <ActionOutput action={action} locale={locale}/>
  </Section>;
}
function RiskCalculator({locale}:{locale:Locale}){
  const [equity,setEquity]=useState(10000),[riskPercent,setRiskPercent]=useState(0.5),[stopLossPips,setStopLoss]=useState(25),[pipValuePerLot,setPipValue]=useState(10);const action=useAction();
  return <Section title={locale==='fa'?'محاسبه حجم معامله':'Position sizing calculator'}>
    <div className="form-row"><label className="control">Equity<input type="number" min="1" value={equity} onChange={e=>setEquity(Number(e.target.value))}/></label>
      <label className="control">Risk % (max 1)<input type="number" min="0.01" max="1" step="0.1" value={riskPercent} onChange={e=>setRiskPercent(Number(e.target.value))}/></label>
      <label className="control">Stop (pips)<input type="number" min="1" value={stopLossPips} onChange={e=>setStopLoss(Number(e.target.value))}/></label>
      <label className="control">Pip value / lot<input type="number" min="0.01" value={pipValuePerLot} onChange={e=>setPipValue(Number(e.target.value))}/></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(()=>post('/api/risk/position-size',{equity,riskPercent,stopLossPips,pipValuePerLot}))}>{strings[locale].risk}</BusyButton></div>
    <ActionOutput action={action} locale={locale}/><p className="warning-line">{locale==='fa'?'مشخصات بروکر، مارجین و تبدیل ارز حساب بررسی نمی‌شوند.':'Broker contract specs, margin and conversions are not validated.'}</p>
  </Section>;
}
function Paper({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const [side,setSide]=useState('BUY'),[lots,setLots]=useState(.1);const list=useRemote('/api/paper/orders');const action=useAction();
  return <><Section title={locale==='fa'?'ایجاد سفارش صرفاً آزمایشی':'Create simulated order'}>
    <div className="form-row"><SymbolPicker symbol={symbol} setSymbol={setSymbol} locale={locale}/>
      <label className="control">Side<select value={side} onChange={e=>setSide(e.target.value)}><option>BUY</option><option>SELL</option></select></label>
      <label className="control">Lots (0.01 - 1.0)<input type="number" min="0.01" max="1" step="0.01" value={lots} onChange={e=>setLots(Number(e.target.value))}/></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(async()=>{const r=await post('/api/paper/orders',{symbol,side,lots});await list.refresh();return r;})}>{strings[locale].create}</BusyButton></div>
    <p className="warning-line">PAPER_ONLY · MEMORY_ONLY — {strings[locale].noBroker}</p>
    <ActionOutput action={action} locale={locale}/>
  </Section><Section title={locale==='fa'?'سفارش‌های ثبت‌شده':'Simulated orders'} aside={<button onClick={()=>void list.refresh()} className="btn-small">{strings[locale].refresh}</button>}>
    <ErrorText error={list.error}/><Table rows={list.data?.orders??[]} locale={locale}/></Section></>;
}
function Alerts({locale,symbol,setSymbol}:{locale:Locale;symbol:string;setSymbol:(x:string)=>void}){
  const list=useRemote('/api/alerts');const action=useAction();const check=useAction();const [when,setWhen]=useState('ABOVE'),[threshold,setThreshold]=useState(1.2);
  return <><Section title={locale==='fa'?'ثبت هشدار قیمت':'Create price alert'}>
    <div className="form-row"><SymbolPicker locale={locale} symbol={symbol} setSymbol={setSymbol}/>
      <label className="control">Condition<select value={when} onChange={e=>setWhen(e.target.value)}><option value="ABOVE">ABOVE</option><option value="BELOW">BELOW</option></select></label>
      <label className="control">Threshold<input type="number" min="0.00001" step="0.0001" value={threshold} onChange={e=>setThreshold(Number(e.target.value))}/></label>
      <BusyButton loading={action.busy} onClick={()=>void action.run(async()=>{const r=await post('/api/alerts',{symbol,when,threshold});await list.refresh();return r;})}>{strings[locale].submit}</BusyButton>
      <BusyButton loading={check.busy} onClick={()=>void check.run(()=>api('/api/alerts/check'))}>{strings[locale].check}</BusyButton></div>
    <p className="warning-line">{locale==='fa'?'بررسی دستی روی قیمت ساختگی است؛ پیامک و اعلان پس‌زمینه ارسال نمی‌شود.':'Manually checked against demo quotes; no push/email/SMS delivery.'}</p>
    <ActionOutput action={action} locale={locale}/><ActionOutput action={check} locale={locale}/>
  </Section><Section title={locale==='fa'?'هشدارهای ذخیره‌شده در حافظه':'Alerts in memory'}><ErrorText error={list.error}/><Table rows={list.data?.alerts??[]} locale={locale}/></Section></>;
}
const lessonContent = {
  intro: {
    fa: {title:'مبانی فارکس',text:'در فارکس نرخ برابری دو ارز معامله می‌شود. قیمت خرید و فروش، اسپرد، نقدشوندگی و نوسان از مفاهیم بنیادی هستند. ابتدا تفاوت داده آزمایشی و قیمت قابل معامله را بشناسید.'},
    en: {title:'Forex fundamentals',text:'Forex quotes describe the exchange rate between currency pairs. Understand bid, ask, spread, liquidity and volatility, and distinguish demo quotes from tradable market prices.'},
  },
  risk: {
    fa: {title:'مدیریت ریسک',text:'پیش از هر معامله باید سقف زیان مجاز، فاصله حد ضرر، حجم مناسب و هزینه‌ها معلوم باشند. مثال‌های محاسبه حجم آموزشی هستند و جایگزین مشخصات قرارداد بروکر نیستند.'},
    en: {title:'Risk management',text:'Define maximum loss, stop distance, position size and costs before trading. Educational sizing examples do not replace broker contract specifications.'},
  },
  backtest: {
    fa: {title:'اشتباه‌های رایج بک‌تست',text:'داده ناقص، نگاه به آینده، بهینه‌سازی بیش‌ازحد و نادیده‌گرفتن اسپرد، کمیسیون و لغزش قیمت می‌توانند نتیجه تاریخی را غیرواقعی کنند. داده ساختگی برای قضاوت درباره سودآوری کافی نیست.'},
    en: {title:'Backtesting pitfalls',text:'Incomplete data, look-ahead bias, overfitting and missing costs make results unreliable. Synthetic price series do not establish real-world profitability.'},
  },
};
function Education({locale}:{locale:Locale}) {
  const service=useRemote(`/api/education/lessons?lang=${locale}`);
  const [selected,setSelected]=useState<keyof typeof lessonContent>('intro');
  const lesson=lessonContent[selected][locale];
  return <Section title={locale==='fa'?'مرکز آموزش پایه':'Foundational learning center'}>
    <div className="lesson-tabs">{(Object.keys(lessonContent) as Array<keyof typeof lessonContent>).map(k=><button key={k} aria-pressed={selected===k} className={selected===k?'active-lesson':''} onClick={()=>setSelected(k)}>{lessonContent[k][locale].title}</button>)}</div>
    <div className="lesson-content"><h3>{lesson.title}</h3><p>{lesson.text}</p></div>
    <p className="muted">{locale==='fa'?'این آموزش مقدماتی است. اطلاعات سرویس سرور نیز برای آزمون در دسترس است.':'Introductory education only. Server lesson catalog is queried for connectivity.'}</p>
    <ErrorText error={service.error}/><Raw data={service.data} locale={locale}/>
  </Section>;
}

function LiveLock({locale}:{locale:Locale}){
  const remote=useRemote('/api/live/status');const [message,setMessage]=useState('');const [error,setError]=useState('');const [busy,setBusy]=useState(false);
  const check=async()=>{setBusy(true);setMessage('');setError('');
    try{const response=await fetch('/api/live/orders',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
      if(response.status===423){setMessage(locale==='fa'?'موفق: ثبت سفارش واقعی با HTTP 423 رد شد.':'PASS: live order rejected with HTTP 423.');}
      else {setError(`UNSAFE: expected 423, received HTTP ${response.status}. Stop testing.`);}
    }catch(e){setError(String(e));}finally{setBusy(false);}
  };
  return <Section title={locale==='fa'?'قفل سخت معاملات واقعی':'Hard-locked real-money execution'}>
    <p className="warning-line">{locale==='fa'?'این ماژول عمداً قابلیت خرید و فروش واقعی ندارد. دکمه زیر صرفاً قفل سرور را آزمایش می‌کند.':'This module deliberately cannot trade. The button only verifies the server lock.'}</p>
    <Facts data={remote.data}/><ErrorText error={remote.error}/>
    <BusyButton loading={busy} onClick={()=>void check()}>{strings[locale].verify}</BusyButton>
    {message&&<p className="ui-success" role="status">{message}</p>}<ErrorText error={error}/>
  </Section>;
}

export default function ModuleView({id,locale,setLocale,theme,setTheme,symbol,setSymbol,navigate}:ModuleProps) {
  switch(id) {
    case 'M01': return <Dashboard locale={locale} navigate={navigate}/>;
    case 'M02': return <LanguageSettings locale={locale} setLocale={setLocale} theme={theme} setTheme={setTheme}/>;
    case 'M03': return <Preferences locale={locale}/>;
    case 'M04': return <Market locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M05': return <Charts locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M06': return <RequestPanel path="/api/mt5/status" locale={locale} title={locale==='fa'?'وضعیت اتصال خواندنی متاتریدر':'MT5 read-only snapshot'} />;
    case 'M07': return <><div className="filters"><SymbolPicker locale={locale} symbol={symbol} setSymbol={setSymbol}/></div><RequestPanel path={`/api/technical/summary?symbol=${symbol}`} locale={locale} title="SMA 20 · EMA 20 · RSI 14"/></>;
    case 'M08': return <Strategies locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M09': return <Backtest locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M10': return <><div className="filters"><SymbolPicker locale={locale} symbol={symbol} setSymbol={setSymbol}/></div><RequestPanel path={`/api/signals/preview?symbol=${symbol}`} locale={locale} title={locale==='fa'?'پیش‌نمایش سیگنال بدون اجازه اجرا':'Preview-only signal'}/></>;
    case 'M11': return <RiskCalculator locale={locale}/>;
    case 'M12': return <Paper locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M13': return <RequestPanel path="/api/journal" locale={locale} title={locale==='fa'?'ژورنال پرشدن سفارش‌های آزمایشی':'Paper order journal'} select={d=><Table rows={d?.entries??[]} locale={locale}/>}/>;
    case 'M14': return <RequestPanel path="/api/news/events" locale={locale} title={locale==='fa'?'تقویم رویدادهای نمونه (غیرزنده)':'Sample economic events (not live)'} select={d=><><p className="warning-line">STATIC_EXAMPLES · NOT LIVE</p><Table rows={d?.events??[]} locale={locale}/></>}/>;
    case 'M15': return <><RequestPanel path="/api/ai/status" locale={locale} title={locale==='fa'?'وضعیت سرویس AI':'Python AI service status'}/><Section title={locale==='fa'?'محدودیت':'Limitation'}><p className="warning-line">{locale==='fa'?'مدل آموزش‌دیده و اعتبارسنجی‌شده هنوز وجود ندارد؛ هیچ پیش‌بینی قابل معامله ارائه نمی‌شود.':'No trained, validated model exists; no trade-ready predictions are available.'}</p></Section></>;
    case 'M16': return <Alerts locale={locale} symbol={symbol} setSymbol={setSymbol}/>;
    case 'M17': return <RequestPanel path="/api/reports/overview" locale={locale} title={locale==='fa'?'گزارش سفارش‌های آزمایشی':'Paper trading overview'}/>;
    case 'M18': return <Education locale={locale}/>;
    case 'M19': return <><RequestPanel path="/api/health" locale={locale} title={locale==='fa'?'پایش سرور':'Backend health'}/><RequestPanel path="/api/modules" locale={locale} title={locale==='fa'?'وضعیت ماژول‌ها':'Module registry'} select={d=><Table rows={Array.isArray(d)?d:[]} locale={locale}/>}/><Section title={locale==='fa'?'سرویس‌های خارجی':'External services'}><p className="muted">{locale==='fa'?'PostgreSQL و Redis هنوز در لایه ذخیره‌سازی این نسخه یکپارچه نشده‌اند.':'PostgreSQL and Redis are not yet connected to application repositories.'}</p></Section></>;
    case 'M20': return <LiveLock locale={locale}/>;
    default: return <Section title={nameOf(id,locale)}><p>{strings[locale].empty}</p></Section>;
  }
}
