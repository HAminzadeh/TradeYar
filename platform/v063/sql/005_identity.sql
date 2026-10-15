-- TradeYar auth (v0.6.4 proposal). Run explicitly on an operator-owned PostgreSQL
-- database before enabling TRADEYAR_AUTH_ENABLED. Never execute against SakhtYar.
BEGIN;
CREATE SCHEMA IF NOT EXISTS tradeyar_auth;
CREATE TABLE IF NOT EXISTS tradeyar_auth.users (
  id UUID PRIMARY KEY,
  username VARCHAR(60) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  email VARCHAR(255),
  password_hash VARCHAR(220) NOT NULL,
  role VARCHAR(32) NOT NULL CHECK (role IN ('ADMIN','RESEARCH_MANAGER','ANALYST','VIEWER')),
  status VARCHAR(16) NOT NULL CHECK (status IN ('PENDING','ACTIVE','SUSPENDED')),
  failed_attempts INTEGER NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  locked_until TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_tradeyar_auth_username ON tradeyar_auth.users (lower(username));
CREATE UNIQUE INDEX IF NOT EXISTS uq_tradeyar_auth_email ON tradeyar_auth.users (lower(email)) WHERE email IS NOT NULL;
CREATE TABLE IF NOT EXISTS tradeyar_auth.sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES tradeyar_auth.users(id) ON DELETE CASCADE,
  csrf_token VARCHAR(100) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tradeyar_auth_sessions_user ON tradeyar_auth.sessions(user_id);
CREATE TABLE IF NOT EXISTS tradeyar_auth.audit (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID,
  action VARCHAR(80) NOT NULL,
  description VARCHAR(300) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMIT;
