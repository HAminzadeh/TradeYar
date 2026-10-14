# TradeYar v0.6.1 — Windows archive + DataSync regression repair

## What failed
- Java tests: 30 passed; frontend `tsc`/Vite: passed.
- Python archive test incorrectly compared an unnormalized Windows short temporary directory with a normalized monthly CSV parent directory. The resulting `Missing or escaping shard` was a **false negative**; it did not prove file corruption.
- `Invoke-TradeYar-DataSync.ps1` evaluated `$PSScriptRoot` inside its `param` default, where Windows PowerShell 5.1 may have it unset.
- The v0.6 installer cleanup (`Remove-Item -Recurse` with an 8.3 TMP alias) threw and obscured the original test failure.

## What is fixed
- Canonicalize the verified archive root before checking that monthly files reside under it; keep strict checksum/CSV validation, no relaxed directory traversal.
- Add a regression test for short/symlinked parent paths and retain tests for cached months, revisions and SHA mismatch.
- Resolve PowerShell script and project locations **after** parameter binding. An explicit `-ProjectPath` remains supported.
- Select archive and research defaults only after entering the script, with local env overrides; no credentials or stored data are changed.
- Handle installer staging cleanup as best effort; never replace a real test exception with cleanup errors.

## Safe first run (no database required)
```powershell
cd D:\ChatGPT_Projects\TradeYar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-DataSync.ps1 -VerifyOnly
```

## PostgreSQL sync (requires configuration)
1. Provision PostgreSQL and apply the SQL file `infrastructure/db/v06_history.sql` to an approved local database.
2. Set `TRADEYAR_PG_DSN` in the *local* process environment (never in Git). Install `psycopg` in the approved Python environment.
3. Receive/collect actual history with the read-only MT5 bridge to create monthly archived files, or use already existing archives.
4. Run `scripts/Invoke-TradeYar-DataSync.ps1` without `-VerifyOnly` to insert new data. A run over an empty archive does not imply any data was imported.

All existing archives remain untouched by the patch; research/trading safety remains unchanged. Live orders are still HTTP 423 LOCKED.
