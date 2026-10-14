-- Run in ClickHouse via clickhouse-client (or HTTP SQL interface). Derived analytical mirror only.
CREATE DATABASE IF NOT EXISTS tradeyar_analytics;
CREATE TABLE IF NOT EXISTS tradeyar_analytics.market_bars_analytics (
 provider String, symbol LowCardinality(String), timeframe LowCardinality(String),
 open_time DateTime64(3,'UTC'), open_price Float64, high_price Float64,
 low_price Float64, close_price Float64, volume UInt64, revision UInt32,
 source_hash FixedString(64)
) ENGINE=ReplacingMergeTree(revision)
PARTITION BY toYYYYMM(open_time)
ORDER BY (symbol,timeframe,provider,open_time);
