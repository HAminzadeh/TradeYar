# Smoke test portability (PowerShell 5.1)

`Invoke-RestMethod` may emit a top-level JSON array as a single pipeline object in Windows PowerShell 5.1. Do not check module count with `@(Invoke-RestMethod ...).Count`: that can incorrectly be `1` even if the API returned 20 objects.

The source-controlled `scripts/Smoke-Test-TradeYar.ps1` now reads `/api/modules` using `Invoke-WebRequest`, parses JSON explicitly and enumerates the module records. It requires unique module IDs M01-M20, checks the synthetic 100-candle response, and asserts the real-order endpoint returns 423 LOCKED.

## Run

Start the Backend in a separate terminal and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Smoke-Test-TradeYar.ps1
```

If a test fails, investigate the API response rather than changing application code to satisfy a false count. Commit this smoke test to Git so the fix also applies on another computer.