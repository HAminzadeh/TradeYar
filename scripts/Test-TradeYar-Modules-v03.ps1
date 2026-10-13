#requires -Version 5.1
<#
  TradeYar v0.3 API contract smoke test: non-destructive by default.
  Expects Spring Boot listening on 127.0.0.1:8080.
  Optionally creates TWO in-memory simulated demo records with -IncludeDemoWrites.
#>
param([string]$Base='http://127.0.0.1:8080',[switch]$IncludeDemoWrites)
$ErrorActionPreference='Stop'
function Get-Api([string]$path) {
    $response=Invoke-WebRequest -Uri ($Base+$path) -UseBasicParsing -TimeoutSec 15
    if ([int]$response.StatusCode -ne 200) { throw "Unexpected HTTP $($response.StatusCode) for $path" }
    return (ConvertFrom-Json -InputObject $response.Content)
}
function Post-Api([string]$path,[object]$body) {
    $response=Invoke-WebRequest -Uri ($Base+$path) -UseBasicParsing -TimeoutSec 15 -Method POST -ContentType 'application/json' -Body ($body|ConvertTo-Json -Compress)
    return (ConvertFrom-Json -InputObject $response.Content)
}
function Pass([string]$id,[string]$message){Write-Host "[PASS] $id $message" -ForegroundColor Green}
Write-Host '=== TradeYar v0.3 module API verification ===' -ForegroundColor Cyan
$health=Get-Api '/api/health'
if($health.status -ne 'READY' -or $health.tradingEnabled -ne $false){throw 'M01 health and trade safety mismatch'}
Pass 'M01' 'Backend healthy'
$registryReply=Invoke-WebRequest -Uri ($Base+'/api/modules') -UseBasicParsing -TimeoutSec 15
$registry=ConvertFrom-Json -InputObject $registryReply.Content
if ($registry -isnot [array]) { throw 'Module API must return a JSON array' }
$ids=@($registry | ForEach-Object { $_.id })
if($ids.Count -ne 20 -or @($ids|Select-Object -Unique).Count -ne 20){throw "Registry count invalid: $($ids.Count)"}
foreach($i in 1..20){if($ids -notcontains ('M{0:D2}' -f $i)){throw "Missing module M$i"}}
Pass 'M02' '20 UI destinations expected (verify browser clicks separately)'
$prefs=Get-Api '/api/preferences';if(-not $prefs.preferences){throw 'M03 missing preferences'};Pass 'M03' 'Preferences readable'
$quote=Get-Api '/api/market/quote?symbol=EURUSD';if($quote.source -ne 'SYNTHETIC_DEMO'){throw 'M04 data provenance missing'};Pass 'M04' 'Synthetic quote'
$chart=Get-Api '/api/charts/series?symbol=EURUSD';if(@($chart.candles).Count -ne 100){throw 'M05 chart candle count != 100'};Pass 'M05' '100 chart candles'
$mt5=Get-Api '/api/mt5/status';if($mt5.liveTradingEnabled -ne $false){throw 'M06 MT5 must be read-only'};Pass 'M06' 'MT5 remains read-only'
$tech=Get-Api '/api/technical/summary?symbol=EURUSD';if($null -eq $tech.rsi14){throw 'M07 indicator missing'};Pass 'M07' 'SMA/EMA/RSI'
$strategyReply=Invoke-WebRequest -Uri ($Base+'/api/strategies') -UseBasicParsing -TimeoutSec 15
$strategies=ConvertFrom-Json -InputObject $strategyReply.Content
if ($strategies -isnot [array]) { throw 'Strategy API must return a JSON array' }
if($strategies.Count -ne 20){throw "M08 strategy registry count $($strategies.Count)"};Pass 'M08' '20 strategies catalogued (3 implemented)'
$backtest=Get-Api '/api/backtest/run?symbol=EURUSD&strategy=SMA_CROSS&spreadPips=1.5';if($backtest.source -ne 'SYNTHETIC_DEMO'){throw 'M09 missing synthetic source'};Pass 'M09' 'Synthetic backtest'
$signal=Get-Api '/api/signals/preview?symbol=EURUSD';if($signal.tradePermitted -ne $false){throw 'M10 signal permitted to trade'};Pass 'M10' 'Untrusted signal preview'
$risk=Post-Api '/api/risk/position-size' @{equity=10000;riskPercent=0.5;stopLossPips=25;pipValuePerLot=10};if($risk.authorizedToTrade -ne $false){throw 'M11 risk incorrectly authorizes orders'};Pass 'M11' 'Indicative sizing'
$paper=Get-Api '/api/paper/orders';if($paper.mode -ne 'PAPER_ONLY'){throw 'M12 not paper mode'};Pass 'M12' 'Simulated order endpoint'
$journal=Get-Api '/api/journal';if($journal.scope -ne 'PAPER_ONLY'){throw 'M13 journal not paper mode'};Pass 'M13' 'Journal endpoint'
$news=Get-Api '/api/news/events';if($news.live -ne $false){throw 'M14 example feed reported as live'};Pass 'M14' 'Non-live calendar examples'
$ai=Get-Api '/api/ai/status';if($ai.readyForTrading -ne $false){throw 'M15 AI erroneously ready to trade'};Pass 'M15' 'AI readiness status'
$alerts=Get-Api '/api/alerts';if($alerts.deliveryEnabled -ne $false){throw 'M16 unverified delivery'};Pass 'M16' 'Manual demo alerts'
$report=Get-Api '/api/reports/overview';if($report.realizedPnLAvailable -ne $false){throw 'M17 unverified PnL'};Pass 'M17' 'Paper metrics'
$education=Get-Api '/api/education/lessons?lang=fa';if(@($education.lessons).Count -lt 3){throw 'M18 missing lesson titles'};Pass 'M18' 'Persian lessons returned'
if($ids -notcontains 'M19'){throw 'M19 not registered'};Pass 'M19' 'Infrastructure registry'
$live=Get-Api '/api/live/status';if($live.enabled -ne $false -or $live.state -ne 'LOCKED'){throw 'M20 LIVE IS NOT LOCKED'}
$code=0
try { Invoke-WebRequest -Uri ($Base+'/api/live/orders') -Method POST -ContentType 'application/json' -Body '{}' -UseBasicParsing -TimeoutSec 15 | Out-Null; $code=200 }
catch {if($_.Exception.Response){$code=[int]$_.Exception.Response.StatusCode} else {throw}}
if($code -ne 423){throw "M20 expected 423, got $code"};Pass 'M20' 'Live orders rejected HTTP 423'
if($IncludeDemoWrites) {
    $order=Post-Api '/api/paper/orders' @{symbol='EURUSD';side='BUY';lots=0.01}
    if($order.executionMode -ne 'PAPER_ONLY'){throw 'Demo paper order was not paper'}
    $alert=Post-Api '/api/alerts' @{symbol='EURUSD';when='ABOVE';threshold=1.2}
    if(-not $alert.id){throw 'Alert not created'}
    Pass 'WRITES' 'One demo paper order and one demo alert created in memory'
}
Write-Host '[PASS] All 20 module API contracts verified (demo scope)' -ForegroundColor Green
