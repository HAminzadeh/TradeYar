// tradeyar-ui-v03: keep this marker for source generator safeguards
import { useEffect, useState } from 'react';
import ModuleView from './modules/ModuleView';
import { modules, type Locale } from './modules/catalog';
import { api } from './modules/api';

function readLocale():Locale {
  try { return localStorage.getItem('tradeyar.locale')==='en'?'en':'fa'; } catch {return 'fa';}
}
function readTheme():'dark'|'light' {
  try {return localStorage.getItem('tradeyar.theme')==='light'?'light':'dark';}catch{return 'dark';}
}
function readModule():string {
  const candidate=location.hash.replace(/^#\/?/,'').toUpperCase();
  return modules.some(m=>m.id===candidate)?candidate:'M01';
}
export default function App(){
  const [locale,setLocale]=useState<Locale>(readLocale);
  const [theme,setTheme]=useState<'dark'|'light'>(readTheme);
  const [selected,setSelected]=useState(readModule);
  const [symbol,setSymbol]=useState('EURUSD');
  const [health,setHealth]=useState('...');
  const current=modules.find(m=>m.id===selected)??modules[0];
  function navigate(id:string){setSelected(id);location.hash=id;}
  useEffect(()=>{
    const update=()=>setSelected(readModule());
    addEventListener('hashchange',update);
    return ()=>removeEventListener('hashchange',update);
  },[]);
  useEffect(()=>{
    document.documentElement.lang=locale==='fa'?'fa-IR':'en-US';
    document.documentElement.dir=locale==='fa'?'rtl':'ltr';
    document.documentElement.setAttribute('data-theme',theme);
    try {localStorage.setItem('tradeyar.locale',locale);localStorage.setItem('tradeyar.theme',theme);}catch{/* Storage disabled */}
  },[locale,theme]);
  useEffect(()=>{
    let active=true;
    api('/api/health').then(d=>{if(active)setHealth(String(d.status));}).catch(()=>{if(active)setHealth('OFFLINE');});
    return ()=>{active=false;};
  },[]);
  const isFa=locale==='fa';
  return <div className="shell">
    <aside className="sidebar" aria-label={isFa?'ماژول‌های تریدیار':'TradeYar modules'}>
      <button className="brand" onClick={()=>navigate('M01')} aria-label="TradeYar Dashboard">◇ {isFa?'تریدیار':'TradeYar'}<small>TradeYar v0.3 · DEMO</small></button>
      <div className="aside-label">{isFa?'خدمات و ماژول‌ها':'Services & modules'}</div>
      <nav className="module-nav">{modules.map(m=><button type="button" className={'module-link'+(m.id===selected?' selected':'')} onClick={()=>navigate(m.id)} key={m.id} aria-current={m.id===selected?'page':undefined}>
        <span className="module-id" dir="ltr">{m.id}</span><span>{m[locale]}</span><span className="module-arrow" aria-hidden="true">›</span>
      </button>)}</nav>
    </aside>
    <main className="main" id="content">
      <header className="topbar">
        <div><div className="kicker">TradeYar / {selected}</div><h1>{current[locale]}</h1><p>{isFa?current.descriptionFa:current.descriptionEn}</p></div>
        <div className="top-actions"><span className={'status-pill'+(health==='READY'?' online':'')} title="Spring Boot">● {health}</span>
          <button type="button" className="btn-small" aria-label="Switch language" onClick={()=>setLocale(locale==='fa'?'en':'fa')}>{isFa?'English':'فارسی'}</button>
        </div>
      </header>
      <div className="module-meta"><span className="mode-pill">{selected} · {current.mode}</span><span>{isFa?'محیط توسعه و شبیه‌سازی؛ نه حساب معاملاتی واقعی':'Development / simulation, not a real trading account'}</span></div>
      <div key={selected} className="module-content"><ModuleView id={selected} locale={locale} setLocale={setLocale} theme={theme} setTheme={setTheme} symbol={symbol} setSymbol={setSymbol} navigate={navigate}/></div>
      <footer>{isFa?'داده‌های ساختگی برای معامله واقعی مناسب نیستند و اجرای واقعی غیرفعال است.':'Synthetic quotes are not suitable for actual trading. Live execution is disabled.'}</footer>
    </main>
  </div>;
}
