# TradeYar v0.6 — Historical archive, 20 strategy research, and Help Center

## Scope, safety and explicit limitations

This package adds **research-quality code and a persistent archival workflow**, not a trained predictive model or broker order execution. All strategy rules remain **independently unvalidated**. In particular, parameter selection among three presets on a 60/20/20 split with **at most 1,200 input bars** is *preliminary calibration*; it is neither complete ten-year learning nor independent proof of profitability. Real-money orders stay hard-locked at HTTP 423. A research dataset requires a real, locally authenticated MT5 terminal and explicit historical retrieval; it is **not bundled**. Histories differ by broker, instrument and timeframe.

## What is stored so it never has to be retrieved unnecessarily?

| Source | Local persistent copy | PostgreSQL table |
| --- | --- | --- |
| Closed OHLC candles from read-only MT5 archive/bridge | `.../TradeYar/history/SYMBOL/FRAME/YYYY-MM.csv` plus `_manifest.json` and `_revisions/` | `tradeyar_research.history_bars`, `history_imports`, `history_bar_revisions`, `history_collection_periods` |
| Preliminary calibration outcomes for all 20 strategies | `%USERPROFILE%/.tradeyar/research/v06-RUN-ID.json` | `calibration_runs_v06`, `calibration_strategy_results_v06` |
| One analysis snapshot with all 20 votes per newly closed bar for a local CSV feed | `%USERPROFILE%/.tradeyar/research/analysis-events-v06.jsonl` | `analysis_snapshots_v06`, `analysis_strategy_signals_v06` |
| Sync receipts | Database only | `data_sync_runs_v06` |

Data remains on disk after a PostgreSQL outage. Set `TRADEYAR_PG_DSN` **locally**, never in Git. When it exists, collectors automatically synchronize **changed history months** to PostgreSQL immediately. To retry older archives, research runs, or signal events, execute `scripts/Invoke-TradeYar-DataSync.ps1`. All imports are idempotent using SHA-256 or composite keys. Existing OHLC history is never silently overwritten; different broker readings are archived as revisions. A `MISSING` month is recorded distinctly from an imported month.

**Important:** this package archives the bar data and analysis outputs it **actually acquires**; it does not invent market tick history, verified broker provenance, trades or ML models. Tick-by-tick storage requires a separately implemented verified Tick collector, suitable schema and vendor permissions. Demo OHLC is not treated as verified market data. Retain data according to the broker/data-vendor licence; deploy encryption-at-rest, backup/restore and retention policies before multi-user use.

## One-time database setup (approved PostgreSQL)

1. Provision a local research database and limited-privilege role. Keep credentials in an approved local secret store or protected environment; **not** in `.env` committed to Git.
2. Apply `infrastructure/db/v06_history.sql` with `psql` through your approved authenticated session. The schema is additive to v0.5.
3. Install Python 3.11+ and vetted `psycopg>=3` in a local environment. `MetaTrader5` Python binding is optional for historical collection.
4. Set `TRADEYAR_PG_DSN` for the importing process locally. Never paste connection strings into logs/screenshots.

```powershell
cd D:\ChatGPT_Projects\TradeYar
# Only if approved / configured: apply schema once using your usual PostgreSQL connection.
psql -v ON_ERROR_STOP=1 -f .\infrastructure\db\v06_history.sql
# Retry any pending archived data plus 20-strategy research runs and analysis events.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-DataSync.ps1
# Optional ongoing background sync in a dedicated console (Ctrl+C stops):
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-DataSync.ps1 -Watch -IntervalSeconds 300
```

Without `TRADEYAR_PG_DSN`, **local data is saved**, but database import is **not** performed. A failed database import reports a nonzero exit code; source files remain intact and can be replayed later. Back up both the PostgreSQL DB and local archive to a secure storage target; importing again from archived files cannot replace an off-site backup.

## One-time historical backfill and daily updates

```powershell
cd D:\ChatGPT_Projects\TradeYar
# Inspect date range and target without broker access:
py -3 .\scripts\collect_mt5_history_v06.py --symbol EURUSD --timeframe H1 --years 10 --dry-run
# Collect when MT5 is already installed and logged in (no credentials saved):
py -3 .\scripts\collect_mt5_history_v06.py --symbol EURUSD --timeframe H1 --years 10
# Run again later: intact older months are CACHED, active month is merged, missing months retried.
# Existing data can be synchronized to PostgreSQL without invoking MT5:
py -3 .\scripts\import_history_postgres_v06.py --folder "$env:LOCALAPPDATA\TradeYar\history\EURUSD\H1"
```

The `mt5_readonly_bridge.py` file is enhanced in v0.6: every read-only closed-bar export also merges into the monthly archive; new periods sync automatically to the DB when configured. The bridge must be started explicitly. **Do not run multiple archive writers on the same symbol/timeframe concurrently** without a shared lock or orchestrator. Separate demo and real-account data sources by environment and provider; this starter supports only a single configured MT5 export for each symbol/timeframe.

## Research calibration and results

- Set `TRADEYAR_ENABLE_LOCAL_RESEARCH=true` only on your trusted workstation and restart backend. Calibration endpoint is restricted to loopback clients.
- Use Help Center → Knowledge / calibration to begin a run. The endpoint requires at least 600 closed, real MT5 **CSV bars** and uses a **maximum 1200 bars** from the configured local read-only feed. This can be less than a decade, even with a decade stored in PostgreSQL.
- Each strategy produces training, validation and held-out metrics. Results save to local files immediately; PostgreSQL synchronization is done through the data sync worker.
- Do not reuse held-out results to select parameters. For real 10-year learning, implement a database-backed walk-forward scheduler with complete per-bar historical data, cost and liquidity models, multiple independent out-of-sample windows, model registry and reproducibility checks. This package intentionally makes no 10-year trained-model claims.

## Help Center

Visit `http://127.0.0.1:5173/#HELP` for the searchable Persian/English Help Center, guided quick-start, connecting read-only MT5, strategy results, data archive, and failure recovery. Module-level guides for M01–M23 remain accessible through the advanced tools.

## Verification / release gates

Run Python unit tests with `python -m unittest discover -s tests -v`, Maven backend tests, `npm run build` in frontend and REST smoke tests. Confirm live order endpoint returns HTTP 423. A connected PostgreSQL and MT5 terminal must be tested on the user's machine; these are **not** included in build tests. Never interpret build success as evidence of ten-year data import, successful calibration, or trading profitability.
