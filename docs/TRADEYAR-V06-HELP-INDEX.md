# TradeYar Help Center — index

**Persian default / English available**. Open `/#HELP` in the local frontend.

- Quick start: choose trading style, symbol, requested timeframe and demo-only risk settings; finish to see the research workspace.
- Market feed: synthetic prices are for UI testing only. Set up an already installed, logged-in MT5 terminal and read-only bridge to use local **closed bars**.
- Knowledge: backfill historical UTC months with `collect_mt5_history_v06.py`; verified monthly files are reused on subsequent runs. Read `docs/TRADEYAR-V06-RESEARCH-AND-ARCHIVE.md`.
- Storage: set approved PostgreSQL and execute `infrastructure/db/v06_history.sql`; imports are idempotent, failures retain the archive locally.
- Research: explicitly enable `TRADEYAR_ENABLE_LOCAL_RESEARCH=true` on trusted local machine only. Preliminary calibration does not train an ML model and does not certify profitability.
- Analysis: research strategies use price bars; 16/20 votes do not establish a probability of success. Every real broker order remains locked.
- Troubleshooting: if MT5 is disconnected, the source is marked `SYNTHETIC`; if the DB is offline, the importer exits nonzero and data remains in local archive. Retry after restoring the DB without another MT5 download.

See the application's contextual M01–M23 guides for individual functionality and parameter defaults.
