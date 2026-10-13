# TradeYar v0.5 — phased strategy research + SSE streaming

**Scope:** Six independent, source-controlled installation stages. Backend never authorizes or sends broker orders. This phase improves architecture, educational strategy formulas, honest data provenance, local research reproducibility and an SSE-driven UI. It does **not** certify 20 profitable or independently validated strategies, provide guaranteed ten-year data, train ML models, or create live brokerage automation.

## Pipeline

Wizard `#START` -> Workspace `#WORKSPACE` -> `GET /api/v05/stream` (SSE) -> read-only bar adapter -> 20 educational indicator rules -> 16/20 vote counter -> fail-closed data / validation / risk gate -> manual PAPER only.

* **S1 Data / streaming:** `MarketBars.java`, `StreamingV05.java`, opt-in MT5 Python exporter. The server emits snapshots every **10 seconds** through SSE; this is server-side file polling, not a real broker push feed. Unavailable CSV -> static H1 synthetic fallback, always tagged as such. The UI falls back to 15-second HTTP polling on SSE failure.
* **S2 Strategy engine:** `StrategyEngineV05` has 20 executable educational rule branches and standardized `BUY`, `SELL`, `NO_SIGNAL`, `NOT_EVALUATED` results. Every `independentlyValidated` field is FALSE until separate historical verification. Simplified implementations (Supertrend, MACD zero-line, RSI divergence, Ichimoku, pivot and DX proxy) deliberately report their methodological limitations; their names should not be interpreted as canonical production versions.
* **S3 Unit/API tests:** JUnit engine + fail-closed response contract tests, Windows PowerShell smoke script.
* **S4 Decision workspace:** preserves user’s 4-step wizard, 4 appearance themes and 3 menu layouts. SSE-based view shows 20 results and expansion details. A 16/20 count never overrides incomplete historical validation or source/risk limitations.
* **S5 Knowledge research:** Chronological **70/30** SMA demonstration only, spread cost assumption and open-position flag. Saves immutable JSONL per run in `%LOCALAPPDATA%/TradeYar/research` (unless `TRADEYAR_RESEARCH_DIR` is set). Schema for PostgreSQL and explicit opt-in importer are included, but database is **not auto-provisioned**; no ML models are trained. No walk-forward retraining, slippage modeling or data-independent performance verification yet.
* **S6 Integration and docs:** documentation, PowerShell smoke test and read-only bridge tooling.

## Install with one auditable installer (PowerShell 5.1+)

Download both the installer and source ZIP into Downloads. The installer verifies archive SHA-256 and a per-file manifest, checks the real-order lock, saves changed files under `.tradeyar-backups`, and never pushes Git changes. Stages: `S1`, `S2`, `S3`, `S4`, `S5`, `S6`, `All`, `Verify`. `All` runs stages in that order. Avoid invoking legacy source generators after installation because they may overwrite the new UI.

```powershell
$P="D:\ChatGPT_Projects\TradeYar"
$S=Join-Path $HOME 'Downloads\Install-TradeYar-v05.ps1'
$Z=Join-Path $HOME 'Downloads\TradeYar-v05-Source.zip'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $S -ProjectPath $P -PayloadZip $Z -Stage All -RunTests
if($LASTEXITCODE -ne 0){throw 'v0.5 installation or tests failed'}
```

Restart Spring Boot after build; then `npm run dev` in frontend, visit `http://127.0.0.1:5173/#WORKSPACE`. Run `scripts/Test-TradeYar-v05.ps1` while Spring Boot is active. Optional test `-RunResearchDemo` writes one research log record outside Git.

## Optional real MT5 read-only bar export

Only on an authorized Windows machine with an installed, logged-in **MetaTrader 5** desktop terminal:

```powershell
$env:TRADEYAR_MARKET_DIR = Join-Path $env:LOCALAPPDATA 'TradeYar\market'
py -3 -m pip install MetaTrader5  # optional approved dependency; verify source with IT
py -3 .\scripts\mt5_readonly_bridge.py --symbol EURUSD --timeframe M15 --bars 3000 --output-dir "$env:TRADEYAR_MARKET_DIR"
```

To request periodic **read-only CSV refresh** (not trade execution), use `--loop --interval 30` in a dedicated terminal. Restart the Java process with the **same** `TRADEYAR_MARKET_DIR` environment variable. Each symbol/timeframe pair requires its own export. The exporter excludes unfinished candle #0 and writes the file atomically; CSVs are constrained to `symbol_timeframe.csv` with exact `time,open,high,low,close,volume` header and numeric UTC epoch seconds. Historical depth is limited by the MT5 terminal/account and cannot be assumed to be ten years. For `M1` consider the 12 MB Java input limit; paginate/import larger archives in a later release. Market hours (weekend/holiday) affect the freshness flag.

**No passwords or credentials are collected or written.** The exporter connects to an already logged-in terminal using only read-only API calls. Never commit private files or your local `.env` containing account secrets.

## Research, knowledge, PostgreSQL

- `POST /api/v05/research/run` with `{"symbol":"EURUSD","timeframe":"H1","strategy":"SMA_CROSS","spreadPips":1.5}` generates a **reproducible educational run** and writes its dataset SHA-256, timestamp, periods, trading costs, and limitations to local JSONL. The held-out 30% is chronological and **not** fully blinded after repeated trial-and-error tuning.
- `infrastructure/db/v05_knowledge.sql` defines versioned research tables. On approved PostgreSQL instance, use `psql` to apply once; then set `TRADEYAR_PG_DSN` locally and run `scripts/import_research_postgres.py --file <JSONL_PATH>` with `psycopg` installed. DB import is opt-in; no DB credentials are stored in Git.
- No asynchronous ML-training jobs are launched and no paper backtest is labeled as completed AI learning. Walk-forward, tick-level slippage, full 20-strategy historical replay and independently validated model registry require subsequent dedicated implementation.

## Safety / transparency

- Real execution endpoint remains hard-locked `POST /api/live/orders -> HTTP 423`.
- `entryAllowed` and `paperReviewAllowed` are always FALSE in v0.5 until independent validation gates and risk specs exist. Manual demo orders through existing `/api/paper/orders` remain possible with explicit confirmation and are not represented as strategy-authorized trades.
- `localReadOnlyCsvAvailable` indicates that a local read-only CSV passed OHLC and timestamp checks; `verifiedBrokerFeed` remains false because file provenance is not independently authenticated. A local CSV never implies trusted tick provenance or broker-side execution readiness.
- Research CSV, local JSONL and future PostgreSQL entries do not make historical results predictive. Out-of-sample splits alone cannot prevent overfitting from repeated parameter choices.
- Validation: Java unit tests, API smoke, TypeScript build, SSE network behavior and manual UI check. Execute `git diff --check` and `git status` before committing.
