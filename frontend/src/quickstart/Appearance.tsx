import type {Locale} from '../modules/catalog';
import type {Appearance as Theme,Layout} from './config';
type Props={locale:Locale;theme:Theme;setTheme:(v:Theme)=>void;layout:Layout;setLayout:(v:Layout)=>void};
const themes:{id:Theme;fa:string;en:string;colors:string[]}[]=[
 {id:'night',fa:'شب حرفه‌ای',en:'Professional Dark',colors:['#0b1321','#15243b','#3c8dde']},
 {id:'day',fa:'روز روشن',en:'Light',colors:['#eff4fa','#ffffff','#2a62b8']},
 {id:'ocean',fa:'اقیانوس',en:'Ocean',colors:['#071b29','#12354b','#25b6bd']},
 {id:'plum',fa:'بنفش',en:'Plum',colors:['#191329','#29213d','#ae86ff']},
];
const layouts:{id:Layout;fa:string;en:string}[]=[{id:'sidebar',fa:'منوی کناری',en:'Sidebar'},{id:'top',fa:'منوی بالا',en:'Top navigation'},{id:'compact',fa:'منوی مینیمال',en:'Compact'}];
export default function AppearanceView({locale,theme,setTheme,layout,setLayout}:Props){const fa=locale==='fa';return <section className="qs-panel"><span className="qs-eyebrow">APPEARANCE & LAYOUT</span><h2>{fa?'شخصی‌سازی ظاهر تریدیار':'Personalize TradeYar'}</h2><p>{fa?'پیش‌نمایش‌های زیر قابل انتخاب هستند و بلافاصله روی رابط اعمال می‌شوند.':'Select a preview to apply the theme or layout immediately.'}</p>
 <h3>{fa?'تم‌های رنگی':'Color themes'}</h3><div className="qs-preview-grid">{themes.map(t=><button key={t.id} type="button" className={'qs-preview-choice'+(theme===t.id?' active':'')} onClick={()=>setTheme(t.id)} aria-pressed={theme===t.id}><div className="qs-theme-sample" style={{background:t.colors[0]}}><div style={{background:t.colors[1]}}/><span style={{background:t.colors[2]}}/><span style={{background:t.colors[2]}}/></div><strong>{t[locale]}</strong></button>)}</div>
 <h3>{fa?'چیدمان منو':'Navigation layout'}</h3><div className="qs-preview-grid">{layouts.map(l=><button type="button" className={'qs-preview-choice'+(layout===l.id?' active':'')} key={l.id} onClick={()=>setLayout(l.id)} aria-pressed={layout===l.id}><div className={'qs-layout-sample '+l.id}><span/><div><b/><b/><b/></div></div><strong>{l[locale]}</strong></button>)}</div>
 <div className="qs-tools"><button className="qs-ghost" onClick={()=>{setTheme('night');setLayout('sidebar');}}>{fa?'بازنشانی به پیش‌فرض':'Restore defaults'}</button></div></section>;}
