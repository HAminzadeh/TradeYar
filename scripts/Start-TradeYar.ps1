[CmdletBinding()]
param([switch]$DemoOnly, [switch]$StrictOfflineApplication)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot


# TRADEYAR-PHASE2-AUTOSTART-BEGIN
# Avoid older download-capable auto-repair while this launcher is active.
$env:TRADEYAR_AUTO_REPAIR_ON_STARTUP = 'false'
if (-not $DemoOnly) {
    $ResearchStartup = Join-Path $Root 'scripts\Start-TradeYar-ResearchServices.ps1'
    if (-not (Test-Path -LiteralPath $ResearchStartup -PathType Leaf)) { throw 'TradeYar research startup script missing' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ResearchStartup -ProjectPath $Root -Mode Start
    if ($LASTEXITCODE -ne 0) { throw 'TradeYar offline research startup failed. Application processes were not launched. Use -DemoOnly to skip research services.' }
}
# Optional STRICT offline application launch (does not use the older online-capable Maven runner).
# This mode only works when project-local Java/Maven dependencies and frontend modules
# are already usable offline. The separate specialist Docker depot never copies these.
if ($StrictOfflineApplication) {
    $OfflineApp = Join-Path $Root 'scripts\Start-TradeYar-Offline.ps1'
    if (-not (Test-Path -LiteralPath $OfflineApp -PathType Leaf)) { throw 'Strict offline app launcher missing' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $OfflineApp -ProjectPath $Root -Mode Start -NoServices -StartFrontend
    if ($LASTEXITCODE -ne 0) { throw 'Strict offline application startup failed. No online fallback.' }
    return
}
# TRADEYAR-PHASE2-AUTOSTART-END
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