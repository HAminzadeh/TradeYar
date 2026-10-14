# قانون دائمی دارایی‌های آفلاین TradeYar (v0.6.3)

## مسیر واحد و ساختار پوشه‌ها

محل پیشنهادی، بیرون از مخزن عمومی Git:

```text
D:\ChatGPT_Projects\
├── TradeYar\                  # سورس پروژه
└── TradeYar-OfflineDepot\     # فقط کش ابزارها و دارایی‌ها؛ Push نشود
    ├── docker-images\         # export ایمیج‌ها (.tar + .sha256)
    ├── archives\              # ZIP ابزارهای Portable + .sha256
    ├── tools\                 # ابزارهای استخراج‌شده پس از بررسی SHA
    ├── maven-repo\            # مخزن Maven آفلاین
    ├── npm-cache\             # کش npm آفلاین
    ├── python-wheelhouse\     # wheelهای Python از منابع معتبر
    ├── manifests\             # نسخه/هش/مجوز/منشأ فایل‌ها
    ├── backups\
    └── logs\
```

پوشهٔ `TradeYar-OfflineDepot` برای **نسخه‌های قابل‌بازیابی** است؛ دیتای زنده Docker Desktop و volumeها همچنان در فضای داخلی Docker ذخیره می‌شود و باید جداگانه بکاپ گرفته شود. آرشیو کردن ایمیج جای بکاپ گرفتن از دیتابیس را نمی‌گیرد.

## قاعده قطعی راه‌اندازی

1. نسخه نصب‌شده و سلامت سرویس مربوط به همان پروژه را بررسی کن؛ اگر سالم است همان را استفاده کن.
2. اگر Docker image در daemon محلی وجود دارد همان را استفاده کن؛ در غیر این صورت فایل `.tar` از depot را فقط پس از تطبیق SHA-256 با `docker load` وارد کن.
3. اگر ابزار سیستم موجود و نسخه آن سازگار است همان را استفاده کن؛ در غیر این صورت ZIP قابل‌حمل در `archives` را فقط با SHA-256 بررسی و استخراج کن. اجرای خودکار EXE/MSI نصب‌کننده و دورزدن UAC مجاز نیست.
4. Maven فقط با `-o` و مخزن `maven-repo`، npm با `npm_config_offline=true`، pip با `PIP_NO_INDEX=1` و `python-wheelhouse` کار کند. هیچ `docker pull` یا دانلود خودکاری هنگام بالا آمدن پروژه وجود ندارد.
5. اگر بسته‌ای به صورت معتبر روی دیسک موجود نبود، **خطای واضح OFFLINE MISS** بده. هرگز به اینترنت fallback نکن.
6. نسخه‌ها، checksumها، مجوز داده‌ها و منشأ باینری‌ها را مستند کن؛ فقط بسته‌های مورد اعتماد وارد depot شوند.

## اولین راه‌اندازی

فایل `Start-TradeYar-Offline.ps1` را در `D:\ChatGPT_Projects\TradeYar\scripts\` قرار بده. در Windows PowerShell:

```powershell
$Project = 'D:\ChatGPT_Projects\TradeYar'
$Script = Join-Path $Project 'scripts\Start-TradeYar-Offline.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode Init
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode Status
```

### مرحله Seed — فقط از فایل‌ها و کش موجود، بدون دانلود

وقتی ایمیج‌های Docker از قبل به صورت قانونی/مجاز روی همان ماشین موجود باشند:

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode SeedImages
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode SeedCaches
```

`SeedImages` فقط ایمیج‌هایی را که **هم‌اکنون روی سیستم موجودند** ذخیره می‌کند؛ هیچ ایمیجی از اینترنت دریافت نمی‌کند. این کار فضای دیسک قابل‌توجهی می‌خواهد. برای ابزارهایی که هنوز در cache نیستند، نسخه portable امضاشده/مطمئن را **جداگانه و با تأیید اپراتور** به `archives\jdk.zip`, `archives\maven.zip`, `archives\node.zip` و فایل SHA-256 متناسب با نام هر آرشیو منتقل کن. فایل SHA باید فقط ۶۴ رقم هگز باشد. ابزار `python` هم می‌تواند در `archives\python.zip` قرار گیرد، اما Python Embedded همیشه برای pip یا MT5 مناسب نیست. این launcher تنها ابزارهای لازم برای اجرای backend را بررسی می‌کند.

### آماده‌سازی و اجرای واقعی کاملاً آفلاین

ابتدا `infrastructure\v063\.env` را با رمزهای اختصاصی تنظیم کن؛ این فایل خصوصی نباید در Git ذخیره شود.

```powershell
# فقط TimescaleDB را با ایمیج موجود/آرشیو محلی آماده می‌کند:
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode Prepare -Services timescale

# اجرای backend آفلاین؛ ترمینال تا زمانی که برنامه اجراست مشغول می‌ماند:
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Mode Start -Services timescale

# اختیاری: سایر سرویس‌ها، فقط با رم کافی:
# -Services timescale,neo4j,clickhouse,minio
```

**مهم:** `Prepare` و `Start` به وجود Maven/Java معتبر و کش آفلاینِ dependencyها احتیاج دارند. اگر Maven artifactها هنوز در `maven-repo` حاضر نباشند، اجرای `Start` صریحاً خطا می‌دهد؛ به اینترنت نمی‌رود. `-Mode Start -StartFrontend` در صورت حاضر بودن `node_modules`، frontend را هم اجرا می‌کند. ابزارهای Flask/Python مستقل باید جداگانه با `pip --no-index --find-links` از wheelhouse نصب شوند.

## سازگاری با راه‌انداز قبلی v0.6.2

فایل موجود `scripts/Start-TradeYar-Managed.ps1` و Java `StartupDependencyMonitor` ممکن است طبق Policy قبلی مجوز دانلود داشته باشند. **تا زمانی که آن‌ها به حالت offline-only ارتقا نیافته‌اند، برای استارت آفلاین قطعی از launcher جدید استفاده کن** و در IntelliJ/Spring Run Configuration مقدار `TRADEYAR_AUTO_REPAIR_ON_STARTUP=false` را قرار بده. چون راه‌انداز جدید این متغیر را برای فرایند child تنظیم می‌کند، دانلودهای تعمیراتی قدیمی هنگام Start آن غیرفعال‌اند. اجرای مستقیم IntelliJ با Policy قبلی تحت کنترل این wrapper نیست؛ برای آن باید یک pre-launch task به `-Mode Prepare` اضافه کنی و متغیر فوق را false تنظیم کنی.

## امنیت و محدودیت‌های عملی

- هر نام ایمیج Docker دقیقا با فایل Compose v0.6.3 مقایسه می‌شود؛ تغییر tag باید با بازبینی این فهرست همراه باشد.
- «کانتینر Running» بدون healthcheck لزوماً به معنی آماده بودن سرویس کاربردی نیست. برای Neo4j/ClickHouse/MinIO health probe جداگانه نیاز است.
- فایل `.env` و secrets را خارج از repo منتشر نکن. Depot نیز حاوی باینری‌ها و شاید credentialهای بعضی package cacheها است، پس فقط دسترسی محلی مجاز بده.
- در Docker Desktop storage واقعی ایمیج‌ها داخل فضای داده Docker می‌ماند؛ TARهای depot نسخه قابل‌بازیابی آن‌ها هستند، نه جایگزین storage داخلی.
- این بسته صرفاً زیرساخت و مدیریت وابستگی‌ها را کنترل می‌کند؛ هیچ مدل یا سیگنال معاملاتی واقعی را تأیید نمی‌کند و قفل معاملات واقعی TradeYar بدون تغییر می‌ماند.
- این برنامه برای Windows PowerShell 5.1 نوشته شده، اما اجرای واقعی آن روی سیستم تو هنوز تأیید نشده است؛ ابتدا `Init` و `Status` را اجرا کن و خروجی را بفرست.
