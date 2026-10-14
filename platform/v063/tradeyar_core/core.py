"""Safe configuration, auditable records, and non-executing research boundary."""
from __future__ import annotations
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
import re
from typing import Any
from uuid import uuid4


class ConfigurationError(RuntimeError):
    pass


def utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def fingerprint(obj: Any) -> str:
    return hashlib.sha256(canonical_json(obj).encode('utf-8')).hexdigest()


@dataclass(frozen=True)
class Settings:
    metadata_dsn: str
    timeseries_dsn: str
    api_token: str
    host: str
    port: int
    environment: str

    @classmethod
    def from_env(cls) -> 'Settings':
        return cls(
            metadata_dsn=os.environ.get('TRADEYAR_PG_DSN', ''),
            timeseries_dsn=os.environ.get('TRADEYAR_TS_DSN', ''),
            api_token=os.environ.get('TRADEYAR_PLATFORM_API_TOKEN', ''),
            host=os.environ.get('TRADEYAR_PLATFORM_HOST', '127.0.0.1'),
            port=int(os.environ.get('TRADEYAR_PLATFORM_PORT', '8002')),
            environment=os.environ.get('TRADEYAR_PLATFORM_ENV', 'development'),
        )

    def safe_summary(self) -> dict:
        return {
            'metadata_dsn_configured': bool(self.metadata_dsn),
            'timeseries_dsn_configured': bool(self.timeseries_dsn),
            'api_token_configured': bool(self.api_token),
            'host': self.host, 'port': self.port, 'environment': self.environment,
            'live_execution_enabled': False,
        }

    def validate_http(self) -> None:
        if self.host not in ('127.0.0.1', 'localhost', '::1'):
            raise ConfigurationError('Only loopback binding is supported in the research platform')
        if not self.api_token or len(self.api_token) < 24:
            raise ConfigurationError('Set TRADEYAR_PLATFORM_API_TOKEN (at least 24 characters) for protected endpoints')


def authorized(provided_token: str | None, expected_token: str) -> bool:
    if not expected_token or not provided_token:
        return False
    return hmac.compare_digest(provided_token.encode('utf-8'), expected_token.encode('utf-8'))


def safe_symbol(value: str) -> str:
    symbol = value.strip().upper()
    if not re.fullmatch(r'[A-Z0-9._-]{3,24}', symbol):
        raise ValueError('Invalid market symbol')
    return symbol


@dataclass(frozen=True)
class AuditEvent:
    event_id: str
    event_type: str
    happened_at_utc: str
    payload_hash: str
    payload: dict
    trading_authorized: bool = False

    @classmethod
    def new(cls, event_type: str, payload: dict) -> 'AuditEvent':
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{2,63}', event_type):
            raise ValueError('Invalid event_type')
        return cls(str(uuid4()), event_type, utcnow(), fingerprint(payload), payload)

    def asdict(self) -> dict:
        return asdict(self)


def enforce_research_only() -> bool:
    """Never authorize, emit, or send real broker orders from this package."""
    return False
