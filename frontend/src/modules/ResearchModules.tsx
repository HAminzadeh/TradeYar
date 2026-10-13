import {useCallback,useEffect,useState,type ReactNode} from 'react';
import {api} from './api';
import type {Locale} from './catalog';
import {PROFILES,defaults,loadSettings,resetSettings,storeSettings,type WorkstationSettings,type TradingStyle} from './profiles';

type Props={id:string;locale:Locale;symbol:string;onSymbol:(s:string)=>void};
type JsonRecord=Record<string,unknown>;
function useResearch(path:string){
  const [data,setData]=useState<JsonRecord|null>(null);const [error,setError]=useState('');const [busy,setBusy]=useState(false);
  const reload=useCallback(async()=>{setBusy(true);setError('');try{setData(await api(path));}catch(e){setError(e instanceof Error?e.message:String(e));setData(null);}finally{setBusy(false);}},[path]);
  useEffect(()=>{void reload();},[reload]);return {data,error,busy,reload};
}
function Notice({children}:{children:ReactNode}){return <p className="warning-line">{children}</p>;}
function JsonDebug({data}:{data:unknown}){return <details className="raw-data"><summary>API / JSON</summary><pre dir="ltr">{JSON.stringify(data,null,2)}</pre></details>;}
export function useWorkstation(){
  const [settings,setSettings]=useState<WorkstationSettings>(loadSettings);
  const save=(s:WorkstationSettings)=>{setSettings(s);storeSettings(s);};
  const reset=(style?:TradingStyle)=>{const next=resetSettings(style);setSettings(next);};
  return {settings,save,reset};
}
function Styles({locale}:{locale:Locale}){
  const {settings,save,reset}=useWorkstation();const fa=locale==='fa';
  const selected=PROFILES.find(p=>p.id===settings.style)??PROFILES[1];
  function select(style:TradingStyle){save(defaults(style));}
  return <div className="module-panel">
    <h3>{fa?'انتخاب سبک معامله‌گری — M22':'Trading style profiles — M22'}</h3>
    <Notice>{fa?'این تنظیمات برای تحلیل و معاملات کاغذی است. پارامترها هنوز روی بازار واقعی اعتبارسنجی نشده‌اند.':'These research/paper defaults are not validated trading parameters.'}</Notice>
    <div className="style-grid">{PROFILES.map(p=><button type="button" className={'style-choice'+(settings.style===p.id?' active':'')} key={p.id} onClick={()=>select(p.id)} aria-pressed={settings.style===p.id}>
      <strong>{p[locale]}</strong><span>{p.timeframe}</span><small>{fa?p.noteFa:p.noteEn}</small>
    </button>)}</div>
    <div className="form-row"><label className="control">{fa?'تایم‌فریم سیگنال':'Signal timeframe'}
      <select value={settings.timeframe} onChange={e=>save({...settings,timeframe:e.target.value})}>
      {['M1','M5','M15','M30','H1','H4','D1','W1','MN1'].map(tf=><option key={tf}>{tf}</option>)}</select></label>
      <label className="control">{fa?'حداقل اجماع':'Consensus minimum'} (%)
      <input type="number" min="80" max="100" step="5" value={settings.consensusPercent} onChange={e=>save({...settings,consensusPercent:Math.max(80,Math.min(100,Math.round(Number(e.target.value)||80)))})}/></label>
      <label className="control">{fa?'حداکثر ریسک کاغذی':'Max paper risk'} (%)
      <input type="number" min="0.01" max={selected.maxPaperRiskPercent} step="0.01" value={settings.maxPaperRiskPercent} onChange={e=>save({...settings,maxPaperRiskPercent:Math.min(selected.maxPaperRiskPercent,Math.max(.01,Number(e.target.value)||.01))})}/></label>
    </div>
    <p className="muted">{fa?'تایم‌فریم تأیید: ':'Confirmation frames: '}{selected.confirmations.join(' / ')}</p>
    <button type="button" onClick={()=>reset(settings.style)}>{fa?'بازنشانی پیش‌فرض این سبک':'Reset selected style defaults'}</button>
    <button type="button" onClick={()=>reset()}>{fa?'بازنشانی کل پروفایل':'Reset entire profile'}</button>
    <JsonDebug data={settings}/>
  </div>;
}
function Consensus({locale,symbol,onSymbol}:{locale:Locale;symbol:string;onSymbol:(s:string)=>void}){
  const fa=locale==='fa';const {settings}=useWorkstation();
  const result=useResearch(`/api/v1/research/consensus?symbol=${encodeURIComponent(symbol)}&style=${settings.style}`);
  const votes=(result.data?.votes??{}) as Record<string,unknown>;
  return <div className="module-panel">
    <h3>{fa?'M21 — مرکز اجماع استراتژی‌ها':'M21 — Strategy consensus center'}</h3>
    <Notice>{fa?'این نسخه فقط سه استراتژی اولیه را محاسبه می‌کند. اجماع معتبر ۱۶ از ۲۰ هنوز ممکن نیست؛ این صفحه هیچ توصیه عملی برای ورود صادر نمی‌کند.':'Only three strategies have demo evaluation logic. 16/20 consensus is impossible in this release. No actionable entry is issued.'}</Notice>
    <div className="form-row"><label className="control">{fa?'نماد':'Symbol'}<select value={symbol} onChange={e=>onSymbol(e.target.value)}>{['EURUSD','GBPUSD','USDJPY','XAUUSD'].map(s=><option key={s}>{s}</option>)}</select></label>
      <button onClick={()=>void result.reload()} disabled={result.busy}>{fa?'ارزیابی مجدد':'Evaluate again'}</button></div>
    {result.error&&<p className="ui-error" role="alert">{result.error}</p>}
    <div className="fact-grid">
      {([['strategyCount',fa?'استراتژی مورد نیاز':'Required strategies'],['evaluatedCount',fa?'استراتژی ارزیابی شده':'Evaluated'],['minimumAligned',fa?'حداقل آرا':'Minimum votes'],['outcome',fa?'نتیجه':'Decision']]).map(([key,label])=><div key={key} className="fact"><span>{label}</span><strong>{String(result.data?.[key]??'—')}</strong></div>)}
    </div>
    <p className="muted">BUY {String(votes.BUY??0)} · SELL {String(votes.SELL??0)} · NO_SIGNAL {String(votes.NO_SIGNAL??0)}</p>
    {result.data&&<JsonDebug data={result.data}/>}
  </div>;
}
function Knowledge({locale}:{locale:Locale}){
  const fa=locale==='fa';const {settings}=useWorkstation();
  const result=useResearch(`/api/v1/research/knowledge/overview?symbol=${settings.symbol}&style=${settings.style}`);
  const strategyNames=['SMA_CROSS','EMA_CROSS','TRIPLE_EMA','SUPERTREND','MACD','RSI_REVERSAL','STOCHASTIC','CCI','DONCHIAN_BREAKOUT','ATR_BREAKOUT','BOLLINGER_SQUEEZE','LONDON_BREAKOUT','BOLLINGER_MEAN_REVERSION','RSI_DIVERGENCE','KELTNER_MEAN_REVERSION','PIN_BAR','ENGULFING','PIVOT_POINT','ICHIMOKU','MULTI_TF_EMA_ADX'];
  return <div className="module-panel">
    <h3>{fa?'M23 — مدیریت دانش و یادگیری استراتژی‌ها':'M23 — Strategy knowledge management'}</h3>
    <Notice>{fa?'هیچ داده ده‌ساله بارگذاری یا مدل آموزش‌دیده‌ای ثبت نشده است. این بخش فعلاً وضعیت پژوهش و الزامات کیفیت را نشان می‌دهد.':'No ten-year dataset has been imported and no model has been trained. This is the research readiness view.'}</Notice>
    <div className="fact-grid">
      <div className="fact"><span>{fa?'وضعیت پژوهش':'Research status'}</span><strong>{String(result.data?.status??'—')}</strong></div>
      <div className="fact"><span>{fa?'پوشش تاریخی تأییدشده':'Verified coverage'}</span><strong>{String(result.data?.verifiedCoverageYears??0)} {fa?'سال':'years'}</strong></div>
      <div className="fact"><span>{fa?'مدل معتبر':'Validated ML model'}</span><strong>{String(result.data?.validatedModel??false)}</strong></div>
    </div>
    {result.error&&<p className="ui-error">{result.error}</p>}
    <p className="muted">{fa?'فهرست راهبردهای پژوهشی — هنوز داده یا عملکرد معتبر ثبت نشده است.':'Research strategy catalog — no verified research outcomes yet.'}</p>
    <div className="table-scroll"><table><thead><tr><th>{fa?'استراتژی':'Strategy'}</th><th>{fa?'وضعیت دانش':'Evidence'}</th></tr></thead><tbody>{strategyNames.map(s=><tr key={s}><td>{s}</td><td>WAITING_FOR_DATA</td></tr>)}</tbody></table></div>
    {result.data&&<JsonDebug data={result.data}/>}
  </div>;
}
export default function ResearchModules({id,locale,symbol,onSymbol}:Props){
  if(id==='M21')return <Consensus locale={locale} symbol={symbol} onSymbol={onSymbol}/>;
  if(id==='M22')return <Styles locale={locale}/>;
  return <Knowledge locale={locale}/>;
}
