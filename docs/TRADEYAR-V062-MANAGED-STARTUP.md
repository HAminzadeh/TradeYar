# TradeYar v0.6.2 — Windows managed startup and prerequisite inventory

## What this release does

* At **every Spring Boot startup**, `StartupDependencyMonitor` writes individual `[BOOTSTRAP]` checks to the same logs you see in IntelliJ. It checks the running Java version, Node, npm, Python, project Maven launcher, frontend packages, `psycopg`, MetaTrader5 Python binding, `psql`, localhost PostgreSQL/Redis/AI listener ports, PostgreSQL environment configuration (never contents), MT5 executable, market-history manifest, local enrollment, and live execution lock. Each subsequent scan (default every 120 seconds) logs **state changes** rather than flooding the console.
* The read-only JSON view is `GET /api/v1/bootstrap/status`. It never returns credentials or directory names. Important: `PORT_OPEN` does **not** mean the service is authenticated, schema-migrated or production-ready. `INSTALLED_UNVERIFIED` MT5 does not mean the account is connected.
* A Windows PowerShell 5.1 launcher checks local executables and **approved** Windows services; it reuses packages cached under `.tradeyar-runtime/packages`, extracting tools under `.tradeyar-runtime/tools`. If the operator **previously enrolled** downloads, a missing package may be fetched via an **official HTTPS URL with pinned SHA-256** specified in `infrastructure/bootstrap/dependencies.lock.json`.
* The package lock intentionally ships with **zero unverified download entries**. An absent download URL or digest means **NO DOWNLOAD** and an actionable warning, not an unsafe search-and-run. Add *confirmed* release URLs/digests before expecting fully automatic provisioning. Installer binaries require a valid Windows Authenticode signature and an expected publisher string. Package URLs, hashes, and installed Windows service names must be configured by the project operator. Windows UAC and broker logins are **never bypassed**.
* PostgreSQL and Redis **do not need to run** for current demo/research endpoints; backend still starts and flags them not ready. For persistent research import, set approved local PostgreSQL schema and `TRADEYAR_PG_DSN` separately. MT5 is **not auto-logged-in, auto-installed or started** by the backend; only operators can approve its installer and launch a broker terminal themselves. No real orders, no stored broker credentials.
* Existing `/api/live/orders` remains HTTP 423. No automatic market orders or learning jobs are launched.

## Installation into existing v0.6.1 project

Download readable `TradeYar-v062-Managed-Startup-Source.zip` and `Install-TradeYar-v062.ps1` to Downloads.

```powershell
$Project = 'D:\ChatGPT_Projects\TradeYar'
$Installer = Join-Path $HOME 'Downloads\Install-TradeYar-v062.ps1'
$Source = Join-Path $HOME 'Downloads\TradeYar-v062-Managed-Startup-Source.zip'
& powershell.exe -NoProfile -File $Installer -ProjectPath $Project -PayloadZip $Source -Stage All -RunTests
if ($LASTEXITCODE -ne 0) { throw 'v0.6.2 install or tests failed' }
```

## How to use and enroll once

**First inspect without downloads or installations**:

```powershell
cd D:\ChatGPT_Projects\TradeYar
& powershell.exe -NoProfile -File .\scripts\Start-TradeYar-Managed.ps1 -Mode Check
```

**Choose an explicit policy** (examples):

```powershell
# Allows only authorized Windows service restarts. No network downloads.
& powershell.exe -NoProfile -File .\scripts\Start-TradeYar-Managed.ps1 -Mode Enroll -ApproveServiceStart

# OPTIONAL, only AFTER reviewing official source URLs/hashes in dependencies.lock.json:
# & powershell.exe -NoProfile -File .\scripts\Start-TradeYar-Managed.ps1 -Mode Enroll -ApproveDownloads -ApproveServiceStart -ApproveNpmInstall
# Executable installer execution is a SEPARATE, higher-risk opt-in: -ApproveSignedInstallers
```

**Configure known existing Windows service names** in `infrastructure/bootstrap/dependencies.lock.json` if any. Example service is `postgresql-x64-17`, but use the **actual value** from `Get-Service` on your machine. The lock is a template, not a claim PostgreSQL/Redis are installed. No arbitrary process paths can be executed as a managed service.

**For IntelliJ**, open Spring Boot's Run Configuration and set these environment variables:

```text
TRADEYAR_PROJECT_ROOT=D:\ChatGPT_Projects\TradeYar
TRADEYAR_AUTO_REPAIR_ON_STARTUP=true
```

Only set `TRADEYAR_AUTO_REPAIR_ON_STARTUP=true` after your local `Enroll` step. Restart Spring Boot. The app itself performs its startup checks immediately; if opted in it launches **a single local, auditable** repair script and forwards its log lines to the IntelliJ console. Periodic monitor scans always run; repairs are intentionally launched at startup only (avoid repeated installer loops). Logs are also saved in `.tradeyar-runtime/logs/bootstrap.log`. IntelliJ may need to be restarted to see updated external environment variables; put them directly in the Run Configuration if possible.

The managed launcher can alternatively bring up the normal Maven-backed application:

```powershell
& powershell.exe -NoProfile -File .\scripts\Start-TradeYar-Managed.ps1 -Mode Launch -StartFrontend
```

Or repair only:

```powershell
& powershell.exe -NoProfile -File .\scripts\Start-TradeYar-Managed.ps1 -Mode Repair
```

## Pinned download manifest

The manifest at `infrastructure/bootstrap/dependencies.lock.json` supports these keys:

```json
{
  "schemaVersion": 1,
  "packages": [
    {
      "id": "node",
      "url": "https://nodejs.org/dist/EXACT-VERSION/ARCHIVE.zip",
      "sha256": "REPLACE_WITH_OFFICIALLY_VERIFIED_64_HEX_SHA256",
      "type": "zip"
    }
  ],
  "services": [
    { "id": "postgresql", "windowsServiceName": "" },
    { "id": "redis", "windowsServiceName": "" }
  ]
}
```

This is **illustrative JSON**, not a valid ready-to-run lock entry. A zip is cached and extracted; an `.exe` or `.msi` additionally requires `publisherContains`, an Authenticode valid signature and explicit `-ApproveSignedInstallers`. `installArgs` is an array of install arguments; use only documented vendor flags. HTTPS hosts are allowlisted, and downloads are rejected if their exact SHA does not match. No antivirus, firewall, UAC or OS policies are altered. A package without complete verification metadata is deliberately skipped.

**Offline reinstallation:** preserve `.tradeyar-runtime/packages` (and local research/history stored outside Git). The next authorized repair verifies the cached hash first and avoids downloading it again. If the cached SHA fails, it is discarded and only then can a new verified download occur.

## Startup readiness vs. research readiness

The service inventory answers whether **tools and listeners** seem available; it does not train models, verify MT5 broker sessions, provision PostgreSQL schemas, authenticate database users or guarantee a feed. Your v0.6.1 historical archive and DataSync flow remain independent. You still need to initialize PostgreSQL, configure a safe local DSN and collect real historical data explicitly.

## Tests / security acceptance

Run Java unit tests and frontend Vite build. Verify `/api/v1/bootstrap/status` contains `LIVE_EXECUTION: LOCKED`; verify `POST /api/live/orders` returns HTTP 423; run `-Mode Check` to test diagnostics without downloads or starting a service. On a system with a configured approved service, stop it intentionally and run `-Mode Repair` to verify recovery; do not stop production services. No Git commit/push is performed by the installer.
