"""Transaction-safe PostgreSQL helpers; no cross-database XA illusion."""
from __future__ import annotations
from contextlib import contextmanager
from .core import Settings, ConfigurationError

@contextmanager
def connect(kind='timeseries'):
    settings=Settings.from_env()
    dsn=settings.timeseries_dsn if kind=='timeseries' else settings.metadata_dsn
    if not dsn:
        raise ConfigurationError('Missing '+('TRADEYAR_TS_DSN' if kind=='timeseries' else 'TRADEYAR_PG_DSN'))
    try:
        import psycopg
    except ImportError as exc:
        raise ConfigurationError('Install platform/requirements.txt') from exc
    with psycopg.connect(dsn, connect_timeout=10) as conn:
        yield conn


def migrate_file(path, kind='timeseries'):
    from pathlib import Path
    sql=Path(path).read_text(encoding='utf-8')
    with connect(kind) as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
    return True
