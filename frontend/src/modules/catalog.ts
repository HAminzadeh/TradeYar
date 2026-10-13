export type Locale = 'fa' | 'en';
export type ModuleItem = { id: string; fa: string; en: string; descriptionFa: string; descriptionEn: string; mode: string };
export const modules: ModuleItem[] = [
  {id:'M01',fa:'داشبورد مرکزی',en:'Core Dashboard',descriptionFa:'سلامت سامانه و فهرست ماژول‌ها',descriptionEn:'System health and registry',mode:'DEMO'},
  {id:'M02',fa:'رابط دوزبانه',en:'Bilingual Interface',descriptionFa:'زبان، جهت صفحه و تم',descriptionEn:'Language, direction and theme',mode:'DEMO'},
  {id:'M03',fa:'تنظیمات کاربر',en:'User Preferences',descriptionFa:'تنظیمات موقت سمت سرور؛ احراز هویت هنوز وجود ندارد',descriptionEn:'Shared in-memory preferences; no authentication',mode:'MEMORY'},
  {id:'M04',fa:'داده‌های بازار',en:'Market Data',descriptionFa:'قیمت و کندل‌های ساختگی قابل جستجو',descriptionEn:'Synthetic quotes and bars',mode:'SYNTHETIC'},
  {id:'M05',fa:'نمودار حرفه‌ای',en:'Price Charts',descriptionFa:'نمودار کندلی تعاملی با داده آزمایشی',descriptionEn:'Interactive candles with demo data',mode:'SYNTHETIC'},
  {id:'M06',fa:'اتصال متاتریدر',en:'MetaTrader 5',descriptionFa:'خواندن وضعیت اتصال و فایل قیمت؛ فقط خواندنی',descriptionEn:'Read-only connection and snapshot status',mode:'READ_ONLY'},
  {id:'M07',fa:'تحلیل تکنیکال',en:'Technical Analysis',descriptionFa:'SMA، EMA و RSI روی قیمت‌های آزمایشی',descriptionEn:'SMA, EMA and RSI over demo prices',mode:'DEMO'},
  {id:'M08',fa:'استراتژی‌ها',en:'Strategies',descriptionFa:'فهرست ۲۰ استراتژی؛ ارزیابی ۳ مورد پیاده‌سازی‌شده',descriptionEn:'20 listed, 3 currently evaluated',mode:'PARTIAL'},
  {id:'M09',fa:'بک‌تست',en:'Backtesting',descriptionFa:'اجرای تست نمایشی SMA با اسپرد قابل تنظیم',descriptionEn:'SMA demo with adjustable spread',mode:'SYNTHETIC'},
  {id:'M10',fa:'سیگنال‌ها',en:'Signals',descriptionFa:'نمایش سیگنال آزمایشی بدون اجازه معامله',descriptionEn:'Unverified signals; never authorization',mode:'DEMO'},
  {id:'M11',fa:'مدیریت ریسک',en:'Risk Sizing',descriptionFa:'محاسبه حجم تخمینی با محدودیت ریسک یک درصد',descriptionEn:'Indicative lot sizing, 1% max risk',mode:'DEMO'},
  {id:'M12',fa:'معاملات آزمایشی',en:'Paper Trading',descriptionFa:'ثبت سفارش شبیه‌سازی‌شده بدون اتصال بروکر',descriptionEn:'Simulated orders, no broker connection',mode:'MEMORY'},
  {id:'M13',fa:'ژورنال معاملات',en:'Trading Journal',descriptionFa:'نمایش سابقه سفارش‌های آزمایشی',descriptionEn:'In-memory simulated fills history',mode:'MEMORY'},
  {id:'M14',fa:'اخبار و تقویم',en:'News & Calendar',descriptionFa:'رویدادهای نمونه؛ فید زنده متصل نیست',descriptionEn:'Examples only; no live feed',mode:'SAMPLE'},
  {id:'M15',fa:'هوش مصنوعی',en:'AI Service',descriptionFa:'وضعیت سرویس Python؛ مدل آموزش‌دیده موجود نیست',descriptionEn:'Python availability; no trained model',mode:'UNTRAINED'},
  {id:'M16',fa:'هشدار قیمت',en:'Price Alerts',descriptionFa:'ساخت و آزمایش دستی هشدار روی داده ساختگی',descriptionEn:'Create and check demo threshold alerts',mode:'MEMORY'},
  {id:'M17',fa:'گزارش‌ها',en:'Reports',descriptionFa:'آمار سفارش آزمایشی؛ سود قطعی محاسبه نشده',descriptionEn:'Paper fill stats, no realized P/L',mode:'DEMO'},
  {id:'M18',fa:'مرکز آموزش',en:'Learning Center',descriptionFa:'فهرست درس‌های پایه فارسی و انگلیسی',descriptionEn:'Bilingual learning catalog',mode:'DEMO'},
  {id:'M19',fa:'زیرساخت',en:'Infrastructure',descriptionFa:'پایش سلامت و وضعیت زیرساخت توسعه',descriptionEn:'Health and module diagnostics',mode:'SCAFFOLD'},
  {id:'M20',fa:'معاملات واقعی (قفل)',en:'Live Execution (Locked)',descriptionFa:'فقط مشاهده قفل و آزمون رد سفارش ۴۲۳',descriptionEn:'Verify hard lock / HTTP 423',mode:'LOCKED'},
];
export function nameOf(id:string, locale:Locale):string { const m=modules.find(x=>x.id===id); return m ? m[locale] : id; }
export function formatNumber(n:unknown, max=5):string {
  if(typeof n !== 'number' || !Number.isFinite(n)) return String(n ?? '—');
  return new Intl.NumberFormat('en-US', {maximumFractionDigits:max}).format(n);
}
