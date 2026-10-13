# TradeYar v0.4.1 — Quick Start UX / تجربه شروع سریع

## Scope and status

This is an actual incremental patch on **locally installed v0.4**; it is NOT a live broker execution system. It does not import ten years of historical data, train ML models, compute genuine multi-timeframe market signals, or modify the hard lock on `/api/live/orders` (HTTP 423).

- New primary navigation: Quick Start, Workspace, Knowledge, Appearance.
- Advanced M01–M23 tools remain reachable under a collapsed section.
- Wizard: style -> symbol/timeframe -> DEMO/REAL view mode, equity, hypothetical pip value, stop, risk and leverage *scenario* -> review.
- Three layouts: side, top, compact. Four visual themes: night, day, ocean, plum. Preferences saved only in browser localStorage.
- DEMO: explicit, confirmed paper order through existing `/api/paper/orders` (in-memory). REAL: view-only. Credentials are never collected by React.
- Backend v0.4.1: `GET /api/v1/workspace/snapshot` returns 20 strategy rows (3 implemented for synthetic H1 bars, 17 NOT_IMPLEMENTED) and price/candles together. UI refreshes **snapshot** every 15 seconds; synthetic values are deterministic, not live feed. Style/timeframe are saved preferences but *do not yet change strategy evaluation or market data timeframe*.
- `GET /api/v1/workspace/training/status` and `POST /api/v1/workspace/training/preflight`: report missing historical research requirements, do not launch a fake training job. No progress claims without real storage, timestamps and workers.
- Risk estimates use user-entered pip value (NOT broker verified), and do not provide trade authority.
- The leverage 1:20/1:50/1:100 widget is a **comparison scenario**, not a per-trade leverage setting on MT5. Margin and liquidation risk are not verified.

## Quick start flow / جریان کار

1. Start at `http://127.0.0.1:5173/#START` or existing `#M01` bookmark.
2. Choose scalping / intraday / swing / position / weekly / custom.
3. Choose EURUSD/GBPUSD/USDJPY/XAUUSD and preferred timeframe.
4. Choose DEMO or REAL-view-only, enter an illustrative equity, max risk <= 0.25%, stop pips, pip value per lot, leverage scenario. No secret or broker password is requested.
5. Review and press Finish. The workspace opens and shows a synthetic chart and strategy status table.
6. Paper orders are manual and require browser confirmation. REAL mode never sends an order.
7. Open Knowledge to see preflight requirements for authentic training.
8. Open Appearance to preview and save theme/layout. Reset returns to night/sidebar.

## Validation and operational commands

From repository root, with current v0.4 source installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\Downloads\Install-TradeYar-QuickStart-v041.ps1" -ProjectPath "D:\ChatGPT_Projects\TradeYar" -PayloadZip "$HOME\Downloads\TradeYar-QuickStart-v041-Source.zip" -Stage All -RunTests
```

Then **restart the Spring Boot app**, run `scripts/Test-TradeYar-QuickStart.ps1`, and start frontend via `npm run dev`.

If a v0.4 file is missing or the source archive hash differs, the installer fails before writing. Backups are stored inside `.tradeyar-backups/`; no commit/push or Windows security modifications happen automatically.

## Expected smoke test

- 20 strategy rows, 3 implemented, 17 unimplemented.
- `entryAllowed=false`, `realExecutionEnabled=false`, `actualLiveMarketFeed=false`.
- Synthetic 100 H1 candles; style is *not* claimed to change indicator timeframe.
- Training jobs = 0, trained models = 0, preflight returns `started=false`.
- HTTP 423 for real order POST unchanged.

## Security / REAL mode future work

Do not put user/broker passwords into `.env` committed to Git, browser localStorage, GitHub Actions output or URLs. A future local broker connector would need Windows Credential Manager / DPAPI, explicit user consent and a segregated demo-vs-live account profile, signed broker API adapter, symbol specifications, independent risk gates, reconciliation, kill-switch, order idempotency, audit log and regulatory review. This release intentionally has no real-money order pathway.

## Baseline note

The user's GitHub may lag their local workspace; install targets **v0.4 local source** (including `frontend/src/modules/ResearchModules.tsx`). Do not rebuild stage 2 with the legacy generator: that can overwrite modern frontend sources. Keep changes safe, inspect `git diff --check`, test locally, then commit.
