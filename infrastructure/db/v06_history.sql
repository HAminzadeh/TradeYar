-- TradeYar v0.6 immutable/auditable data archive (PostgreSQL 14+).
-- Run once with an approved local research DB. No account passwords stored here.
CREATE SCHEMA IF NOT EXISTS tradeyar_research;
CREATE TABLE IF NOT EXISTS tradeyar_research.history_imports (
  import_sha256 CHAR(64) PRIMARY KEY,
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  file_name VARCHAR(160) NOT NULL,
  bar_count INTEGER NOT NULL CHECK(bar_count > 0),
  imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider VARCHAR(100) NOT NULL,
  verified_provenance BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS tradeyar_research.history_bars (
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  event_at TIMESTAMPTZ NOT NULL,
  o NUMERIC(22,10) NOT NULL CHECK(o > 0),
  h NUMERIC(22,10) NOT NULL CHECK(h > 0),
  l NUMERIC(22,10) NOT NULL CHECK(l > 0),
  c NUMERIC(22,10) NOT NULL CHECK(c > 0),
  volume BIGINT NOT NULL CHECK(volume >= 0),
  import_sha256 CHAR(64) NOT NULL REFERENCES tradeyar_research.history_imports(import_sha256),
  PRIMARY KEY (symbol,timeframe,event_at),
  CHECK(l <= LEAST(o,c) AND h >= GREATEST(o,c) AND l <= h)
);
CREATE INDEX IF NOT EXISTS ix_tradeyar_history_event_at ON tradeyar_research.history_bars(event_at DESC);
-- Preserve revised readings rather than silently overwriting originally observed market data.
CREATE TABLE IF NOT EXISTS tradeyar_research.history_bar_revisions (
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  event_at TIMESTAMPTZ NOT NULL,
  import_sha256 CHAR(64) NOT NULL REFERENCES tradeyar_research.history_imports(import_sha256),
  o NUMERIC(22,10) NOT NULL,
  h NUMERIC(22,10) NOT NULL,
  l NUMERIC(22,10) NOT NULL,
  c NUMERIC(22,10) NOT NULL,
  volume BIGINT NOT NULL,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (symbol,timeframe,event_at,import_sha256)
);
CREATE TABLE IF NOT EXISTS tradeyar_research.history_collection_periods (
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  period_month DATE NOT NULL,
  window_start_utc TIMESTAMPTZ NOT NULL,
  window_end_utc TIMESTAMPTZ NOT NULL,
  status VARCHAR(24) NOT NULL CHECK(status IN ('IMPORTED','MISSING','PARTIAL','CACHED','ERROR')),
  source VARCHAR(120) NOT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  latest_import_sha256 CHAR(64),
  checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(symbol,timeframe,period_month)
);
CREATE TABLE IF NOT EXISTS tradeyar_research.calibration_runs_v06 (
  run_id UUID PRIMARY KEY,
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  style VARCHAR(30) NOT NULL,
  source VARCHAR(120) NOT NULL,
  dataset_sha256 CHAR(64) NOT NULL,
  processed_bars INTEGER NOT NULL CHECK(processed_bars >= 0),
  covered_years NUMERIC(12,5),
  independent_validation BOOLEAN NOT NULL DEFAULT FALSE,
  ten_year_training_complete BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL,
  report_json JSONB NOT NULL,
  archived_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS tradeyar_research.calibration_strategy_results_v06 (
  run_id UUID NOT NULL REFERENCES tradeyar_research.calibration_runs_v06(run_id),
  strategy_id VARCHAR(64) NOT NULL,
  selected_preset VARCHAR(64),
  training_metrics JSONB NOT NULL,
  validation_metrics JSONB NOT NULL,
  heldout_metrics JSONB NOT NULL,
  PRIMARY KEY(run_id,strategy_id)
);
CREATE TABLE IF NOT EXISTS tradeyar_research.data_sync_runs_v06 (
  sync_id UUID PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  source_type VARCHAR(40) NOT NULL,
  files_checked INTEGER NOT NULL DEFAULT 0,
  rows_inserted BIGINT NOT NULL DEFAULT 0,
  discrepancies BIGINT NOT NULL DEFAULT 0,
  note TEXT
);
-- Append-only historical datasets; UPDATE and DELETE require an explicit DBA maintenance procedure.
-- All calculated research-only strategy votes associated with a closed bar.
CREATE TABLE IF NOT EXISTS tradeyar_research.analysis_snapshots_v06 (
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  style VARCHAR(30) NOT NULL,
  event_at TIMESTAMPTZ NOT NULL,
  engine_version VARCHAR(40) NOT NULL,
  source VARCHAR(120) NOT NULL,
  decision VARCHAR(80) NOT NULL,
  payload JSONB NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(symbol,timeframe,style,event_at,engine_version)
);
CREATE TABLE IF NOT EXISTS tradeyar_research.analysis_strategy_signals_v06 (
  symbol VARCHAR(20) NOT NULL,
  timeframe VARCHAR(8) NOT NULL,
  style VARCHAR(30) NOT NULL,
  event_at TIMESTAMPTZ NOT NULL,
  engine_version VARCHAR(40) NOT NULL,
  strategy_id VARCHAR(64) NOT NULL,
  signal VARCHAR(20) NOT NULL,
  independently_validated BOOLEAN NOT NULL DEFAULT FALSE,
  reason TEXT NOT NULL,
  PRIMARY KEY(symbol,timeframe,style,event_at,engine_version,strategy_id),
  FOREIGN KEY(symbol,timeframe,style,event_at,engine_version)
    REFERENCES tradeyar_research.analysis_snapshots_v06(symbol,timeframe,style,event_at,engine_version)
);
