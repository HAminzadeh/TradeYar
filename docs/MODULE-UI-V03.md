# TradeYar v0.3 — Connected module UI

This release turns the existing 20 module labels into *navigable, interactive, keyboard-accessible pages*.

- **Scope:** browser workflows on top of the existing Spring Boot v0.2 REST endpoints. No new broker integration, persistence, auth, real-time feeds or trained models.
- **Language:** Persian (RTL) default and English (LTR). Toggle and theme are saved in browser storage.
- **Navigation:** `#M01` … `#M20` hashes; per-module React components render forms, status panels, API data and errors.
- **Data:** synthetic quotes/backtests, in-memory order/alerts/preferences, static news examples, AI availability and hard-locked live execution.
- **Safety:** M20 is read-only status plus a request to verify HTTP 423; no real-money submission feature exists.

## Functional pages

| Module | Browser action | API |
|---|---|---|
| M01 | Overview, health, jump to any module | `GET /api/health`, `/api/modules` |
| M02 | Toggle locale, direction, theme | local browser settings |
| M03 | Read and save server demo preferences | `GET/PUT /api/preferences` |
| M04 | Choose symbol, inspect demo quote and candles | `GET /api/market/quote`, `/candles` |
| M05 | Switch symbol, candle chart, refresh | `GET /api/charts/series` |
| M06 | Refresh read-only MT5 status | `GET /api/mt5/status` |
| M07 | Inspect demo SMA/EMA/RSI | `GET /api/technical/summary` |
| M08 | Browse 20 strategies, evaluate enabled strategies | `GET /api/strategies`, `/evaluate` |
| M09 | Run synthetic SMA backtest, edit spread | `GET /api/backtest/run` |
| M10 | Inspect non-executable signal preview | `GET /api/signals/preview` |
| M11 | Submit indicative risk sizing form | `POST /api/risk/position-size` |
| M12 | Submit demo order and view simulated fills | `GET/POST /api/paper/orders` |
| M13 | Read simulation journal | `GET /api/journal` |
| M14 | View labeled example economic events | `GET /api/news/events` |
| M15 | Query AI service readiness | `GET /api/ai/status` |
| M16 | Create demo threshold alerts, check manually | `GET/POST /api/alerts`, `GET /api/alerts/check` |
| M17 | View demo reporting counters | `GET /api/reports/overview` |
| M18 | List localized lesson titles | `GET /api/education/lessons` |
| M19 | Diagnostics and module registry | `GET /api/health`, `/api/modules` |
| M20 | Inspect live lock; test rejected request | `GET /api/live/status`, `POST /api/live/orders` (must return 423) |

## Deliberately not completed in v0.3

Fully functional real-money trading, trained AI, live news feeds, real MT5 account synchronization, full strategy catalog execution, persisted journals, actual market price subscriptions, complete user identities, realistic historical walk-forward backtests and production security. These require new backend slices and external integrations and must not be described as finished.

## Tests

- `npm run build` and `npx tsc --noEmit` in frontend.
- `powershell -File scripts/Smoke-Test-TradeYar.ps1` while Spring Boot runs.
- Run `scripts/Test-TradeYar-Modules-v03.ps1` for GET checks and non-mutating contract checks.
- Manual navigation: click M01–M20, verify each page title, controls, status and errors. M12 and M16 write only in-memory demo records.
