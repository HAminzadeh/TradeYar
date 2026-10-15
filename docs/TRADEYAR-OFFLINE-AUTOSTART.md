# TradeYar v0.6.3 — Safe automatic startup of research infrastructure

## What was already done (DO NOT repeat at every start)

1. One-time operator-approved `docker pull` / ClickHouse Docker Official Image acquisition.
2. One-time SHA-256-audited image `Seed`, `Verify`, and metadata registration in the **separate** `TradeYar-OfflineDepot` directory.
3. One-time identification of the shared **SakhtYar** MinIO container and storage of `manifests/shared-minio.json` (not credentials).

No Docker archives, general development caches, credentials, or database volumes belong in Git.

## Source reconciliation against master at commit 901d66a (October 15, 2026)

The baseline `scripts/Start-TradeYar-Offline.ps1` still refers to the obsolete `clickhouse/clickhouse-server:25.3` while the final three-image lock and Compose correctly require `clickhouse:25.3.14.14`. The installer updates **only this pinned image/archive mapping** within the legacy offline launcher, backs up that source file outside Git, and keeps the rest of the script unchanged. No image is downloaded or re-exported at runtime.

## Integrated startup

`Start-TradeYar.ps1` (the existing human-facing launcher) now runs `Start-TradeYar-ResearchServices.ps1 -Mode Start` **before** launching its original backend/frontend/optional AI processes. The research starter:

1. Reads the exact pinned three-image lock file and compares it to `infrastructure/v063/compose.yml`.
2. Checks that the shared MinIO container from `TradeYar-OfflineDepot/manifests/shared-minio.json` is *already running* with the same image ID and exposed S3 API host port. It NEVER creates, restarts, removes, changes credentials or volumes, or backs up another project's MinIO.
3. Checks the private, uncommitted `infrastructure/v063/.env` and validates Compose without printing secrets.
4. Uses the existing offline depot manager to verify local TAR SHA-256 and, only for missing images, restore audited archives with `docker load`.
5. Reuses healthy, matching **TradeYar-owned** containers; otherwise uses `docker compose --project-name tradeyar-v063 ... up -d --pull never --no-build --no-deps --no-recreate` **for only the selected services**.
6. Rejects image/container drift, offline misses and unhealthy states rather than changing containers or downloading packages.

This is research infrastructure startup only; no live trading, schema migrations, MT5 login, AI training, or brokerage interactions are enabled.

## First-time secrets setup (manual, outside Git)

Copy `infrastructure/v063/.env.example` to `infrastructure/v063/.env` if missing, then replace placeholder secrets with strong unique credentials. This configuration is needed for the three dedicated research services. Never commit `.env`. Do not put shared MinIO root credentials into this file. The shared MinIO service is external and **S3 bucket / least-privilege credentials / application client integration are not implemented by this launcher**.

## Commands (PowerShell 5.1)

```powershell
$Project = 'D:\ChatGPT_Projects\TradeYar'
$Startup = Join-Path $Project 'scripts\Start-TradeYar-ResearchServices.ps1'

# Non-mutating preflight; does NOT start any research services:
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Startup -ProjectPath $Project -Mode Check
if ($LASTEXITCODE -ne 0) { throw 'Research environment preflight failed' }

# Normal integrated application startup (brings up research infrastructure first):
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Project 'scripts\Start-TradeYar.ps1')
if ($LASTEXITCODE -ne 0) { throw 'TradeYar launcher failed' }

# Demo-only compatibility mode (starts original backend/frontend, no research Compose changes):
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Project 'scripts\Start-TradeYar.ps1') -DemoOnly
```

### Optional strict offline application mode

The standard main launcher preserves the pre-existing Maven/npm application startup after preparing the *Docker research infrastructure*; the older Maven command might reach a registry. To make **the application launch itself** use offline-only Maven and local frontend modules, explicitly choose:

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Project 'scripts\Start-TradeYar.ps1') -StrictOfflineApplication
```

This first prepares research infrastructure, then delegates to the existing `Start-TradeYar-Offline.ps1 -Mode Start -NoServices -StartFrontend`. Missing compatible project-local Maven/Java dependencies or installed frontend modules give an actionable offline failure: **no online fallback**. Such generic development dependencies are deliberately NOT mirrored by Phase 2. `-DemoOnly -StrictOfflineApplication` skips research services and launches only the offline app.

### IntelliJ / IDE caveat

Launching the Spring Boot class directly in IntelliJ **does not execute `Start-TradeYar.ps1`**. Configure a `Before Launch` external tool to call `Start-TradeYar-ResearchServices.ps1 -Mode Start`, or use the integrated PowerShell launcher. Set `TRADEYAR_AUTO_REPAIR_ON_STARTUP=false` in the IDE run configuration, too, to avoid old download-capable repair paths. No IDE settings or run configurations are overwritten by the installer.

### What a successful startup does **not** guarantee

Without healthchecks, `RUNNING` is only a container state, not a validated SQL/Cypher/ClickHouse query. Schema creation, database logins, historical data ingestion, and shared MinIO bucket/credential integration remain separate tasks. Do not use this platform for real-money trading.

The existing backend/frontend launcher uses Maven/npm tools and may have their own network configuration; this package only guarantees **Docker research infrastructure** does not download during startup. It intentionally does NOT mirror JDK/Maven/npm/Python caches.

## Safe recovery

If a startup fails: first examine the `[TRADEYAR-STARTUP]` message, run `-Mode Check`, inspect local `.env`, and run `-Mode Verify` via the offline depot manager. Do not run `docker system prune`, `docker compose down -v`, or manually delete shared volumes. The installer makes a backup of the original `Start-TradeYar.ps1` outside Git and makes no changes to running containers.

CI: `.github/workflows/offline-depot-policy.yml` is updated to run both offline image inventory and auto-start contract tests with `test_offline*.py`.
