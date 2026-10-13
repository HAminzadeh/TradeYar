import {useEffect,useState} from 'react';
import {api,post} from '../modules/api';
import type {Locale} from '../modules/catalog';
const SYM=['EURUSD','GBPUSD','USDJPY','XAUUSD'];
export default function Learning({locale}:{locale:Locale}){
 const fa=locale==='fa';const [status,setStatus]=useState<Record<string,unknown>|null>(null),[model,setModel]=useState<Record<string,unknown>|null>(null);
 const [sym,setSym]=useState('EURUSD'),[tf,setTf]=useState('H1'),[spread,setSpread]=useState(1.5);
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),[out,setOut]=useState<Record<string,unknown>|null>(null);
 async function refresh(){try{const [s,m]=await Promise.all([api('/api/v05/research/status'),api('/api/v05/capabilities')]);setStatus(s);setModel(m);}catch(e){setError(String(e));}}
 useEffect(()=>{void refresh();},[]);
 async function run(){setBusy(true);setError('');setOut(null);try{setOut(await post('/api/v05/research/run',{symbol:sym,timeframe:tf,strategy:'SMA_CROSS',spreadPips:spread}));}catch(e){setError(String(e));}finally{setBusy(false);}}
 return <section className="qs-panel"><span className="qs-eyebrow">M23 — REPRODUCIBLE RESEARCH</span><h2>{fa?'آرشیو دانش و آزمون استراتژی‌ها':'Strategy knowledge and backtests'}</h2>
 <p className="qs-tip">{fa?'۲۰ استراتژی دارای قواعد اولیه محاسباتی هستند، اما مدل ML آموزش داده نشده است. در این نسخه فقط بک‌تست آزمایشی SMA با تقسیم زمانی ۷۰/۳۰ اجرا و ذخیره می‌شود؛ تاریخچه ده‌ساله و PostgreSQL هنوز نیازمند راه‌اندازی مستقل هستند.':'Twenty experimental rules exist, but no ML model has been trained. This release performs and logs a 70/30 chronological SMA demonstration only. Ten-year history and PostgreSQL require separate verified setup.'}</p>
 <div className="qs-stat-grid"><div><span>ML models trained</span><strong>0</strong></div><div><span>Independently validated</span><strong>{String(model?.independentlyValidatedStrategies??0)}</strong></div><div><span>Strategy definitions</span><strong>20</strong></div><div><span>Research persistence</span><strong>LOCAL JSONL</strong></div></div>
 <h3>{fa?'اجرای بک‌تست پژوهشی':'Run educational backtest'}</h3>
 <div className="qs-form-row v05-research-controls" style={{display:'flex',gap:12,flexWrap:'wrap',alignItems:'end'}}>
  <label className="control">{fa?'نماد':'Symbol'}<select value={sym} onChange={(e:any)=>setSym(e.target.value)}>{SYM.map(x=><option key={x}>{x}</option>)}</select></label>
  <label className="control">{fa?'تایم‌فریم':'Timeframe'}<select value={tf} onChange={(e:any)=>setTf(e.target.value)}>{['M1','M5','M15','H1','H4','D1','W1'].map(x=><option key={x}>{x}</option>)}</select></label>
  <label className="control">Spread / pips<input type="number" min={0} max={100} step={.1} value={spread} onChange={(e:any)=>setSpread(Number(e.target.value))}/></label>
  <button className="qs-primary" disabled={busy} onClick={()=>void run()}>{busy?(fa?'در حال محاسبه…':'Running…'):(fa?'اجرای بک‌تست آزمایشی':'Run demo backtest')}</button>
 </div>
 {error&&<p className="qs-error" role="alert">{error}</p>}
 {out&&<><p className="qs-tip" role="status">{fa?'نتیجه در گزارش محلی ذخیره شد. این آموزش ML نیست.':'Run saved to local research log. This is not ML training.'}</p><details className="raw-data" open><summary>{fa?'گزارش دوره آموزش و آزمون':'Chronological train/test report'}</summary><pre dir="ltr">{JSON.stringify(out,null,2)}</pre></details></>}
 <h3>{fa?'وضعیت زیرساخت پژوهش':'Research readiness'}</h3><pre className="v05-knowledge-status" dir="ltr" style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere',padding:12,background:'var(--input)',borderRadius:8}}>{JSON.stringify(status,null,2)}</pre>
 </section>;
}
