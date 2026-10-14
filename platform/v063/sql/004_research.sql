-- Metadata DB; additive and separate from existing tradeyar_research v0.5 tables.
BEGIN;
CREATE SCHEMA IF NOT EXISTS tradeyar_platform_research;
CREATE TABLE IF NOT EXISTS tradeyar_platform_research.backtest_runs (
    run_id UUID PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    symbol TEXT NOT NULL, timeframe TEXT NOT NULL,
    dataset_hash CHAR(64) NOT NULL, strategy TEXT NOT NULL,
    strategy_params JSONB NOT NULL, cost_assumptions JSONB NOT NULL,
    result_metrics JSONB NOT NULL, trade_ledger JSONB NOT NULL,
    validated BOOLEAN NOT NULL DEFAULT FALSE,
    broker_executable BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_backtest_lookup ON tradeyar_platform_research.backtest_runs(symbol,timeframe,created_at DESC);
CREATE TABLE IF NOT EXISTS tradeyar_platform_research.walkforward_runs (
    run_id UUID PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dataset_hash CHAR(64) NOT NULL, study_config JSONB NOT NULL,
    folds JSONB NOT NULL, summary JSONB NOT NULL,
    independently_validated BOOLEAN NOT NULL DEFAULT FALSE
);
COMMIT;
