-- Read-only v0.6.2 archive projections, source/version-aware. Apply to Timescale DB.
CREATE SCHEMA IF NOT EXISTS tradeyar_market;
CREATE TABLE IF NOT EXISTS tradeyar_market.market_bar_observations (
 provider TEXT NOT NULL, symbol TEXT NOT NULL,timeframe TEXT NOT NULL,
 open_time TIMESTAMPTZ NOT NULL, content_hash CHAR(64) NOT NULL,
 source_archive_sha256 CHAR(64) NOT NULL,
 observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 row_values JSONB NOT NULL,
 PRIMARY KEY(provider,symbol,timeframe,open_time,content_hash)
);
SELECT create_hypertable('tradeyar_market.market_bar_observations','open_time',if_not_exists=>TRUE,migrate_data=>TRUE);
