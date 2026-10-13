#requires -Version 5.1
<#
.SYNOPSIS
  Build TradeYar architecture first, then the 20-module development scaffold.
.DESCRIPTION
  Runs phases 0..11. Local changes to target files are backed up before replacement.
  No broker orders are enabled. Some modules are demonstrations, not production features.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\Build-TradeYar.ps1 -Stage All -Verify
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Build-TradeYar.ps1 -Root 'D:\ChatGPT_Projects\TradeYar' -Stage 2
#>
param(
  [string]$Root = '',
  [ValidateSet('All','0','1','2','3','4','5','6','7','8','9','10','11')]
  [string]$Stage = 'All',
  [switch]$Verify
)
$ErrorActionPreference = 'Stop'
if (-not $Root) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $possibleRoot = Split-Path -Parent $scriptDir
  if (Test-Path (Join-Path $possibleRoot 'backend/pom.xml')) { $Root = $possibleRoot }
  elseif (Test-Path (Join-Path (Get-Location) 'backend/pom.xml')) { $Root = (Get-Location).Path }
  else { throw 'Set -Root to the cloned TradeYar repository directory.' }
}
$Root = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path (Join-Path $Root 'backend/pom.xml'))) {
  throw "Not a TradeYar repository: $Root"
}
$phases = if ($Stage -eq 'All') { @(0..11) } else { @([int]$Stage) }
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss-fff')
$backupRoot = Join-Path $Root ".tradeyar-backups/$stamp"
$created = 0; $unchanged = 0; $backedUp = 0
$utf8 = [System.Text.UTF8Encoding]::new($false)
function Write-ProjectFile {
  param([int]$Phase,[string]$RelativePath,[string]$Content)
  if ($phases -notcontains $Phase) { return }
  $target = Join-Path $Root ($RelativePath.Replace('/',[System.IO.Path]::DirectorySeparatorChar))
  $folder = Split-Path -Parent $target
  if (-not (Test-Path $folder)) { [void][System.IO.Directory]::CreateDirectory($folder) }
  if (Test-Path $target) {
    $before = [System.IO.File]::ReadAllText($target)
    if ($before -eq $Content) { $script:unchanged++; return }
    $backup = Join-Path $backupRoot ($RelativePath.Replace('/',[System.IO.Path]::DirectorySeparatorChar))
    $backupFolder = Split-Path -Parent $backup
    if (-not (Test-Path $backupFolder)) { [void][System.IO.Directory]::CreateDirectory($backupFolder) }
    [System.IO.File]::Copy($target,$backup,$true)
    $script:backedUp++
  }
  [System.IO.File]::WriteAllText($target,$Content,$utf8)
  $script:created++
  Write-Host ("[phase {0}] {1}" -f $Phase,$RelativePath) -ForegroundColor Cyan
}
Write-Host 'TradeYar | Architecture and 20-module scaffold | LIVE TRADING LOCKED' -ForegroundColor Green
Write-Host "Root: $Root" -ForegroundColor Gray
Write-ProjectFile 0 'docs/ARCHITECTURE.md' @'
# TradeYar Architecture — version 0.2 (development scaffold)

## Final architectural direction

- Java 21 + Spring Boot modular monolith: domain code and HTTP adapters separated by package, one deployable backend.
- React/TypeScript SPA: `fa-IR` default, RTL for Persian and LTR for English, explicit language switch.
- Python/FastAPI: isolated ML/analytics service; not trusted to authorize trades.
- MT5/MQL5: read-only agent for market snapshots. No live trading or credential storage in source.
- PostgreSQL: target relational store for accounts, market bars, strategy definitions, journals, orders and events.
- Redis: optional caching and async/event distribution in later iterations.
- Shared governance: API contracts, timestamps in UTC, data provenance, request validation, tests, logging, metrics.

## Component diagram

```mermaid
flowchart TB
  UI[React bilingual RTL / LTR] --> API[Java Spring Boot modular monolith]
  API --> DB[(PostgreSQL target)]
  API --> REDIS[(Redis target)]
  API --> AI[Python AI service: no model loaded]
  API --> MT[MT5 read-only CSV adapter]
  API --> MARKET[Deterministic synthetic market provider]
  API --> PAPER[Paper trading memory store]
  API --> LOCK[Live execution LOCKED]
```

## Security and execution boundary

All order-sending mechanisms are LOCKED. `/api/live/orders` returns HTTP 423 regardless of settings. Paper trading is simulated with synthetic quotes, never forwarded to a broker. No module may bypass an independent risk gate in a future live execution implementation. Human authorization, user authentication, broker-side constraints, idempotency keys, kill-switch, reconciliation and compliance review are prerequisites to enabling execution.

## Layering and dependency direction

Frontend -> REST backend -> application/domain services -> ports -> external adapters.
Backend -> Python AI / MT5 local file / future market data provider.
M10 signals may depend on M08 strategies, but execution must NEVER depend directly on unvalidated AI predictions.
M12 paper trading is isolated from M20 live execution.

## Persistence and maturity

The produced implementation is a runnable **development scaffold**. Market data is deterministic and SYNTHETIC, account preferences / alerts / simulated orders are currently stored in process memory; the PostgreSQL and Redis Docker services are provisioned but not integrated into the application layer. Restarting the backend clears temporary state. Live broker feed, real historical backtests, production auth, persistent journal, trained AI, alerts delivery, and real order submission are NOT implemented.

## Module identifiers

M01 core | M02 UI/i18n | M03 users/preferences | M04 market data | M05 charts | M06 MT5 read-only bridge | M07 technical analysis | M08 strategy engine | M09 backtest | M10 signals | M11 risk | M12 paper trading | M13 journal | M14 news/calendar | M15 AI bridge | M16 alerts | M17 reports | M18 education | M19 infrastructure | M20 live execution (LOCKED).

## Phase acceptance

0 architecture docs; 1 backend baseline and infrastructure; 2 bilingual UI; 3 user preferences; 4 market+chart; 5 MT5 snapshot; 6 indicators+strategies; 7 backtest; 8 signals+risk; 9 paper+journal; 10 news+AI+alerts+reporting+education; 11 explicit live lock.

## Next production implementation slices

1. Persistent schemas and repository ports, Flyway migrations and transaction isolation.
2. Authentication/authorization (non-demo), secret management, audit log, retention policies.
3. Broker adapter with signed command channel, quote freshness, trading hours, lot/pip conversion and risk limits.
4. Historical verified data, realistic cost/slippage simulation, walk-forward tests and backtest reproducibility.
5. Observability: structured logs, tracing, metrics, alerting and disaster recovery.
'@

Write-ProjectFile 0 'README.md' @'
# TradeYar | تریدیار

Java-first bilingual forex research workstation. **Development scaffold only.** Persian (RTL) is the default UI language; English (LTR) can be selected.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [All stages and modules](docs/PHASES.md)
- [Development API](docs/API.md)

## Generate the full scaffold

From PowerShell in the repository:

```powershell
.\scripts\Build-TradeYar.ps1 -Stage All -Verify
.\scripts\Setup-TradeYar.ps1 -InstallDependencies
.\scripts\Start-TradeYar.ps1
```

Dashboard http://localhost:5173 — Backend http://localhost:8080/api/health

**Important:** only synthetic demo quotes are generated; paper orders and user preferences are stored in memory, the Python AI model is untrained, the MT5 bridge is read-only, and live order submission is hard-locked. PostgreSQL and Redis are provisioned but not yet connected to backend repositories. No real-money trading capability is provided.
'@

Write-ProjectFile 0 'docs/API.md' @'
# Development API (all under http://localhost:8080)

- `GET /api/health` — existing status from initial scaffold.
- `GET /api/modules` — module registry.
- `GET /api/preferences`, `PUT /api/preferences` — in-memory locale preferences.
- `GET /api/market/candles?symbol=EURUSD&limit=100` — synthetic candles.
- `GET /api/market/quote?symbol=EURUSD` — synthetic snapshot.
- `GET /api/charts/series?symbol=EURUSD` — chart data wrapper.
- `GET /api/mt5/status` — disconnected or last CSV snapshot from configured file.
- `GET /api/technical/summary?symbol=EURUSD` — SMA/EMA/RSI.
- `GET /api/strategies` / `GET /api/strategies/evaluate?strategy=SMA_CROSS` — strategies.
- `GET /api/backtest/run?symbol=EURUSD&strategy=SMA_CROSS` — demonstrator using synthetic data.
- `GET /api/signals/preview?symbol=EURUSD` — untrusted trading signal preview.
- `POST /api/risk/position-size` — capped estimated size, not trade authorization.
- `GET /api/paper/orders`, `POST /api/paper/orders` — simulated paper orders only.
- `GET /api/journal` — simulated order record view.
- `GET /api/news/events` — non-live sample calendar events.
- `GET /api/ai/status` — optional Python service health check.
- `GET /api/alerts`, `POST /api/alerts`, `GET /api/alerts/check` — in-memory alerts.
- `GET /api/reports/overview` — mock trade counts; no fabricated P/L.
- `GET /api/education/lessons?lang=fa` — basic learning content.
- `GET /api/live/status`, `POST /api/live/orders` — hard-locked execution (423).

No API here is authorized for internet-facing production use until authentication, rate limiting, validation, persistence and monitoring have been implemented.
'@

Write-ProjectFile 0 '.gitignore' @'
# Compiled and generated
**/target/
**/node_modules/
**/dist/
**/build/
**/__pycache__/
**/*.py[cod]
**/.pytest_cache/
**/.venv/
*.log
# Secrets and local editor state
.env
.env.*
!.env.example
**/.idea/
**/.vscode/
.tradeyar-backups/
# OS
.DS_Store
Thumbs.db
'@

Write-ProjectFile 0 '.env.example' @'
# Never commit a populated .env file.
POSTGRES_DB=tradeyar
POSTGRES_USER=tradeyar
POSTGRES_PASSWORD=replace-with-long-random-password
TRADEYAR_AI_URL=http://127.0.0.1:8001
# Optional absolute path to CSV written by the MT5 read-only agent.
TRADEYAR_MT5_TICKS_FILE=
'@

Write-ProjectFile 0 'docs/PHASES.md' @'
# Staged implementation

Run `powershell -ExecutionPolicy Bypass -File .\scripts\Build-TradeYar.ps1 -Stage All` from a cloned repo, or provide `-Root`.
For a single phase use `-Stage 0` .. `-Stage 11`; phases 0..N must be completed before testing phase N on its own.

0 Architecture and contracts
1 M01 core, M19 infrastructure
2 M02 interface and internationalization
3 M03 preferences
4 M04 market, M05 chart
5 M06 MT5 read-only adapter
6 M07 indicators, M08 strategies
7 M09 backtesting demo
8 M10 signals, M11 risk sizing
9 M12 paper trading, M13 journal
10 M14 news, M15 AI, M16 alerts, M17 reports, M18 learning
11 M20 LOCKED execution

Only synthetic market data is available at first. This scaffold should not be used to make investment decisions.
'@

Write-ProjectFile 1 'backend/app/pom.xml' @'
<project xmlns="http://maven.apache.org/POM/4.0.0"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion>
 <parent>
   <groupId>com.tradeyar</groupId><artifactId>tradeyar-parent</artifactId><version>0.1.0-SNAPSHOT</version>
 </parent>
 <artifactId>app</artifactId>
 <dependencies>
   <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
   <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
   <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
   <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
 </dependencies>
 <build><plugins>
   <plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId><version>${spring-boot.version}</version>
     <executions><execution><goals><goal>repackage</goal></goals></execution></executions>
   </plugin>
   <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-compiler-plugin</artifactId><version>3.14.0</version>
     <configuration>
       <parameters>true</parameters><release>${maven.compiler.release}</release><encoding>UTF-8</encoding></configuration></plugin>
   <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><version>3.5.2</version></plugin>
 </plugins></build>
</project>
'@

Write-ProjectFile 1 'backend/app/src/main/resources/application.yml' @'
spring:
  application:
    name: TradeYar
server:
  address: ${TRADEYAR_BIND_ADDRESS:127.0.0.1}
  port: ${PORT:8080}
management:
  endpoints:
    web:
      exposure:
        include: health,info
tradeyar:
  trading:
    live-enabled: false
  market:
    default-symbol: EURUSD
'@

Write-ProjectFile 1 'backend/app/src/main/java/com/tradeyar/app/core/ModulesController.java' @'
package com.tradeyar.app.core;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/modules")
public class ModulesController {
  private static final String[][] MODULES = {
    {"M01","Core","DEMO"},{"M02","Bilingual UI","DEMO"},
    {"M03","Preferences","DEMO"},{"M04","Market data","SYNTHETIC"},
    {"M05","Charts","DEMO"},{"M06","MT5 connector","READ_ONLY"},
    {"M07","Technical analysis","DEMO"},{"M08","Strategies","PARTIAL"},
    {"M09","Backtesting","SYNTHETIC"},{"M10","Signals","DEMO"},
    {"M11","Risk sizing","DEMO"},{"M12","Paper trading","IN_MEMORY"},
    {"M13","Trading journal","IN_MEMORY"},{"M14","News","SAMPLE"},
    {"M15","AI","UNTRAINED"},{"M16","Alerts","IN_MEMORY"},
    {"M17","Reports","DEMO"},{"M18","Education","DEMO"},
    {"M19","Infrastructure","SCAFFOLD"},{"M20","Live execution","LOCKED"}
  };
  @GetMapping
  public List<Map<String,String>> modules() {
    return java.util.Arrays.stream(MODULES)
      .map(row -> Map.of("id",row[0],"name",row[1],"status",row[2])).toList();
  }
}
'@

Write-ProjectFile 1 'backend/app/src/main/java/com/tradeyar/app/core/ApiErrors.java' @'
package com.tradeyar.app.core;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.converter.HttpMessageNotReadableException;

@RestControllerAdvice
public class ApiErrors {
  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String,String>> invalid(IllegalArgumentException error) {
    return ResponseEntity.badRequest().body(Map.of("error",error.getMessage()));
  }
  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<Map<String,String>> invalidBody(HttpMessageNotReadableException error) {
    return ResponseEntity.badRequest().body(Map.of("error","Invalid JSON request"));
  }
  @ExceptionHandler(ResponseStatusException.class)
  public ResponseEntity<Map<String,String>> responseStatus(ResponseStatusException error) {
    return ResponseEntity.status(error.getStatusCode()).body(Map.of("error",
      error.getReason() == null ? "Request rejected" : error.getReason()));
  }
}
'@

Write-ProjectFile 1 'backend/app/src/test/java/com/tradeyar/app/TradeYarSmokeTest.java' @'
package com.tradeyar.app;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class TradeYarSmokeTest {
  @Test void contextStarts() { }
}
'@

Write-ProjectFile 1 'infrastructure/docker/compose.yaml' @'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-tradeyar}
      POSTGRES_USER: ${POSTGRES_USER:-tradeyar}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in a local .env file}
    ports:
      - "127.0.0.1:5433:5432"
    volumes:
      - tradeyar-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      retries: 5
  redis:
    image: redis:7-alpine
    ports:
      - "127.0.0.1:6380:6379"
volumes:
  tradeyar-data:
'@

Write-ProjectFile 1 '.github/workflows/ci.yml' @'
name: TradeYar CI
on:
  push:
  pull_request:
jobs:
  java:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven
          cache-dependency-path: backend/pom.xml
      - name: Test backend
        run: mvn -f backend/pom.xml test
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - name: Install and build UI
        working-directory: frontend
        run: npm install && npm run build
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Validate Python service
        run: python -m compileall -q python/ai-service/app
'@

Write-ProjectFile 1 'backend/app/src/test/java/com/tradeyar/app/core/ModulesControllerTest.java' @'
package com.tradeyar.app.core;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class ModulesControllerTest {
  @Test void hasTwentyModules() { assertEquals(20,new ModulesController().modules().size()); }
  @Test void liveIsLocked() {
    assertEquals("LOCKED",new ModulesController().modules().get(19).get("status"));
  }
}
'@

Write-ProjectFile 2 'frontend/src/i18n/translations.ts' @'
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
'@

Write-ProjectFile 2 'frontend/src/i18n/moduleNames.ts' @'
export const moduleNamesFa: Record<string,string> = {
  M01: 'هسته مرکزی', M02: 'رابط کاربری دوزبانه', M03: 'کاربران و تنظیمات',
  M04: 'داده‌های بازار', M05: 'نمودارها', M06: 'اتصال متاتریدر',
  M07: 'تحلیل تکنیکال', M08: 'استراتژی‌ها', M09: 'بک‌تست',
  M10: 'سیگنال‌ها', M11: 'مدیریت ریسک', M12: 'معاملات آزمایشی',
  M13: 'ژورنال معاملات', M14: 'اخبار و تقویم', M15: 'هوش مصنوعی',
  M16: 'هشدارها', M17: 'گزارش‌ها', M18: 'آموزش',
  M19: 'زیرساخت', M20: 'اجرای معاملات واقعی (قفل‌شده)'
};
'@

Write-ProjectFile 2 'frontend/src/App.tsx' @'
import { useEffect, useMemo, useState } from 'react';
import { CandlestickSeries, createChart, type IChartApi, type UTCTimestamp } from 'lightweight-charts';
import { translations, type Locale } from './i18n/translations';
import { moduleNamesFa } from './i18n/moduleNames';

type ModuleRow = { id: string; name: string; status: string };
type Candle = { time: number; open: number; high: number; low: number; close: number; volume: number };
type Quote = { symbol: string; bid: number; ask: number; source: string };
function getDefaultLocale(): Locale {
  try { return localStorage.getItem('tradeyar.locale') === 'en' ? 'en' : 'fa'; }
  catch { return 'fa'; }
}

function CandleChart({ candles }: { candles: Candle[] }) {
  const [element, setElement] = useState<HTMLDivElement | null>(null);
  useEffect(() => {
    if (!element || !candles.length) return;
    const chart: IChartApi = createChart(element, {
      width: element.clientWidth, height: 310,
      layout: { background: { color: '#141f32' }, textColor: '#b8c6df' },
      grid: { vertLines: { color: '#223149' }, horzLines: { color: '#223149' } },
      timeScale: { timeVisible: true, secondsVisible: false }
    });
    const series = chart.addSeries(CandlestickSeries, {
      upColor: '#31c48d', downColor: '#f87171', borderVisible: false,
      wickUpColor: '#31c48d', wickDownColor: '#f87171'
    });
    series.setData(candles.map(c => ({ ...c, time: c.time as UTCTimestamp })));
    chart.timeScale().fitContent();
    const observer = new ResizeObserver(() => chart.applyOptions({ width: element.clientWidth }));
    observer.observe(element);
    return () => { observer.disconnect(); chart.remove(); };
  }, [element, candles]);
  return <div ref={setElement} className="chart" />;
}

export default function App() {
  const [locale, setLocale] = useState<Locale>(getDefaultLocale);
  const [health, setHealth] = useState('...');
  const [modules, setModules] = useState<ModuleRow[]>([]);
  const [candles, setCandles] = useState<Candle[]>([]);
  const [quote, setQuote] = useState<Quote | null>(null);
  const t = translations[locale];
  const direction = locale === 'fa' ? 'rtl' : 'ltr';
  useEffect(() => {
    document.documentElement.lang = locale === 'fa' ? 'fa-IR' : 'en-US';
    document.documentElement.dir = direction;
    try { localStorage.setItem('tradeyar.locale', locale); } catch { /* disabled storage */ }
  }, [locale, direction]);
  useEffect(() => {
    const read = async () => {
      const fetchJson = async (url: string) => {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      };
      setHealth('...');
      setHealth(await fetchJson('/api/health').then(x => x.status as string).catch(() => 'OFFLINE'));
      setModules(await fetchJson('/api/modules').catch(() => []));
      setCandles(await fetchJson('/api/market/candles?symbol=EURUSD&limit=100').then(x => x.candles as Candle[]).catch(() => []));
      setQuote(await fetchJson('/api/market/quote?symbol=EURUSD').catch(() => null));
    };
    void read();
  }, []);
  const grouped = useMemo(() => modules.slice().sort((a,b) => a.id.localeCompare(b.id)), [modules]);
  return <div className="shell" dir={direction}>
    <aside className="sidebar">
      <div className="brand">◈ {t.app}<small>TradeYar v0.2</small></div>
      <div className="aside-label">{t.categories}</div>
      <div className="module-nav">{grouped.map(m => <div className="module-link" key={m.id}>
        <span className="module-id">{m.id}</span><span>{locale === 'fa' ? moduleNamesFa[m.id] ?? m.name : m.name}</span>
      </div>)}</div>
    </aside>
    <main className="main">
      <header className="topbar">
        <div><h1>{t.title}</h1><p>{t.note}</p></div>
        <div className="language-control"><span>{t.language}</span>
          <button type="button" aria-label="Switch language" onClick={() => setLocale(locale === 'fa' ? 'en' : 'fa')}>
            {locale === 'fa' ? 'English' : 'فارسی'}
          </button>
        </div>
      </header>
      <div className="info-grid">
        <article className="info-card"><span>{t.connection}</span><strong>{health === 'READY' ? t.ready : t.disconnected}</strong><small>{health}</small></article>
        <article className="info-card"><span>{t.modules}</span><strong>{modules.length} / 20</strong><small>{t.demo}</small></article>
        <article className="info-card"><span>{t.price}</span><strong dir="ltr">{quote ? quote.bid.toFixed(5) : '—'}</strong><small>{quote?.source ?? t.unavailable}</small></article>
        <article className="info-card"><span>{t.live}</span><strong>{t.locked}</strong><small>LOCKED</small></article>
      </div>
      <section className="surface">
        <div className="surface-head"><h2>{t.chart}</h2><span className="warning">{t.marketSource}</span></div>
        {candles.length ? <CandleChart candles={candles}/> : <p>{t.unavailable}</p>}
      </section>
      <p className="footer-warning">{t.disclaimer}</p>
    </main>
  </div>;
}
'@

Write-ProjectFile 2 'frontend/src/style.css' @'
:root{font-family:Tahoma,"Segoe UI",Arial,sans-serif;color:#edf4ff;background:#0b1220;font-synthesis:none}
*{box-sizing:border-box}body{margin:0}.shell{min-height:100vh;display:flex}.sidebar{flex:0 0 260px;background:#101b2d;border-inline-end:1px solid #28384e;padding:22px;max-height:100vh;overflow:auto}
.brand{font-size:25px;font-weight:800;color:#8ab5ff;margin:0 0 30px}.brand small{display:block;font-size:11px;margin-top:7px;color:#8c9bb3;letter-spacing:1px}
.aside-label{font-size:12px;color:#9aa9bf;margin-bottom:12px}.module-nav{display:grid;gap:5px}.module-link{display:flex;gap:10px;align-items:center;padding:8px;border-radius:7px;color:#bfcee4;font-size:12px}.module-link:hover{background:#1b2f4b}.module-id{font:11px Consolas,monospace;color:#90bcff;direction:ltr}
.main{min-width:0;width:100%;padding:30px;max-width:1680px;margin:0 auto}.topbar{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:28px}.topbar h1{font-size:24px;margin:0 0 8px}.topbar p{color:#aab9ce;font-size:13px;margin:0}
.language-control{display:flex;align-items:center;gap:12px;font-size:13px;white-space:nowrap}.language-control button{color:#fff;background:#1c4983;border:1px solid #547cb4;padding:9px 14px;cursor:pointer;border-radius:9px}
.info-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:20px}.info-card,.surface{background:#142136;border:1px solid #2a3b54;border-radius:14px}.info-card{padding:20px;display:grid;gap:10px}.info-card span,.info-card small{color:#aab9ce;font-size:12px}.info-card strong{font-size:23px}.surface{padding:18px}.surface-head{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:12px;flex-wrap:wrap}.surface h2{font-size:17px;margin:0}.warning{font-size:12px;color:#f6c37d}.chart{width:100%;min-height:310px;direction:ltr}.footer-warning{text-align:center;color:#edbb76;font-size:12px;margin-top:20px}
@media(max-width:1050px){.info-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.sidebar{flex-basis:190px}.main{padding:22px}}
@media(max-width:680px){.shell{display:block}.sidebar{max-height:none;padding:12px}.brand{margin:0}.aside-label,.module-nav{display:none}.main{padding:14px}.topbar{align-items:flex-start}.topbar h1{font-size:19px}.language-control{flex-direction:column;gap:7px}.info-grid{gap:8px}.info-card{padding:12px}.info-card strong{font-size:18px}}
'@

Write-ProjectFile 2 'frontend/index.html' @'
<!doctype html>
<html lang="fa-IR" dir="rtl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>TradeYar | تریدیار</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
'@

Write-ProjectFile 3 'backend/app/src/main/java/com/tradeyar/app/users/PreferencesController.java' @'
package com.tradeyar.app.users;

import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.web.bind.annotation.*;

/** Demo-only preferences; deliberately no identity/authentication claims. */
@RestController
@RequestMapping("/api/preferences")
public class PreferencesController {
  public record Preferences(String locale, String theme) { }
  private final AtomicReference<Preferences> preferences = new AtomicReference<>(new Preferences("fa-IR","dark"));
  @GetMapping public Map<String,Object> get() {
    return Map.of("preferences",preferences.get(),"persistence","MEMORY_ONLY","authentication","NOT_IMPLEMENTED");
  }
  @PutMapping public Preferences update(@RequestBody Preferences requested) {
    if (requested == null || !("fa-IR".equals(requested.locale()) || "en-US".equals(requested.locale())))
      throw new IllegalArgumentException("locale must be fa-IR or en-US");
    if (!("dark".equals(requested.theme()) || "light".equals(requested.theme())))
      throw new IllegalArgumentException("theme must be dark or light");
    preferences.set(requested);
    return requested;
  }
}
'@

Write-ProjectFile 4 'backend/app/src/main/java/com/tradeyar/app/market/MarketService.java' @'
package com.tradeyar.app.market;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class MarketService {
  public record Candle(long time, double open, double high, double low, double close, long volume) { }
  private static final Set<String> SYMBOLS = Set.of("EURUSD","GBPUSD","USDJPY","XAUUSD");
  public String symbol(String input) {
    String symbol = input == null ? "EURUSD" : input.toUpperCase(java.util.Locale.ROOT).trim();
    if (!SYMBOLS.contains(symbol)) throw new IllegalArgumentException("Unsupported symbol");
    return symbol;
  }
  public List<Candle> candles(String symbol, int limit) {
    symbol = symbol(symbol);
    if (limit < 10 || limit > 500) throw new IllegalArgumentException("limit must be 10..500");
    int seed = switch (symbol) { case "GBPUSD" -> 2; case "USDJPY" -> 3; case "XAUUSD" -> 4; default -> 1; };
    double price = switch (symbol) { case "GBPUSD" -> 1.31; case "USDJPY" -> 150.0; case "XAUUSD" -> 3000.0; default -> 1.10; };
    double scale = symbol.equals("XAUUSD") ? 6.0 : symbol.equals("USDJPY") ? .30 : .003;
    long base = Instant.parse("2026-01-01T00:00:00Z").getEpochSecond();
    List<Candle> rows = new ArrayList<>();
    for (int i = 0; i < limit; i++) {
      double open = price;
      price += scale * (.32 * Math.sin((i + seed) * .37) + .18 * Math.cos((i + seed) * .13));
      double high = Math.max(open,price) + scale * .14;
      double low = Math.min(open,price) - scale * .14;
      rows.add(new Candle(base + i * 3600L, round(open),round(high),round(low),round(price),100+i*7L));
    }
    return rows;
  }
  private double round(double n) { return Math.round(n * 100000.0) / 100000.0; }
  public Map<String,Object> quote(String symbol) {
    symbol = symbol(symbol);
    double price = candles(symbol,100).get(99).close();
    double spread = symbol.equals("XAUUSD") ? .25 : symbol.equals("USDJPY") ? .02 : .0002;
    return Map.of("symbol",symbol,"bid",price,"ask",round(price+spread),
      "source","SYNTHETIC_DEMO","tradable",false,"timestamp",Instant.now().toString());
  }
}

@RestController
@RequestMapping("/api/market")
class MarketController {
  private final MarketService service;
  MarketController(MarketService service) { this.service=service; }
  @GetMapping("/candles") public Map<String,Object> candles(
      @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
      @RequestParam(name="limit", defaultValue="100") int limit) {
    return Map.of("symbol",service.symbol(symbol),"source","SYNTHETIC_DEMO",
      "timeframe","H1","candles",service.candles(symbol,limit));
  }
  @GetMapping("/quote") public Map<String,Object> quote(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return service.quote(symbol);
  }
}
'@

Write-ProjectFile 4 'backend/app/src/main/java/com/tradeyar/app/charts/ChartController.java' @'
package com.tradeyar.app.charts;

import com.tradeyar.app.market.MarketService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/charts")
public class ChartController {
  private final MarketService market;
  public ChartController(MarketService market) { this.market = market; }
  @GetMapping("/series")
  public Map<String,Object> series(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return Map.of("symbol",market.symbol(symbol),"resolution","H1","source","SYNTHETIC_DEMO",
      "candles",market.candles(symbol,100),"supportedIndicators",new String[]{"SMA","EMA","RSI"});
  }
}
'@

Write-ProjectFile 5 'backend/app/src/main/java/com/tradeyar/app/mt5/Mt5Controller.java' @'
package com.tradeyar.app.mt5;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Read-only local CSV status. No terminal commands or order execution. */
@RestController
@RequestMapping("/api/mt5")
public class Mt5Controller {
  @GetMapping("/status") public Map<String,Object> status() {
    String sourcePath = System.getenv("TRADEYAR_MT5_TICKS_FILE");
    if (sourcePath == null || sourcePath.isBlank()) return disconnected("CSV path not configured");
    try {
      Path file = Path.of(sourcePath);
      if (!Files.isRegularFile(file) || Files.size(file)>32768L) return disconnected("Snapshot unavailable or too large");
      List<String> lines = Files.readAllLines(file);
      if (lines.isEmpty()) return disconnected("Empty snapshot");
      String[] fields = lines.get(lines.size()-1).split(";",-1);
      if (fields.length < 4) return disconnected("Malformed snapshot");
      double bid=Double.parseDouble(fields[2]);
      double ask=Double.parseDouble(fields[3]);
      if (!Double.isFinite(bid) || !Double.isFinite(ask) || bid<=0 || ask<bid)
        return disconnected("Invalid prices");
      return Map.of("status","SNAPSHOT_AVAILABLE","mode","READ_ONLY","liveTradingEnabled",false,
        "timestamp",fields[0],"symbol",fields[1],"bid",bid,"ask",ask,
        "note","Snapshot is not a validated live market feed");
    } catch (Exception e) { return disconnected("Unable to read CSV snapshot"); }
  }
  private Map<String,Object> disconnected(String note) {
    return Map.of("status","DISCONNECTED","mode","READ_ONLY","liveTradingEnabled",false,"note",note);
  }
}
'@

Write-ProjectFile 5 'metatrader/Experts/TradeYarAgent.mq5' @'
// TradeYar MT5 Agent — deliberately READ ONLY
#property strict
#property version "0.20"
input bool ExportQuotesToCommonFiles = false;
input int ExportIntervalSeconds = 5;
datetime lastExport = 0;
int OnInit() {
   Print("TradeYar MT5 read-only bridge. Order execution is disabled.");
   return(INIT_SUCCEEDED);
}
void OnTick() {
   if(!ExportQuotesToCommonFiles) return;
   if(ExportIntervalSeconds < 1 || TimeCurrent() - lastExport < ExportIntervalSeconds) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   int f = FileOpen("TradeYarTicks.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(f == INVALID_HANDLE) { Print("Snapshot write failed: ",GetLastError()); return; }
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,
             DoubleToString(tick.bid,_Digits),DoubleToString(tick.ask,_Digits));
   FileClose(f);
   lastExport = TimeCurrent();
}
void OnDeinit(const int reason) { Print("TradeYar read-only agent stopped"); }
'@

Write-ProjectFile 6 'backend/app/src/main/java/com/tradeyar/app/technical/TechnicalService.java' @'
package com.tradeyar.app.technical;

import com.tradeyar.app.market.MarketService;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class TechnicalService {
  public double sma(List<Double> values, int period, int endIndex) {
    if (period < 2 || endIndex < period-1 || endIndex >= values.size())
      throw new IllegalArgumentException("Insufficient SMA samples");
    double sum=0;
    for (int i=endIndex-period+1;i<=endIndex;i++) sum += values.get(i);
    return sum/period;
  }
  public double ema(List<Double> values, int period) {
    if (period < 2 || values.size() < period) throw new IllegalArgumentException("Insufficient EMA samples");
    double value=0;
    for (int i=0;i<period;i++) value+=values.get(i);
    value/=period;
    double alpha=2.0/(period+1);
    for (int i=period;i<values.size();i++) value=values.get(i)*alpha+value*(1-alpha);
    return value;
  }
  public double rsi(List<Double> values, int period) {
    if (period<2 || values.size()<=period) throw new IllegalArgumentException("Insufficient RSI samples");
    double gains=0, losses=0;
    for(int i=1;i<=period;i++) {
      double delta=values.get(i)-values.get(i-1);
      gains+=Math.max(delta,0); losses+=Math.max(-delta,0);
    }
    gains/=period; losses/=period;
    for(int i=period+1;i<values.size();i++) {
      double delta=values.get(i)-values.get(i-1);
      gains=(gains*(period-1)+Math.max(delta,0))/period;
      losses=(losses*(period-1)+Math.max(-delta,0))/period;
    }
    if (losses==0) return gains==0 ? 50.0 : 100.0;
    return 100.0-100.0/(1.0+gains/losses);
  }
  public List<Double> closes(List<MarketService.Candle> candles) {
    return candles.stream().map(MarketService.Candle::close).toList();
  }
}

@RestController
@RequestMapping("/api/technical")
class TechnicalController {
  private final TechnicalService technical;
  private final MarketService market;
  TechnicalController(TechnicalService technical, MarketService market) {
    this.technical=technical;this.market=market;
  }
  @GetMapping("/summary") public Map<String,Object> summary(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    List<Double> values=technical.closes(market.candles(symbol,100));
    return Map.of("symbol",market.symbol(symbol),"source","SYNTHETIC_DEMO",
      "sma20",technical.sma(values,20,values.size()-1),"ema20",technical.ema(values,20),
      "rsi14",technical.rsi(values,14));
  }
}
'@

Write-ProjectFile 6 'backend/app/src/main/java/com/tradeyar/app/strategies/StrategyService.java' @'
package com.tradeyar.app.strategies;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.technical.TechnicalService;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class StrategyService {
  public static final List<String> CATALOG=List.of(
    "SMA_CROSS","EMA_CROSS","TRIPLE_EMA","SUPERTREND",
    "MACD","RSI_REVERSAL","STOCHASTIC","CCI",
    "DONCHIAN_BREAKOUT","ATR_BREAKOUT","BOLLINGER_SQUEEZE","LONDON_BREAKOUT",
    "BOLLINGER_MEAN_REVERSION","RSI_DIVERGENCE","KELTNER_MEAN_REVERSION",
    "PIN_BAR","ENGULFING","PIVOT_POINT","ICHIMOKU","MULTI_TF_EMA_ADX");
  private static final Set<String> ENABLED=Set.of("SMA_CROSS","EMA_CROSS","RSI_REVERSAL");
  private final MarketService market;
  private final TechnicalService technical;
  public StrategyService(MarketService market, TechnicalService technical) {
    this.market=market;this.technical=technical;
  }
  public Map<String,Object> evaluate(String symbol,String strategy) {
    if (!CATALOG.contains(strategy)) throw new IllegalArgumentException("Unknown strategy");
    symbol=market.symbol(symbol);
    if (!ENABLED.contains(strategy)) return Map.of("strategy",strategy,"symbol",symbol,
      "implemented",false,"signal","NO_SIGNAL","source","SYNTHETIC_DEMO");
    List<Double> close=technical.closes(market.candles(symbol,100));
    String signal="NO_SIGNAL";
    if ("RSI_REVERSAL".equals(strategy)) {
      double rsi=technical.rsi(close,14);
      signal=rsi<30 ? "BUY" : rsi>70 ? "SELL" : "NO_SIGNAL";
    } else if ("EMA_CROSS".equals(strategy)) {
      double fast=technical.ema(close,10), slow=technical.ema(close,25);
      signal=fast>slow ? "BUY" : fast<slow ? "SELL" : "NO_SIGNAL";
    } else {
      double fast=technical.sma(close,10,close.size()-1), slow=technical.sma(close,25,close.size()-1);
      signal=fast>slow ? "BUY" : fast<slow ? "SELL" : "NO_SIGNAL";
    }
    return Map.of("strategy",strategy,"symbol",symbol,"implemented",true,
      "signal",signal,"source","SYNTHETIC_DEMO","executable",false);
  }
  public List<Map<String,Object>> catalog() {
    return CATALOG.stream().map(s -> Map.<String,Object>of("id",s,
      "implemented",ENABLED.contains(s),"executionEnabled",false)).toList();
  }
}

@RestController
@RequestMapping("/api/strategies")
class StrategiesController {
  private final StrategyService service;
  StrategiesController(StrategyService service) { this.service=service; }
  @GetMapping public List<Map<String,Object>> list() { return service.catalog(); }
  @GetMapping("/evaluate") public Map<String,Object> evaluate(
    @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
    @RequestParam(name="strategy", defaultValue="SMA_CROSS") String strategy) {
    return service.evaluate(symbol,strategy);
  }
}
'@

Write-ProjectFile 7 'backend/app/src/main/java/com/tradeyar/app/backtest/BacktestController.java' @'
package com.tradeyar.app.backtest;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.technical.TechnicalService;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Educational SMA demonstration with synthetic bars and next-bar-open fills. */
@RestController
@RequestMapping("/api/backtest")
public class BacktestController {
  private final MarketService market;
  private final TechnicalService technical;
  public BacktestController(MarketService market, TechnicalService technical) {
    this.market=market;this.technical=technical;
  }
  @GetMapping("/run") public Map<String,Object> run(
     @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
     @RequestParam(name="strategy", defaultValue="SMA_CROSS") String strategy,
     @RequestParam(name="spreadPips", defaultValue="1.5") double spreadPips) {
    if (!"SMA_CROSS".equals(strategy)) throw new IllegalArgumentException("Demo backtest supports SMA_CROSS only");
    if (!Double.isFinite(spreadPips) || spreadPips<0 || spreadPips>100)
      throw new IllegalArgumentException("spreadPips must be within 0..100");
    symbol=market.symbol(symbol);
    List<MarketService.Candle> bars=market.candles(symbol,200);
    List<Double> closes=technical.closes(bars);
    double pip = symbol.equals("USDJPY") ? .01 : symbol.equals("XAUUSD") ? .1 : .0001;
    boolean holding=false;
    double entry=0,netPips=0;
    int trades=0,winners=0;
    for (int i=26; i<bars.size()-1; i++) {
      double prevFast=technical.sma(closes,10,i-1);
      double prevSlow=technical.sma(closes,25,i-1);
      double fast=technical.sma(closes,10,i);
      double slow=technical.sma(closes,25,i);
      if(!holding && prevFast<=prevSlow && fast>slow) {
        entry=bars.get(i+1).open(); holding=true;
      } else if(holding && prevFast>=prevSlow && fast<slow) {
        double pips=(bars.get(i+1).open()-entry)/pip-spreadPips;
        netPips+=pips; trades++; if(pips>0) winners++;
        holding=false;
      }
    }
    return Map.of("symbol",symbol,"strategy",strategy,"source","SYNTHETIC_DEMO",
      "tradesClosed",trades,"winningTrades",winners,"netPips",Math.round(netPips*100.0)/100.0,
      "spreadPipsPerRoundTrip",spreadPips,"openPositionNotMarkedToMarket",holding,
      "disclaimer","Not historical data, not a reliable performance estimate");
  }
}
'@

Write-ProjectFile 8 'backend/app/src/main/java/com/tradeyar/app/risk/RiskController.java' @'
package com.tradeyar.app.risk;

import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Indicative forex lot sizing; not an order authorization or broker quote. */
@RestController
@RequestMapping("/api/risk")
public class RiskController {
  public record RiskRequest(double equity, double riskPercent, double stopLossPips, double pipValuePerLot) { }
  @PostMapping("/position-size") public Map<String,Object> size(@RequestBody RiskRequest request) {
    if (request==null || !Double.isFinite(request.equity()) || request.equity()<=0 ||
        !Double.isFinite(request.riskPercent()) || request.riskPercent()<=0 || request.riskPercent()>1 ||
        !Double.isFinite(request.stopLossPips()) || request.stopLossPips()<1 ||
        !Double.isFinite(request.pipValuePerLot()) || request.pipValuePerLot()<=0)
      throw new IllegalArgumentException("Invalid input; riskPercent must be <= 1%");
    double budget=request.equity()*request.riskPercent()/100.0;
    double raw=budget/(request.stopLossPips()*request.pipValuePerLot());
    double lots=Math.floor(Math.min(raw,10.0)*100.0)/100.0;
    return Map.of("lots",Math.max(lots,0),"riskBudget",budget,"riskPercent",request.riskPercent(),
      "note","Indicative only; broker symbol specs, conversion, margin and slippage are not verified",
      "authorizedToTrade",false);
  }
}
'@

Write-ProjectFile 8 'backend/app/src/main/java/com/tradeyar/app/signals/SignalsController.java' @'
package com.tradeyar.app.signals;

import com.tradeyar.app.strategies.StrategyService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/signals")
public class SignalsController {
  private final StrategyService strategies;
  SignalsController(StrategyService strategies) { this.strategies=strategies; }
  @GetMapping("/preview") public Map<String,Object> preview(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return Map.of("signal",strategies.evaluate(symbol,"SMA_CROSS"),
      "confidenceValidated",false,"tradePermitted",false,"riskApproved",false);
  }
}
'@

Write-ProjectFile 8 'backend/app/src/test/java/com/tradeyar/app/risk/RiskControllerTest.java' @'
package com.tradeyar.app.risk;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class RiskControllerTest {
  @Test void rejectsOversizedRisk() {
    var risk=new RiskController();
    assertThrows(IllegalArgumentException.class, () -> risk.size(new RiskController.RiskRequest(1000,3,20,10)));
  }
  @Test void calculatesBudget() {
    var risk=new RiskController();
    assertEquals(10.0,(double)risk.size(new RiskController.RiskRequest(1000,1,20,10)).get("riskBudget"));
  }
}
'@

Write-ProjectFile 9 'backend/app/src/main/java/com/tradeyar/app/paper/PaperTradingService.java' @'
package com.tradeyar.app.paper;

import com.tradeyar.app.market.MarketService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class PaperTradingService {
  public record PaperRequest(String symbol,String side,double lots) { }
  public record PaperOrder(String id,String symbol,String side,double lots,double fillPrice,
                           String createdAt,String status,String executionMode) { }
  private final ConcurrentHashMap<String,PaperOrder> orders=new ConcurrentHashMap<>();
  private final MarketService market;
  public PaperTradingService(MarketService market) { this.market=market; }
  public PaperOrder submit(PaperRequest request) {
    if (request==null || request.side()==null || !(request.side().equals("BUY") || request.side().equals("SELL")) ||
        !Double.isFinite(request.lots()) || request.lots()<0.01 || request.lots()>1.0)
      throw new IllegalArgumentException("side must be BUY/SELL and lots 0.01..1.0");
    String symbol=market.symbol(request.symbol());
    Map<String,Object> quote=market.quote(symbol);
    double fill=(double) quote.get(request.side().equals("BUY") ? "ask" : "bid");
    String id=UUID.randomUUID().toString();
    PaperOrder order=new PaperOrder(id,symbol,request.side(),request.lots(),fill,
      Instant.now().toString(),"SIMULATED_FILL","PAPER_ONLY");
    orders.put(id,order);
    return order;
  }
  public List<PaperOrder> all() {
    List<PaperOrder> result=new ArrayList<>(orders.values());
    result.sort(Comparator.comparing(PaperOrder::createdAt).reversed());
    return result;
  }
}

@RestController
@RequestMapping("/api/paper")
class PaperController {
  private final PaperTradingService paper;
  PaperController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping("/orders") public Map<String,Object> list() {
    return Map.of("orders",paper.all(),"mode","PAPER_ONLY","persistence","MEMORY_ONLY");
  }
  @PostMapping("/orders") public PaperTradingService.PaperOrder order(
     @RequestBody PaperTradingService.PaperRequest request) { return paper.submit(request); }
}
'@

Write-ProjectFile 9 'backend/app/src/main/java/com/tradeyar/app/journal/JournalController.java' @'
package com.tradeyar.app.journal;

import com.tradeyar.app.paper.PaperTradingService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/journal")
public class JournalController {
  private final PaperTradingService paper;
  public JournalController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping public Map<String,Object> journal() {
    return Map.of("entries",paper.all(),"scope","PAPER_ONLY",
      "persistence","MEMORY_ONLY","realizedPnLAvailable",false);
  }
}
'@

Write-ProjectFile 10 'backend/app/src/main/java/com/tradeyar/app/news/NewsController.java' @'
package com.tradeyar.app.news;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Explicit sample events, not current market/economic news. */
@RestController
@RequestMapping("/api/news")
public class NewsController {
  @GetMapping("/events") public Map<String,Object> events() {
    return Map.of("connected",false,"source","STATIC_EXAMPLES","live",false,
      "events",List.of(Map.of("title","Sample central bank decision","currency","USD","impact","HIGH"),
                       Map.of("title","Sample inflation release","currency","EUR","impact","MEDIUM")));
  }
}
'@

Write-ProjectFile 10 'backend/app/src/main/java/com/tradeyar/app/ai/AiController.java' @'
package com.tradeyar.app.ai;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai")
public class AiController {
  private final HttpClient client=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
  @GetMapping("/status") public Map<String,Object> status() {
    String base=System.getenv().getOrDefault("TRADEYAR_AI_URL","http://127.0.0.1:8001");
    // Only loopback URLs are permitted for the development bridge.
    if (!(base.startsWith("http://127.0.0.1:") || base.startsWith("http://localhost:")))
      return Map.of("status","DISABLED","modelLoaded",false,"reason","Only loopback AI URLs are permitted");
    try {
      URI uri=URI.create(base+"/health");
      HttpRequest req=HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(2)).GET().build();
      HttpResponse<String> resp=client.send(req,HttpResponse.BodyHandlers.ofString());
      return Map.of("status",resp.statusCode()==200 ? "CONNECTED" : "UNAVAILABLE",
        "modelLoaded",false,"readyForTrading",false,"httpStatus",resp.statusCode());
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      return Map.of("status","UNAVAILABLE","modelLoaded",false,"readyForTrading",false);
    } catch (Exception ex) {
      return Map.of("status","UNAVAILABLE","modelLoaded",false,"readyForTrading",false);
    }
  }
}
'@

Write-ProjectFile 10 'python/ai-service/app/main.py' @'
"""TradeYar AI adapter. No model is trained or loaded."""
from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="TradeYar AI", version="0.2.0")

class PredictionRequest(BaseModel):
    symbol: str = Field(min_length=3, max_length=20)
    features: dict[str, float] = Field(default_factory=dict)

@app.get("/health")
def health():
    return {"service": "tradeyar-ai", "status": "READY", "model_loaded": False,
            "trade_authorized": False}

@app.post("/predict")
def predict(request: PredictionRequest):
    return {"symbol": request.symbol, "signal": "NO_SIGNAL", "implemented": False,
            "trade_authorized": False, "reason": "No trained and validated model exists"}

@app.get("/predict")
def get_predict():
    return {"signal": "NO_SIGNAL", "implemented": False, "trade_authorized": False}
'@

Write-ProjectFile 10 'backend/app/src/main/java/com/tradeyar/app/alerts/AlertsController.java' @'
package com.tradeyar.app.alerts;

import com.tradeyar.app.market.MarketService;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.web.bind.annotation.*;

/** Development alerts are evaluated on demand; no notifications are sent. */
@RestController
@RequestMapping("/api/alerts")
public class AlertsController {
  public record Alert(String id,String symbol,String when,double threshold) { }
  public record AlertRequest(String symbol,String when,double threshold) { }
  private final ConcurrentHashMap<String,Alert> alerts=new ConcurrentHashMap<>();
  private final MarketService market;
  public AlertsController(MarketService market) { this.market=market; }
  @GetMapping public Map<String,Object> list() {
    return Map.of("alerts",alerts.values(),"persistence","MEMORY_ONLY","deliveryEnabled",false);
  }
  @PostMapping public Alert create(@RequestBody AlertRequest request) {
    if (request==null || !("ABOVE".equals(request.when()) || "BELOW".equals(request.when())) ||
      !Double.isFinite(request.threshold()) || request.threshold()<=0)
      throw new IllegalArgumentException("Invalid threshold/condition");
    Alert alert=new Alert(UUID.randomUUID().toString(),market.symbol(request.symbol()),
      request.when(),request.threshold());
    alerts.put(alert.id(),alert);
    return alert;
  }
  @GetMapping("/check") public Map<String,Object> check() {
    var results=alerts.values().stream().map(alert -> {
      double bid=(double)market.quote(alert.symbol()).get("bid");
      boolean triggered=alert.when().equals("ABOVE") ? bid>alert.threshold() : bid<alert.threshold();
      return Map.of("id",alert.id(),"triggered",triggered,"price",bid,"source","SYNTHETIC_DEMO");
    }).toList();
    return Map.of("results",results,"deliveryEnabled",false);
  }
}
'@

Write-ProjectFile 10 'backend/app/src/main/java/com/tradeyar/app/reports/ReportsController.java' @'
package com.tradeyar.app.reports;

import com.tradeyar.app.paper.PaperTradingService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/reports")
public class ReportsController {
  private final PaperTradingService paper;
  public ReportsController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping("/overview") public Map<String,Object> overview() {
    return Map.of("paperOrders",paper.all().size(),"realizedPnLAvailable",false,
       "winRateAvailable",false,"source","MEMORY_ONLY","liveTrades",0,
       "disclaimer","Fill counts only; positions, costs and closing P/L are not modeled");
  }
}
'@

Write-ProjectFile 10 'backend/app/src/main/java/com/tradeyar/app/education/EducationController.java' @'
package com.tradeyar.app.education;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/education")
public class EducationController {
  @GetMapping("/lessons") public Map<String,Object> lessons(@RequestParam(name="lang", defaultValue="fa") String lang) {
    if (!("fa".equals(lang) || "en".equals(lang))) throw new IllegalArgumentException("lang must be fa or en");
    boolean fa=lang.equals("fa");
    return Map.of("lang",lang,"lessons",List.of(
      Map.of("id","intro","title",fa ? "مبانی بازار فارکس" : "Forex fundamentals"),
      Map.of("id","risk","title",fa ? "مدیریت ریسک و سرمایه" : "Risk and capital management"),
      Map.of("id","backtest","title",fa ? "خطاهای رایج در بک‌تست" : "Common backtesting mistakes")));
  }
}
'@

Write-ProjectFile 11 'backend/app/src/main/java/com/tradeyar/app/execution/LiveExecutionController.java' @'
package com.tradeyar.app.execution;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** This prototype has no path for order submission to MT5 or any broker. */
@RestController
@RequestMapping("/api/live")
public class LiveExecutionController {
  @GetMapping("/status") public Map<String,Object> status() {
    return Map.of("enabled",false,"state","LOCKED","brokerConnected",false,
      "note","Authentication, reconciliation, risk gates and safety review are required");
  }
  @PostMapping("/orders") public void reject(@RequestBody(required=false) String ignored) {
    throw new ResponseStatusException(HttpStatus.LOCKED,"Real-money order execution is disabled");
  }
}
'@

Write-ProjectFile 11 'backend/app/src/test/java/com/tradeyar/app/execution/LiveExecutionTest.java' @'
package com.tradeyar.app.execution;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class LiveExecutionTest {
  @Test void alwaysRejects() {
    var controller=new LiveExecutionController();
    assertEquals(false,controller.status().get("enabled"));
    assertThrows(ResponseStatusException.class,() -> controller.reject("{}"));
  }
}
'@

Write-Host ("Generated/updated: {0} | unchanged: {1} | backed up: {2}" -f $created,$unchanged,$backedUp) -ForegroundColor Green
if ($backedUp -gt 0) { Write-Host "Original files saved to: $backupRoot" -ForegroundColor Yellow }
Write-Host 'No real trading is enabled. Sample quotes and in-memory stores must not be used in production.' -ForegroundColor Yellow
if ($Verify) {
  if ($Stage -ne 'All') { Write-Warning 'Verification is best run after all phases have been applied.' }
  if (Get-Command mvn -ErrorAction SilentlyContinue) {
    & mvn -f (Join-Path $Root 'backend/pom.xml') test
    if ($LASTEXITCODE -ne 0) { throw 'Maven tests failed' }
  } else { Write-Warning 'Maven not found; Java tests skipped.' }
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    $front = Join-Path $Root 'frontend'
    if (Test-Path (Join-Path $front 'node_modules')) {
      Push-Location $front
      try {
        & npm run build
        if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed' }
      } finally { Pop-Location }
    } else { Write-Warning 'Frontend dependencies not installed; run npm install in frontend first.' }
  }
}
Write-Host 'Next: run .\scripts\Setup-TradeYar.ps1 -InstallDependencies; then .\scripts\Start-TradeYar.ps1' -ForegroundColor Green
