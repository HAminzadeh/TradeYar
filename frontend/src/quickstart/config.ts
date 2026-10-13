import {PROFILES,defaults,type TradingStyle} from '../modules/profiles';

export type Mode='DEMO'|'REAL';
export type Appearance='night'|'day'|'ocean'|'plum';
export type Layout='sidebar'|'top'|'compact';
export type SymbolName='EURUSD'|'GBPUSD'|'USDJPY'|'XAUUSD';
export type WizardConfig={
 style:TradingStyle;symbol:SymbolName;timeframe:string;mode:Mode;
 equity:number;riskPercent:number;stopPips:number;pipValuePerLot:number;
 leverageScenario:20|50|100;
};
export const SYMBOLS:SymbolName[]=['EURUSD','GBPUSD','USDJPY','XAUUSD'];
export const CONFIG_KEY='tradeyar.quickstart.v1';
export const APPEARANCE_KEY='tradeyar.appearance.v1';
export const LAYOUT_KEY='tradeyar.layout.v1';
export const wizardDefaults=():WizardConfig=>({style:'INTRADAY',symbol:'EURUSD',timeframe:'M15',mode:'DEMO',equity:10000,riskPercent:0.25,stopPips:25,pipValuePerLot:10,leverageScenario:20});
export function readWizard():WizardConfig {
 try{
   const saved=JSON.parse(localStorage.getItem(CONFIG_KEY)||'null') as Partial<WizardConfig>|null;
   if(!saved)return wizardDefaults();
   const d=wizardDefaults();
   return {...d,...saved,style:PROFILES.some(x=>x.id===saved.style)?saved.style!:d.style,
     symbol:SYMBOLS.includes(saved.symbol as SymbolName)?saved.symbol!:d.symbol,
     mode:saved.mode==='REAL'?'REAL':'DEMO',
     equity:finiteBetween(saved.equity,1,1e12,d.equity),
     riskPercent:finiteBetween(saved.riskPercent,.01,.25,d.riskPercent),
     stopPips:finiteBetween(saved.stopPips,1,1e6,d.stopPips),
     pipValuePerLot:finiteBetween(saved.pipValuePerLot,.001,1e6,d.pipValuePerLot),
     leverageScenario:([20,50,100].includes(Number(saved.leverageScenario))?saved.leverageScenario:20) as 20|50|100};
 }catch{return wizardDefaults();}
}
function finiteBetween(x:unknown,min:number,max:number,fallback:number){return typeof x==='number'&&Number.isFinite(x)&&x>=min&&x<=max?x:fallback;}
export function saveWizard(v:WizardConfig){try{localStorage.setItem(CONFIG_KEY,JSON.stringify(v));}catch{/* storage disabled */}}
export function selectStyle(v:WizardConfig,style:TradingStyle):WizardConfig{
 const profile=defaults(style);
 return {...v,style,timeframe:profile.timeframe,riskPercent:profile.maxPaperRiskPercent};
}
export function readAppearance():Appearance{
 try{const v=localStorage.getItem(APPEARANCE_KEY);return v==='day'||v==='ocean'||v==='plum'?v:'night';}catch{return 'night';}
}
export function readLayout():Layout{
 try{const v=localStorage.getItem(LAYOUT_KEY);return v==='top'||v==='compact'?v:'sidebar';}catch{return 'sidebar';}
}
export function explainRisk(v:WizardConfig){
 const riskBudget=v.equity*v.riskPercent/100;
 const raw=riskBudget/(v.stopPips*v.pipValuePerLot);
 const lots=Math.max(0,Math.floor(Math.min(raw,10)*100)/100);
 return {riskBudget,lots};
}
