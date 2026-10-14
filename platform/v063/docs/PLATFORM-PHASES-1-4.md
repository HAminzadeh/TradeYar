# TradeYar v0.6.3 — phased add-on to v0.6.2

## Source baseline
GitHub `HAminzadeh/TradeYar`, `master`, observed commit `3722b9b1b7fa8b195e9bb2fb4bbd5193c9e808d4` (October 14, 2026). This package was designed against that tree and maintains existing v0.6.2 modules. It is **not** a claim of independently validated forex trading or a full production platform.

## Parts
1. **Part1**: local authenticated research API, immutable audit-domain DTOs, PostgreSQL research core migration. Explicit secrets required for write operations.
2. **Part2**: opt-in isolated TimescaleDB, Neo4j, ClickHouse, MinIO; hypertable and graph schema; no automatic deletion/migration of existing PostgreSQL 16 on 5433.
3. **Part3**: retains v0.6.2 monthly archive collector and Postgres sync. Adds an additive SHA-verified Timescale projection for M1..H4; treats historical revisions as alternate observations, does not overwrite canonical values. No surprise broker login or download.
4. **Part4**: Python SMA walk-forward research and new Java v0.6.2 *20-strategy* historical replay, controlled loopback POST endpoint. 60/20/20 chronological segment labels; constant spread/slippage and fixed-horizon next-open fills. NO trained model, independent out-of-sample profit certification, real order routing, or verified tick execution.

## Upgrade rules
All installed files live in versioned `platform/v063`, `infrastructure/v063`, plus brand-new v063 Java classes and `scripts/TradeYar-v063-SyncTimescale.py`. Original v0.6.2 files are not overwritten. Install refuses conflicts, records SHA-256, and makes backups only with explicit `-AllowOverwrite`. Installation is not the same as starting Docker, importing data, or validating real trading.

## Phase 2 Activation
Copy `infrastructure/v063/.env.example` to `infrastructure/v063/.env`, set strong secrets, then use `-Part Part2 -StartServices` (must have Docker, Docker Compose and adequate memory). Existing v0.6.2 PostgreSQL on port 5433 stays independent from Timescale on port 5434. You must set `TRADEYAR_TS_DSN` and `TRADEYAR_PG_DSN` *locally* and `psql` installed before `-ApplyDatabase`; the platform does not auto-copy 0.6.2 data. Neo4j and ClickHouse schemas require separate application following their engines' tools; ClickHouse is not automatically populated. All remote service ingress binds to 127.0.0.1.

## Phase 3 Sync
1. Use existing `scripts/collect_mt5_history_v06.py` in read-only mode on a logged-in terminal, or reuse existing verified archive. For PostgreSQL v0.6.2, continue using `scripts/Invoke-TradeYar-DataSync.ps1`.
2. `py -3 scripts/TradeYar-v063-SyncTimescale.py --project D:\ChatGPT_Projects\TradeYar --folder "$env:LOCALAPPDATA\TradeYar\history\EURUSD\H1" --verify-only`
3. After Timescale migrations and local secret `TRADEYAR_TS_DSN`, omit `--verify-only` to synchronize the verified archive. Does not automatically read from remote brokers, does not silently rewrite conflicting OHLC.

## Phase 4 opt-in replay
Set `TRADEYAR_ENABLE_LOCAL_RESEARCH=true` and a random local `TRADEYAR_V063_RESEARCH_TOKEN` with at least 24 characters in Spring's run environment, and ensure existing archived monthly files and manifests are present. Restart Spring, then POST localhost `/api/v063/research/replay` with a matching `X-TradeYar-Research-Token` header and body e.g. `{"symbol":"EURUSD","timeframe":"H1","maxBars":1200,"spreadPips":1.5,"slippagePips":0.2,"holdingBars":3}`. Both loopback request and secret are mandatory. The endpoint returns 60 segment summaries for the 20 v0.6 research rules. `tradeAuthorized=false` throughout. Use per-instrument pip size and cost assumptions; these fixed values are only illustrative and no broker fill validation is performed.

## Tests and limitations
`-RunTests` runs Python unittest for staged components and backend JUnit/Maven tests after Part4. Additional live integration tests are required for Docker/Timescale/Neo4j/ClickHouse/MinIO and broker data. The Java replay caps input to 3000 closed bars at the endpoint (engine max 6000); this is not a complete decade-wide replay. Time-aligned macro release feeds, full broker tick/slippage simulation, Kafka/Debezium running infrastructure, OAuth/OIDC and production disaster-recovery are architectural follow-ups. All live trading endpoints remain disabled (HTTP 423). No live performance guarantees.
