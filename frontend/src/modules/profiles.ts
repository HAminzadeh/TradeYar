import type { Locale } from './catalog';

export type TradingStyle = 'SCALP' | 'INTRADAY' | 'SWING' | 'POSITION' | 'WEEKLY' | 'CUSTOM';
export type Profile = {
  id: TradingStyle; fa: string; en: string; timeframe: string;
  confirmations: string[]; maxPaperRiskPercent: number; noteFa: string; noteEn: string;
  validation: 'NOT_VALIDATED';
};
export type WorkstationSettings = {
  version: 1; style: TradingStyle; timeframe: string; consensusPercent: number;
  maxPaperRiskPercent: number; symbol: 'EURUSD' | 'GBPUSD' | 'USDJPY' | 'XAUUSD';
};
export const PROFILES: Profile[] = [
  {id:'SCALP',fa:'اسکالپ',en:'Scalping',timeframe:'M1',confirmations:['M15','H1'],maxPaperRiskPercent:0.1,noteFa:'به داده تیک، اسپرد واقعی و آزمون تاخیر نیاز دارد.',noteEn:'Requires validated tick data, spreads and latency.',validation:'NOT_VALIDATED'},
  {id:'INTRADAY',fa:'روزانه',en:'Intraday',timeframe:'M15',confirmations:['H1','H4'],maxPaperRiskPercent:0.25,noteFa:'ارزیابی پس از بسته‌شدن کندل، با کنترل سشن و اخبار.',noteEn:'Evaluate closed bars with session and news controls.',validation:'NOT_VALIDATED'},
  {id:'SWING',fa:'سوئینگ',en:'Swing',timeframe:'H4',confirmations:['D1'],maxPaperRiskPercent:0.25,noteFa:'هزینه نگهداری شبانه و رویدادهای پایان هفته مهم‌اند.',noteEn:'Overnight and weekend costs must be modeled.',validation:'NOT_VALIDATED'},
  {id:'POSITION',fa:'پوزیشن',en:'Position',timeframe:'D1',confirmations:['W1'],maxPaperRiskPercent:0.25,noteFa:'برای افق طولانی به تاریخچه و تحلیل سواپ نیاز دارد.',noteEn:'Requires long history and swap accounting.',validation:'NOT_VALIDATED'},
  {id:'WEEKLY',fa:'هفتگی',en:'Weekly',timeframe:'W1',confirmations:['MN1'],maxPaperRiskPercent:0.2,noteFa:'فقط کندل W1 بسته‌شده معتبر است؛ تعداد نمونه محدود است.',noteEn:'Use completed weekly bars; sample sizes can be small.',validation:'NOT_VALIDATED'},
  {id:'CUSTOM',fa:'سفارشی',en:'Custom',timeframe:'H1',confirmations:['H4'],maxPaperRiskPercent:0.25,noteFa:'ترکیب دلخواه بدون اعتبارسنجی خودکار تأیید نمی‌شود.',noteEn:'Custom combinations require independent validation.',validation:'NOT_VALIDATED'},
];
export const SETTINGS_KEY = 'tradeyar.settings.v1';
export function defaults(style: TradingStyle = 'INTRADAY'): WorkstationSettings {
  const selected = PROFILES.find(x => x.id === style) ?? PROFILES[1];
  return {version:1,style:selected.id,timeframe:selected.timeframe,consensusPercent:80,maxPaperRiskPercent:selected.maxPaperRiskPercent,symbol:'EURUSD'};
}
export function loadSettings(): WorkstationSettings {
  const base = defaults();
  try {
    const value = JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? 'null');
    if (!value || value.version !== 1 || !PROFILES.some(p=>p.id===value.style)) return base;
    const ref = defaults(value.style);
    return {...ref,
      timeframe:typeof value.timeframe === 'string' && /^(M1|M5|M15|M30|H1|H4|D1|W1|MN1)$/.test(value.timeframe) ? value.timeframe : ref.timeframe,
      consensusPercent:Number.isInteger(value.consensusPercent) && value.consensusPercent>=80 && value.consensusPercent<=100 ? value.consensusPercent : 80,
      maxPaperRiskPercent:typeof value.maxPaperRiskPercent==='number' && Number.isFinite(value.maxPaperRiskPercent) && value.maxPaperRiskPercent>0 && value.maxPaperRiskPercent<=ref.maxPaperRiskPercent ? value.maxPaperRiskPercent : ref.maxPaperRiskPercent,
      symbol:['EURUSD','GBPUSD','USDJPY','XAUUSD'].includes(value.symbol) ? value.symbol : 'EURUSD',
    };
  } catch { return base; }
}
export function storeSettings(value:WorkstationSettings) { try {localStorage.setItem(SETTINGS_KEY,JSON.stringify(value));} catch {/* browsers without storage */} }
export function resetSettings(style:TradingStyle='INTRADAY') {const next=defaults(style);storeSettings(next);return next;}
export function profileLabel(p:Profile,locale:Locale) {return p[locale];}
