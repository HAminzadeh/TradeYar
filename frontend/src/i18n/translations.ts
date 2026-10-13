export type Locale = 'fa' | 'en';
export const translations = {
  fa: {
    app: 'تریدیار', title: 'ایستگاه تحلیل و معامله‌گری تریدیار', backend: 'وضعیت سرور',
    modules: 'ماژول‌ها', workspace: 'فضای کاری', market: 'بازار', chart: 'نمودار EUR/USD',
    connection: 'ارتباط با سرور', language: 'زبان', price: 'قیمت نمایشی',
    marketSource: 'داده ساختگی — مناسب تصمیم معاملاتی نیست',
    demo: 'آزمایشی', locked: 'غیرفعال', live: 'معامله واقعی',
    status: 'وضعیت', ready: 'آماده', disconnected: 'قطع', note: 'فقط محیط توسعه و شبیه‌سازی',
    refresh: 'به‌روزرسانی', loading: 'در حال بارگذاری', unavailable: 'در دسترس نیست',
    categories: 'خدمات و ماژول‌ها', disclaimer: 'هیچ سفارش واقعی از این نسخه ارسال نمی‌شود.'
  },
  en: {
    app: 'TradeYar', title: 'TradeYar Trading Workstation', backend: 'Backend status',
    modules: 'Modules', workspace: 'Workspace', market: 'Market', chart: 'EUR/USD chart',
    connection: 'Backend connection', language: 'Language', price: 'Demo price',
    marketSource: 'Synthetic data — not for trading decisions',
    demo: 'Demo', locked: 'Disabled', live: 'Live trading',
    status: 'Status', ready: 'Ready', disconnected: 'Offline', note: 'Development and simulation only',
    refresh: 'Refresh', loading: 'Loading', unavailable: 'Unavailable',
    categories: 'Services and modules', disclaimer: 'This build cannot submit real orders.'
  }
} as const;