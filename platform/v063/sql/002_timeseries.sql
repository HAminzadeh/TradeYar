-- Execute only in the dedicated Timescale/PostgreSQL database (TRADEYAR_TS_DSN).
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE SCHEMA IF NOT EXISTS tradeyar_market;
CREATE TABLE IF NOT EXISTS tradeyar_market.market_bars (
  provider TEXT NOT NULL, symbol TEXT NOT NULL, timeframe TEXT NOT NULL,
  open_time TIMESTAMPTZ NOT NULL, close_time TIMESTAMPTZ NOT NULL,
  available_at TIMESTAMPTZ NOT NULL,
  open_price DOUBLE PRECISION NOT NULL CHECK (open_price > 0),
  high_price DOUBLE PRECISION NOT NULL CHECK (high_price > 0),
  low_price DOUBLE PRECISION NOT NULL CHECK (low_price > 0),
  close_price DOUBLE PRECISION NOT NULL CHECK (close_price > 0),
  tick_volume BIGINT NOT NULL DEFAULT 0 CHECK (tick_volume >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  value_hash CHAR(64) NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(provider, symbol, timeframe, open_time),
  CHECK (low_price <= LEAST(open_price,close_price) AND high_price >= GREATEST(open_price,close_price)),
  CHECK (close_time > open_time), CHECK(available_at >= close_time)
);
SELECT create_hypertable('tradeyar_market.market_bars','open_time',if_not_exists=>TRUE, migrate_data=>TRUE);
CREATE INDEX IF NOT EXISTS bar_symbol_frame_desc ON tradeyar_market.market_bars(symbol,timeframe,open_time DESC);
CREATE TABLE IF NOT EXISTS tradeyar_market.market_bar_versions (
  provider TEXT NOT NULL, symbol TEXT NOT NULL, timeframe TEXT NOT NULL,
  open_time TIMESTAMPTZ NOT NULL, revision INTEGER NOT NULL,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  row_values JSONB NOT NULL, value_hash CHAR(64) NOT NULL,
  PRIMARY KEY(provider,symbol,timeframe,open_time,revision)
);
SELECT create_hypertable('tradeyar_market.market_bar_versions','open_time',if_not_exists=>TRUE, migrate_data=>TRUE);
CREATE TABLE IF NOT EXISTS tradeyar_market.market_ticks (
  provider TEXT NOT NULL, symbol TEXT NOT NULL, tick_time TIMESTAMPTZ NOT NULL,
  tick_id TEXT NOT NULL, bid DOUBLE PRECISION NOT NULL,
  ask DOUBLE PRECISION NOT NULL, volume DOUBLE PRECISION,
  available_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(provider,symbol,tick_time,tick_id),
  CHECK (bid > 0 AND ask >= bid), CHECK(available_at >= tick_time)
);
SELECT create_hypertable('tradeyar_market.market_ticks','tick_time',if_not_exists=>TRUE, migrate_data=>TRUE);
CREATE INDEX IF NOT EXISTS tick_symbol_desc ON tradeyar_market.market_ticks(symbol,tick_time DESC);
