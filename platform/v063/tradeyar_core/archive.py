"""Parquet archive for user-authorized CSV with atomic manifest and SHA-256."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import os
from .ingest import file_hash
from .core import utcnow


def archive_csv(source, destination) -> dict:
    try:
        import duckdb
    except ImportError as exc:
        raise RuntimeError('Install optional duckdb: python -m pip install duckdb') from exc
    source=Path(source).expanduser().resolve()
    target=Path(destination).expanduser().resolve()
    if source.suffix.lower()!='.csv' or target.suffix.lower()!='.parquet':
        raise ValueError('Require .csv input and .parquet output')
    if not source.is_file() or target.exists():
        raise ValueError('Source missing or destination already exists')
    target.parent.mkdir(parents=True,exist_ok=True)
    tmp=target.with_name(target.stem+'.partial.parquet')
    if tmp.exists():
        raise ValueError('Temporary destination exists')
    # The source path is bound, while the safe destination is escaped as a SQL literal.
    with duckdb.connect(':memory:') as db:
        escaped=str(tmp).replace("'","''")
        db.execute(f"COPY (SELECT * FROM read_csv_auto(?)) TO '{escaped}' (FORMAT PARQUET, COMPRESSION ZSTD)",[str(source)])
    os.replace(tmp,target)
    manifest={'source':str(source),'source_sha256':file_hash(source),
              'archive':str(target),'archive_sha256':file_hash(target),
              'archived_at_utc':utcnow(), 'format':'PARQUET','compression':'ZSTD'}
    mpath=target.with_suffix('.manifest.json')
    # Do not rewrite existing manifests.
    with mpath.open('x',encoding='utf-8') as f:
        json.dump(manifest,f,indent=2)
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--file',required=True);parser.add_argument('--out',required=True)
    a=parser.parse_args()
    print(json.dumps(archive_csv(a.file,a.out),indent=2))
