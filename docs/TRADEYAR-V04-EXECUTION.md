# TradeYar v0.4 — Executable stage 0/1 delivery and 12-stage implementation roadmap

**Baseline:** `HAminzadeh/TradeYar` v0.3.0, commit `5549b4c9ee49c6b205bcbae083daa8f85c6547da`.

**Implemented in this delivery:** Stage **0** (backend read-only research contracts, safety test, existing API preservation), Stage **1** (grouped sidebar, M21/22/23 readiness pages, localized per-module guides, safe page defaults and reset).

**Not implemented in this delivery:** Stages 2–11. The installer explicitly refuses them rather than claiming success. It does not download prices, install MT5, fetch ten years of history, train ML, use PostgreSQL, or enable real-money trading.

## Installation process

1. Place `Install-TradeYar-v04.ps1` and `TradeYar-v04-Phase01-Source.zip` together in Downloads.
2. Stop the running frontend. Backend may remain running during installation, but **restart** it after compilation.
3. Run PowerShell from any directory:

```powershell
$Project = 'D:\ChatGPT_Projects\TradeYar'
$Script = Join-Path $HOME 'Downloads\Install-TradeYar-v04.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ProjectPath $Project -Stage All -RunTests
if ($LASTEXITCODE -ne 0) { throw 'TradeYar v0.4 upgrade or tests failed' }
```

`All` means **all stages that are implemented in this source bundle: 0 and 1**. It is not the full 12-phase build.

To run or rerun only stage 0: `-Stage 0`. To rerun stage 1, which also verifies/installs stage 0 prerequisites: `-Stage 1`. Status: `-Stage Status`; verification without copying: `-Stage Verify`. Other stage numbers (2–11) exit explicitly as `NOT_IMPLEMENTED`.

`-RunTests` requires `mvn` available, a working Maven Central connection and installed frontend `node_modules`. If `node_modules` is missing, run `cd frontend; npm install` first. The installer never bypasses endpoint protection or silently accesses privileged destinations.

4. Restart backend using `scripts/Invoke-TradeYar-Maven.ps1 -Goal Start` (or IntelliJ).
5. Run `scripts/Test-TradeYar-v04.ps1` in another terminal; this confirms safety HTTP 423, registry compatibility, 6 profiles, strict lack of consensus and M23 no-data status.
6. Run `npm run dev` from frontend, then visit `http://127.0.0.1:5173/#M22`.
7. Review `git status --short` and `git diff --check`. Nothing is auto-committed or pushed.

## Files and functionality

- `frontend/src/App.tsx`: 7 grouped collapsible categories, search, per-section guide/reset, keyboard-accessible buttons.
- `frontend/src/modules/catalog.ts`: 23 UI items, 20 existing + M21/22/23.
- `frontend/src/modules/guides.ts` and `docs/modules/Mxx.md`: Persian/English scope, use, defaults, limitations and error information for each of 23 modules.
- `frontend/src/modules/profiles.ts`: 6 styles (`SCALP`, `INTRADAY`, `SWING`, `POSITION`, `WEEKLY`, `CUSTOM`); browser persistence with schema checking and reset. Defaults are conservative **paper research suggestions**, not optimized for profit.
- `frontend/src/modules/ResearchModules.tsx`: read-only consensus coverage, 6-style selector, honest M23 research readiness.
- `ResearchReadinessController.java`: GET read-only endpoints for readiness. Does not alter existing `/api/modules` response, keeping legacy 20-module smoke tests compatible.
- `ResearchReadinessContractTest.java`: Java safety regression for 3 evaluated / 20 required and 0 verified history.
- `scripts/Check-TradeYar-MT5.ps1`: read-only detection from common locations. No auto-install without explicit consent.

## Why M21 and M23 are not claimed functional beyond readiness

Current `StrategyService` evaluates only 3 of the 20 catalog entries. A strict 16/20 consensus, especially if 20 independent validated evaluations are required, therefore cannot be reached. The project has no verified 10-year source, immutable dataset snapshot, ETL jobs, train/test split, or trained model registry. The v0.4 contract honestly reports `INSUFFICIENT_EVIDENCE` / `WAITING_FOR_DATA`.

## Remaining stages (design, not shipped implementation)

- 2: PostgreSQL persistent profiles/knowledge schema, Flyway migrations, audit and RBAC.
- 3: explicit-consent official signed MT5 installer and read-only terminal/account adapter.
- 4: multi-timeframe, provenance-checked market ingestion, quote freshness and QC.
- 5: resumable historical backfill, immutable snapshot registry and verified coverage (up to 10 years if provider permits).
- 6: all 20 strategies with compatible profiles, parameters and unit/parity tests.
- 7: cost-aware backtest, walk-forward, untouched holdout and simulated fills.
- 8: M23 learning registry, incremental daily outcomes, optional gated ML and drift alarms.
- 9: M21 strict 16/20 independent-family gating plus hard risk/data veto.
- 10: persistent paper-only execution, journal and reporting.
- 11: production-quality QA, resource caps, incident monitoring, recovery and release checks.

The safe delivery boundary remains: `/api/live/orders` returns 423; model output is never a broker execution authorization. Do not substitute synthetic data for real historical results.
