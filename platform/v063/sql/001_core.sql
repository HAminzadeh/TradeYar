BEGIN;
CREATE SCHEMA IF NOT EXISTS tradeyar_core;
CREATE TABLE IF NOT EXISTS tradeyar_core.data_sources (
  source_id TEXT PRIMARY KEY, provider TEXT NOT NULL, dataset_kind TEXT NOT NULL,
  permission_status TEXT NOT NULL DEFAULT 'UNVERIFIED' CHECK (permission_status IN ('UNVERIFIED','ALLOWED','RESTRICTED','EXPIRED')),
  permission_evidence TEXT, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS tradeyar_core.ingestion_runs (
  run_id UUID PRIMARY KEY, source_id TEXT NOT NULL, dataset_hash CHAR(64) NOT NULL,
  started_at TIMESTAMPTZ NOT NULL, finished_at TIMESTAMPTZ,
  status TEXT NOT NULL, inserted_count BIGINT NOT NULL DEFAULT 0,
  corrected_count BIGINT NOT NULL DEFAULT 0, duplicate_count BIGINT NOT NULL DEFAULT 0,
  rejected_count BIGINT NOT NULL DEFAULT 0, error_message TEXT,
  CONSTRAINT fk_data_source FOREIGN KEY(source_id) REFERENCES tradeyar_core.data_sources(source_id)
);
CREATE INDEX IF NOT EXISTS ingestion_source_time_idx ON tradeyar_core.ingestion_runs(source_id,started_at DESC);
CREATE TABLE IF NOT EXISTS tradeyar_core.audit_events (
  event_id UUID PRIMARY KEY, event_type TEXT NOT NULL, event_time TIMESTAMPTZ NOT NULL,
  content_hash CHAR(64) NOT NULL, details JSONB NOT NULL, source_system TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tradeyar_core.outbox_events (
  event_id UUID PRIMARY KEY, aggregate_type TEXT NOT NULL, aggregate_id TEXT NOT NULL,
  payload JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at TIMESTAMPTZ, attempts INT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS outbox_unpublished_idx ON tradeyar_core.outbox_events(created_at) WHERE published_at IS NULL;
COMMIT;
