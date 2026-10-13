-- TradeYar v0.5 research-only PostgreSQL schema. Execute manually against approved local DB.
-- All timestamps UTC, experiment history immutable. No account passwords, trading credentials or tokens.
CREATE SCHEMA IF NOT EXISTS tradeyar_research;
CREATE TABLE IF NOT EXISTS tradeyar_research.dataset_snapshots (
 dataset_sha256 CHAR(64) PRIMARY KEY,
 symbol VARCHAR(20) NOT NULL, timeframe VARCHAR(8) NOT NULL,
 provider VARCHAR(120) NOT NULL, first_bar TIMESTAMPTZ, last_bar TIMESTAMPTZ,
 candle_count INT NOT NULL CHECK(candle_count>=0),
 verified BOOLEAN NOT NULL DEFAULT FALSE,
 collected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS tradeyar_research.strategy_versions (
 strategy_id VARCHAR(64) NOT NULL, strategy_version VARCHAR(40) NOT NULL,
 source_hash CHAR(64), validation_status VARCHAR(48) NOT NULL DEFAULT 'NOT_VALIDATED',
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(strategy_id,strategy_version)
);
CREATE TABLE IF NOT EXISTS tradeyar_research.research_runs (
 run_id UUID PRIMARY KEY, symbol VARCHAR(20) NOT NULL,
 timeframe VARCHAR(8) NOT NULL, strategy_id VARCHAR(64) NOT NULL,
 dataset_sha256 CHAR(64) NOT NULL, source VARCHAR(120) NOT NULL,
 total_bars INT NOT NULL CHECK(total_bars>=0),
 created_at TIMESTAMPTZ NOT NULL, training_metrics JSONB NOT NULL,
 held_out_metrics JSONB NOT NULL, warning TEXT NOT NULL,
 validated BOOLEAN NOT NULL DEFAULT FALSE,
 UNIQUE(run_id)
);
CREATE INDEX IF NOT EXISTS ix_tradeyar_research_lookup ON tradeyar_research.research_runs(symbol,timeframe,strategy_id,created_at DESC);
CREATE TABLE IF NOT EXISTS tradeyar_research.strategy_signals (
 signal_id UUID PRIMARY KEY, strategy_id VARCHAR(64) NOT NULL, symbol VARCHAR(20) NOT NULL,
 timeframe VARCHAR(8) NOT NULL, event_time TIMESTAMPTZ NOT NULL,
 direction VARCHAR(16) NOT NULL, dataset_sha256 CHAR(64),
 strategy_version VARCHAR(40) NOT NULL, context JSONB NOT NULL,
 independently_validated BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS tradeyar_research.training_jobs (
 job_id UUID PRIMARY KEY, strategy_id VARCHAR(64) NOT NULL, symbol VARCHAR(20) NOT NULL,
 timeframe VARCHAR(8) NOT NULL, state VARCHAR(40) NOT NULL,
 started_at TIMESTAMPTZ, finished_at TIMESTAMPTZ,
 metric_payload JSONB, model_hash CHAR(64), approved BOOLEAN NOT NULL DEFAULT FALSE
);
