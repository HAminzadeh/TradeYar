// TradeYar v0.4.1: simple quick-start experience. Keep v0.3 marker for legacy generator safeguards.
// tradeyar-ui-v03
import {useEffect,useState} from 'react';
import ModuleView from './modules/ModuleView';
import ResearchModules from './modules/ResearchModules';
import {modules,type Locale} from './modules/catalog';
import {GUIDES} from './modules/guides';
import {api} from './modules/api';
import Wizard from './quickstart/Wizard';
import Workspace from './quickstart/Workspace';
import Learning from './quickstart/Learning';
import AppearanceView from './quickstart/Appearance';
import HelpCenter from './help/HelpCenter';
import {APPEARANCE_KEY,LAYOUT_KEY,readAppearance,readLayout,readWizard,saveWizard,type WizardConfig,type Appearance,type Layout} from './quickstart/config';
import './quickstart.css';

type Route='START'|'WORKSPACE'|'LEARN'|'LOOK'|'HELP'|string;
const groups=[
 {fa:'داشبورد و تصمیم‌گیری',en:'Decision tools',ids:['M01','M21','M10','M16']},
 {fa:'بازار و ارتباطات',en:'Markets',ids:['M04','M05','M06','M14']},
 {fa:'استراتژی و پژوهش',en:'Strategies & research',ids:['M22','M08','M07','M09','M23','M15']},
 {fa:'ریسک و معاملات آزمایشی',en:'Risk & paper trading',ids:['M11','M12','M13','M17']},
 {fa:'آموزش و تنظیمات',en:'Education & settings',ids:['M18','M02','M03','M19','M20']}
];
function routeFromHash():Route{
 const s=decodeURIComponent(window.location.hash.replace(/^#\/?/,'')).toUpperCase();
 if(['START','WORKSPACE','LEARN','LOOK','HELP'].includes(s))return s;
 if(s==='M01'||!s)return 'START';
 if(modules.some(m=>m.id===s))return s;
 return 'START';
}
function initialLocale():Locale{try{return localStorage.getItem('tradeyar.locale')==='en'?'en':'fa';}catch{return 'fa';}}
export default function App(){
 const [locale,setLocale]=useState<Locale>(initialLocale);
 const [route,setRoute]=useState<Route>(routeFromHash);
 const [config,setConfig]=useState<WizardConfig>(readWizard);
 const [theme,setTheme]=useState<Appearance>(readAppearance);
 const [layout,setLayout]=useState<Layout>(readLayout);
 const [legacyTheme,setLegacyTheme]=useState<'dark'|'light'>(()=>readAppearance()==='day'?'light':'dark');
 const [health,setHealth]=useState('...');
 const [advanced,setAdvanced]=useState(false);
 const [guide,setGuide]=useState(false);
 const [symbol,setSymbol]=useState(config.symbol);
 const fa=locale==='fa';
 const advancedPage=modules.find(m=>m.id===route);
 const title=route==='START'?(fa?'شروع سریع':'Quick start'):route==='WORKSPACE'?(fa?'میزکار معامله':'Trading workspace'):route==='LEARN'?(fa?'مدیریت دانش':'Learning center'):route==='LOOK'?(fa?'ظاهر و چیدمان':'Appearance'):route==='HELP'?(fa?'راهنمای گام‌به‌گام':'Help Center'):advancedPage?.[locale]??'TradeYar';
 function navigate(id:string){window.location.hash=id;setRoute(id);setGuide(false);if(id.startsWith('M'))setAdvanced(true);}
 function complete(next:WizardConfig){saveWizard(next);setConfig(next);setSymbol(next.symbol);navigate('WORKSPACE');}
 function changeTheme(t:Appearance){setTheme(t);setLegacyTheme(t==='day'?'light':'dark');}
 useEffect(()=>{const f=()=>setRoute(routeFromHash());window.addEventListener('hashchange',f);return()=>window.removeEventListener('hashchange',f);},[]);
 useEffect(()=>{document.documentElement.lang=fa?'fa-IR':'en-US';document.documentElement.dir=fa?'rtl':'ltr';document.documentElement.setAttribute('data-theme',theme);document.documentElement.setAttribute('data-layout',layout);try{localStorage.setItem('tradeyar.locale',locale);localStorage.setItem('tradeyar.theme',theme==='day'?'light':'dark');localStorage.setItem(APPEARANCE_KEY,theme);localStorage.setItem(LAYOUT_KEY,layout);}catch{/* browser storage disabled */}},[fa,locale,theme,layout]);
 useEffect(()=>{let active=true;api('/api/health').then(x=>{if(active)setHealth(String(x.status));}).catch(()=>{if(active)setHealth('OFFLINE');});return()=>{active=false;};},[]);
 const mainNav=[{id:'START',fa:'شروع سریع',en:'Quick start'},{id:'WORKSPACE',fa:'میزکار',en:'Workspace'},{id:'LEARN',fa:'مدیریت دانش',en:'Learning'},{id:'LOOK',fa:'ظاهر',en:'Appearance'},{id:'HELP',fa:'راهنمای نرم‌افزار',en:'Help Center'}];
 const docs=GUIDES.find(g=>g.id===route);
 return <div className={'qs-app qs-layout-'+layout} dir={fa?'rtl':'ltr'}>
  <aside className="qs-sidebar" aria-label={fa?'منوی اصلی':'Main menu'}>
   <button type="button" className="qs-brand" onClick={()=>navigate('START')}><span className="qs-logo">◇</span><span>{fa?'تریدیار':'TradeYar'}<small>v0.6 · RESEARCH / PAPER</small></span></button>
   <nav className="qs-main-nav" aria-label={fa?'مسیرهای اصلی':'Main routes'}>{mainNav.map(n=><button type="button" key={n.id} className={route===n.id?'active':''} onClick={()=>navigate(n.id)} aria-current={route===n.id?'page':undefined}>{n[locale]}</button>)}</nav>
   <div className="qs-advanced-nav"><button type="button" className="qs-advanced-toggle" aria-expanded={advanced} onClick={()=>setAdvanced(!advanced)}>{fa?'ابزارهای تخصصی':'Advanced tools'} <span>{advanced?'−':'+'}</span></button>
     {advanced&&<div className="qs-advanced-inner">{groups.map((g,i)=><details key={i} open={Boolean(advancedPage&&g.ids.includes(route))}><summary>{g[locale]}</summary>{g.ids.map(id=>{const m=modules.find(x=>x.id===id);return m?<button type="button" key={id} onClick={()=>navigate(id)} className={route===id?'active':''}><span dir="ltr">{id}</span> {m[locale]}</button>:null;})}</details>)}</div>}
   </div><p className="qs-side-foot">{fa?'وضعیت اجرا: فقط آزمایشی':'Execution: paper only'}<br/><strong>LIVE ORDERS LOCKED</strong></p>
  </aside>
  <main className="qs-content" id="content">
   <header className="qs-global-header"><div><span className="qs-eyebrow">TRADEYAR / {route}</span><h1>{title}</h1></div><div className="qs-global-actions"><span className={'qs-health '+(health==='READY'?'ready':'')}>● {health}</span><button type="button" className="qs-ghost" onClick={()=>setLocale(fa?'en':'fa')}>{fa?'English':'فارسی'}</button></div></header>
   {route==='START'?<Wizard initial={config} locale={locale} onFinish={complete}/>:
    route==='WORKSPACE'?<Workspace locale={locale} config={config} onEdit={()=>navigate('START')} onLearning={()=>navigate('LEARN')}/>:
    route==='LEARN'?<Learning locale={locale}/>:
    route==='LOOK'?<AppearanceView locale={locale} theme={theme} setTheme={changeTheme} layout={layout} setLayout={setLayout}/>:route==='HELP'?<HelpCenter locale={locale} onNavigate={navigate}/>:
    <div className="qs-advanced-page"><div className="qs-tools qs-advanced-header"><button type="button" className="qs-ghost" onClick={()=>navigate('START')}>{fa?'بازگشت به شروع سریع':'Back to quick start'}</button><button type="button" className="qs-ghost" onClick={()=>setGuide(!guide)}>{fa?'راهنمای بخش':'Module guide'}</button></div>
     {guide&&docs&&<section className="qs-panel"><h3>{docs[locale]}</h3><p>{fa?docs.whatFa:docs.whatEn}</p><p>{fa?docs.howFa:docs.howEn}</p><p>{fa?docs.defaultFa:docs.defaultEn}</p></section>}
     {['M21','M22','M23'].includes(route)?<ResearchModules id={route} locale={locale} symbol={symbol} onSymbol={s=>setSymbol(s as WizardConfig['symbol'])}/>:
       <ModuleView id={route} locale={locale} setLocale={setLocale} theme={legacyTheme} setTheme={t=>changeTheme(t==='light'?'day':'night')} symbol={symbol} setSymbol={s=>setSymbol(s as WizardConfig['symbol'])} navigate={navigate}/>}
    </div>}
   <footer className="qs-footer-note">{fa?'داده ساختگی و سیگنال‌های تأییدنشده، توصیه ورود واقعی نیستند. اجرای سفارش واقعی در سرور قفل شده است.':'Synthetic prices and unvalidated signals are not live trading advice. Live execution is hard-locked on the server.'}</footer>
  </main>
 </div>;
}
