$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

$Backend = Join-Path $Root "backend"
$Frontend = Join-Path $Root "frontend"
$Python = Join-Path $Root "python/ai-service"

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$Backend'; powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$Root\scripts\Invoke-TradeYar-Maven.ps1' -Goal Start"
)

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$Frontend'; npm run dev"
)

$PythonExe = Join-Path $Python ".venv/Scripts/python.exe"

if (Test-Path $PythonExe) {
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "cd '$Python'; & '.\.venv\Scripts\python.exe' -m uvicorn app.main:app --port 8001"
    )
}

Write-Host "TradeYar services launched" -ForegroundColor Green
Write-Host "Dashboard: http://localhost:5173"