#requires -Version 5.1
# TradeYar API smoke tests - JSON_MODULES_V2
# Run after starting the backend. Tests NEVER submit broker orders.
[CmdletBinding()]
param([string]$BaseUrl = 'http://127.0.0.1:8080')
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

$health = Invoke-RestMethod -Uri "$BaseUrl/api/health" -TimeoutSec 15
if ($health.status -ne 'READY' -or $health.tradingEnabled -ne $false) {
    throw 'Backend is not READY, or live trading is not disabled.'
}
Write-Host '[PASS] Backend health and live trading flag' -ForegroundColor Green

# IMPORTANT: Windows PowerShell 5.1 may wrap Invoke-RestMethod JSON arrays as one
# pipeline object. @(Invoke-RestMethod ...) can report Count=1 for 20 rows.
# Read the raw response, parse JSON, and explicitly enumerate the returned rows.
$response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/modules" -TimeoutSec 15
$decoded = ConvertFrom-Json -InputObject $response.Content
if ($null -eq $decoded) { throw 'Module API returned JSON null.' }
if ($decoded -is [System.Array]) {
    $moduleRows = @($decoded | ForEach-Object { $_ })
} elseif ($null -ne $decoded.PSObject.Properties['modules']) {
    $moduleRows = @($decoded.modules | ForEach-Object { $_ })
} else {
    throw "Unexpected /api/modules JSON shape. Expected an array; response: $($response.Content.Substring(0,[Math]::Min(250,$response.Content.Length)))"
}
$moduleCount = $moduleRows.Count
if ($moduleCount -ne 20) {
    throw "Expected 20 module objects, found $moduleCount. Response: $($response.Content.Substring(0,[Math]::Min(500,$response.Content.Length)))"
}
$ids = @($moduleRows | ForEach-Object { $_.id })
$expectedIds = @(1..20 | ForEach-Object { 'M{0:D2}' -f $_ })
$uniqueIds = @($ids | Sort-Object -Unique)
if ($uniqueIds.Count -ne 20 -or @($expectedIds | Where-Object { $ids -cnotcontains $_ }).Count -ne 0) {
    throw "Expected unique IDs M01..M20; received: $($ids -join ', ')"
}
$liveModule = @($moduleRows | Where-Object { $_.id -eq 'M20' })
if ($liveModule.Count -ne 1 -or $liveModule[0].status -ne 'LOCKED') {
    throw 'M20 live execution module must have LOCKED status.'
}
Write-Host '[PASS] 20 unique modules M01..M20 registered; M20 LOCKED' -ForegroundColor Green

$market = Invoke-RestMethod -Uri "$BaseUrl/api/market/candles?symbol=EURUSD&limit=100" -TimeoutSec 15
$bars = @($market.candles | ForEach-Object { $_ })
if ($market.source -ne 'SYNTHETIC_DEMO' -or $bars.Count -ne 100) {
    throw "Candle API mismatch: source=$($market.source); count=$($bars.Count)"
}
Write-Host '[PASS] Synthetic EURUSD candles: 100' -ForegroundColor Green

$live = Invoke-RestMethod -Uri "$BaseUrl/api/live/status" -TimeoutSec 15
if ($live.enabled -ne $false -or $live.state -ne 'LOCKED') {
    throw 'SECURITY FAILURE: live execution status is not locked.'
}
Write-Host '[PASS] Live execution status is LOCKED' -ForegroundColor Green

$statusCode = 0
try {
    $result = Invoke-WebRequest -UseBasicParsing -Method Post `
        -Uri "$BaseUrl/api/live/orders" -ContentType 'application/json' `
        -Body '{}' -TimeoutSec 15
    $statusCode = [int]$result.StatusCode
} catch {
    if ($null -ne $_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    } else {
        throw "Cannot determine POST /api/live/orders HTTP status: $($_.Exception.Message)"
    }
}
if ($statusCode -ne 423) {
    throw "SECURITY FAILURE: expected HTTP 423 from /api/live/orders; got $statusCode"
}
Write-Host '[PASS] Real-money order submission rejected (HTTP 423)' -ForegroundColor Green
Write-Host '[PASS] All TradeYar API smoke tests passed.' -ForegroundColor Green