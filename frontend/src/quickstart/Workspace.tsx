import {useCallback,useEffect,useMemo,useState} from 'react';
import CandleChart,{type Candle} from '../modules/CandleChart';
import {api,post} from '../modules/api';
import type {Locale} from '../modules/catalog';
import {PROFILES} from '../modules/profiles';
import {explainRisk,type WizardConfig} from './config';
import './workspace-v05.css';

type Strategy={id:string;signal:'BUY'|'SELL'|'NO_SIGNAL'|'NOT_EVALUATED';implemented:boolean;independentlyValidated:boolean;reason:string;barsUsed:number};
type Snapshot={symbol:string;style:string;requestedTimeframe:string;effectiveTimeframe:string;requestedTimeframeApplied:boolean;source:string;verifiedBrokerFeed:boolean;localReadOnlyCsvAvailable:boolean;fresh:boolean;lastClosedBarUtc:string;sampledAtUtc:string;feedNote:string;quote:{bid:number;ask:number};candles:Candle[];strategies:Strategy[];counts:{BUY:number;SELL:number;NO_SIGNAL:number;NOT_EVALUATED:number};strategyCount:number;aligned:number;minimumAligned:number;decision:string;entryAllowed:boolean;validationNote:string};
type Props={locale:Locale;config:WizardConfig;onEdit:()=>void;onLearning:()=>void};
function signalFa(v:string,fa:boolean){return ({BUY:fa?'خرید':'BUY',SELL:fa?'فروش':'SELL',NO_SIGNAL:fa?'بدون سیگنال':'NO SIGNAL',NOT_EVALUATED:fa?'قابل ارزیابی نیست':'NOT EVALUATED'} as Record<string,string>)[v]||v;}
const errorMessage=(e:unknown)=>e instanceof Error?e.message:String(e);
export default function Workspace({locale,config,onEdit,onLearning}:Props){
 const fa=locale==='fa'; const profile=PROFILES.find(p=>p.id===config.style);
 const [data,setData]=useState<Snapshot|null>(null),[error,setError]=useState(''),[state,setState]=useState<'CONNECTING'|'SSE'|'POLLING'|'STOPPED'>('CONNECTING');
 const [running,setRunning]=useState(true),[last,setLast]=useState(''),[selected,setSelected]=useState('');
 const [risk,setRisk]=useState<Record<string,unknown>|null>(null),[riskError,setRiskError]=useState('');
 const [side,setSide]=useState<'BUY'|'SELL'>('BUY'),[paperBusy,setPaperBusy]=useState(false),[paperResult,setPaperResult]=useState('');
 const path=useMemo(()=>`/api/v06/snapshot?symbol=${encodeURIComponent(config.symbol)}&timeframe=${encodeURIComponent(config.timeframe)}&style=${encodeURIComponent(config.style)}`,[config.symbol,config.timeframe,config.style]);
 const streamPath=path.replace('/snapshot?','/stream?');
 const refresh=useCallback(async()=>{try{const next=await api(path) as Snapshot;setData(next);setError('');setLast(new Date().toISOString());}catch(e){setError(errorMessage(e));}},[path]);
 useEffect(()=>{void refresh();},[refresh]);
 useEffect(()=>{
   if(!running){setState('STOPPED');return;}
   let active=true;let source:EventSource|null=null;let timer:number|undefined;
   const usePolling=()=>{if(!active||timer!==undefined)return;setState('POLLING');timer=window.setInterval(()=>{if(!document.hidden)void refresh();},15000);};
   try{
     source=new EventSource(streamPath);
     source.addEventListener('snapshot',(evt:MessageEvent)=>{if(!active)return;try{setData(JSON.parse(evt.data) as Snapshot);setError('');setLast(new Date().toISOString());setState('SSE');}catch(e){setError(errorMessage(e));}});
     source.onerror=()=>{if(active){setState('POLLING');usePolling();source?.close();}};
   }catch{usePolling();}
   return()=>{active=false;source?.close();if(timer!==undefined)window.clearInterval(timer);};
 },[running,streamPath,refresh]);
 useEffect(()=>{let active=true;setRisk(null);setRiskError('');
   post('/api/risk/position-size',{equity:config.equity,riskPercent:config.riskPercent,stopLossPips:config.stopPips,pipValuePerLot:config.pipValuePerLot})
    .then(x=>{if(active)setRisk(x as Record<string,unknown>);}).catch(e=>{if(active)setRiskError(errorMessage(e));});
   return()=>{active=false;};
 },[config.equity,config.riskPercent,config.stopPips,config.pipValuePerLot]);
 const estimated=explainRisk(config),actualLots=typeof risk?.lots==='number'?risk.lots:estimated.lots;
 const rows=data?.strategies||[],chosen=rows.find(r=>r.id===selected);
 async function submitPaper(){
   if(config.mode!=='DEMO'||!data||!Number.isFinite(actualLots)||actualLots<.01||actualLots>1)return;
   const yes=window.confirm(fa?`ثبت سفارش کاملاً آزمایشی ${side} با حجم ${actualLots} لات، مستقل از سیگنال‌ها؟`:`Manual PAPER-ONLY ${side} ${actualLots} lots independent of algorithm signals?`);
   if(!yes)return;
   setPaperBusy(true);setPaperResult('');try{const response=await post('/api/paper/orders',{symbol:config.symbol,side,lots:actualLots});setPaperResult((fa?'شناسه سفارش آموزشی: ':'Paper order ID: ')+String(response.id));}catch(e){setPaperResult(errorMessage(e));}finally{setPaperBusy(false);}
 }
 return <div className="v05-workspace">
  <section className="qs-panel">
   <div className="qs-heading-inline"><div><span className="qs-eyebrow">TRADEYAR v0.6 · RESEARCH / STREAMING</span><h2>{fa?'میزکار هوشمند تحلیل':'Strategy monitoring workspace'}</h2><p>{profile?.[locale]||config.style} · {config.symbol} · {config.timeframe} · {config.mode==='DEMO'?'PAPER':'REAL VIEW ONLY'}</p></div><div className="qs-tools"><button className="qs-ghost" onClick={onEdit}>{fa?'تغییر تنظیمات':'Edit wizard'}</button><button className="qs-ghost" onClick={onLearning}>{fa?'مرکز دانش':'Research'}</button></div></div>
   <div className="v05-tags"><span>{data?.source||'CONNECTING'}</span><span>{fa?'تایم‌فریم واقعی: ':'Effective timeframe: '}{data?.effectiveTimeframe||'—'}</span><span>{data?.fresh?'FRESH':'STALE / DEMO'}</span><span>REAL EXECUTION LOCKED</span></div>
   <div className="qs-stat-grid"><div><span>{fa?'قیمت Bid':'Bid'}</span><strong dir="ltr">{data?.quote?.bid??'—'}</strong></div><div><span>{fa?'۲۰ الگوریتم':'Strategies'}</span><strong>{rows.length} / 20</strong></div><div><span>{fa?'ارتباط':'Transport'}</span><strong>{state}</strong></div><div><span>{fa?'نتیجه':'Decision'}</span><strong>{data?.decision||'WAITING'}</strong></div></div>
   <div className="qs-chart-header"><h3>{fa?'نمودار قیمت':'Market chart'} · {config.symbol}</h3><div className="qs-tools"><label className="qs-inline-toggle"><input type="checkbox" checked={running} onChange={(e:any)=>setRunning(e.target.checked)}/>{fa?'پایش خودکار':'Auto monitor'}</label><button className="qs-primary" onClick={()=>void refresh()}>{fa?'بازخوانی':'Refresh'}</button></div></div>
   {error&&<p role="alert" className="qs-error">{error}</p>}
   {!data?.localReadOnlyCsvAvailable&&<p className="qs-tip">{fa?'نمودار و سیگنال‌ها بر پایه داده نمایشی H1 هستند؛ قیمت لحظه‌ای بازار نیستند.':'Synthetic H1 bars; NOT a real-time market feed. Wizard timeframe may not be applied.'}</p>}
   {data?.feedNote&&<p className="qs-subnote">{data.feedNote}</p>}
   {data?.candles?.length?<CandleChart candles={data.candles}/>:<p>{fa?'در انتظار دریافت داده…':'Loading chart…'}</p>}
   <p className="qs-subnote">{fa?'آخرین دریافت: ':'Last update: '}{last?new Date(last).toLocaleTimeString(fa?'fa-IR':'en-US'):'—'} · {fa?'آخرین کندل بسته: ':'Last closed bar: '}{data?.lastClosedBarUtc||'—'}</p>
  </section>
  <section className="qs-panel">
   <div className="qs-heading-inline"><div><span className="qs-eyebrow">20-STRATEGY SCANNER</span><h2>{fa?'پایش و رأی‌گیری استراتژی‌ها':'Strategy monitor and votes'}</h2></div><span>{state==='SSE'?(fa?'جریان متصل':'Stream connected'):(fa?'اتصال / بازخوانی':'Connecting / polling')}</span></div>
   <div className="qs-vote-grid"><div className="qs-buy"><span>{fa?'نامزد خرید':'BUY'}</span><strong>{data?.counts?.BUY??0}</strong></div><div className="qs-sell"><span>{fa?'نامزد فروش':'SELL'}</span><strong>{data?.counts?.SELL??0}</strong></div><div><span>{fa?'بدون سیگنال':'NO SIGNAL'}</span><strong>{data?.counts?.NO_SIGNAL??0}</strong></div><div><span>{fa?'ارزیابی‌نشده':'NOT EVALUATED'}</span><strong>{data?.counts?.NOT_EVALUATED??0}</strong></div></div>
   <p className="qs-tip" role="status">{fa?'نتیجه صرفاً پژوهشی است. هیچ‌یک از ۲۰ الگوریتم هنوز اعتبارسنجی مستقل لازم برای پیشنهاد ورود را ندارند. حتی ۱۶ رأی هم تأیید سودآوری نیست.':'Educational signals only. None of the 20 algorithms has independent out-of-sample validation. Even 16 aligned votes do not imply profitability.'}</p>
   <div className="qs-scan-table" role="table" aria-label="strategy results"><div className="qs-scan-head" role="row"><span>{fa?'استراتژی':'Strategy'}</span><span>{fa?'رأی آزمایشی':'Demo vote'}</span></div>{rows.map((r,i)=><button type="button" className="v05-strategy-row" key={r.id} onClick={()=>setSelected(selected===r.id?'':r.id)} aria-expanded={selected===r.id}><span dir="ltr"><small>{String(i+1).padStart(2,'0')}</small> {r.id}</span><span className={'v05-vote '+r.signal}>{signalFa(r.signal,fa)}</span></button>)}</div>
   {chosen&&<div className="v05-strategy-detail"><strong>{chosen.id}</strong><p>{chosen.reason}</p><p>{fa?'اعتبارسنجی مستقل: انجام نشده':'Independent validation: NOT DONE'} · {fa?'کندل بررسی‌شده: ':'Bars: '}{chosen.barsUsed}</p></div>}
  </section>
  <section className="qs-panel"><span className="qs-eyebrow">RISK / PAPER ONLY</span><h2>{fa?'مدیریت ریسک و سفارش آزمایشی':'Risk and paper order'}</h2>
   <div className="qs-stat-grid"><div><span>{fa?'سرمایه واردشده':'Equity entered'}</span><strong>{config.equity}</strong></div><div><span>{fa?'بودجه ریسک فرضی':'Risk budget'}</span><strong>{estimated.riskBudget.toFixed(2)}</strong></div><div><span>{fa?'حجم آموزشی':'Indicative lots'}</span><strong>{actualLots}</strong></div><div><span>{fa?'اهرم فرضی':'Leverage scenario'}</span><strong>1:{config.leverageScenario}</strong></div></div>
   <p className="qs-tip">{fa?'حجم و اهرم نهایی نیازمند اطلاعات واقعی حساب، مشخصات قرارداد، مارجین، کمیسیون و لغزش هستند. سیگنال فعلی اجازه ورود نمی‌دهد.':'Actual sizing and leverage require broker contract, margin, fees, conversion and slippage. No current signal authorizes an entry.'}</p>
   {riskError&&<p role="alert" className="qs-error">{riskError}</p>}
   {config.mode==='DEMO'?<div className="qs-paper"><label>{fa?'جهت سفارش دستی فقط دمو':'Manual demo direction'}<select value={side} onChange={(e:any)=>setSide(e.target.value as 'BUY'|'SELL')}><option>BUY</option><option>SELL</option></select></label><button className="qs-primary" disabled={paperBusy||!data||actualLots<.01||actualLots>1} onClick={()=>void submitPaper()}>{fa?'ثبت سفارش دستی آزمایشی':'Manual paper order'}</button></div>:<p className="qs-error">{fa?'حالت Real فقط برای مشاهده است. رمز حساب را در این بخش وارد نکن؛ سفارش واقعی قفل است.':'REAL is view-only. Do not enter credentials here; real orders are locked.'}</p>}
   {paperResult&&<p role="status" className="qs-subnote">{paperResult}</p>}
  </section>
 </div>;
}
