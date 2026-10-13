#requires -Version 5.1
param([string]$BaseUrl='http://127.0.0.1:8080')
$ErrorActionPreference='Stop'
function GetJson([string]$Path) {
  $response=Invoke-WebRequest -UseBasicParsing -Uri ($BaseUrl+$Path) -TimeoutSec 15
  if([int]$response.StatusCode -ne 200){throw "GET ${Path}: expected 200"}
  ConvertFrom-Json -InputObject $response.Content
}
$health=GetJson '/api/health'
if($health.status -ne 'READY' -or $health.tradingEnabled -ne $false){throw 'Backend unhealthy or live trading unsafe'}
Write-Host '[PASS] READY and no live trading' -ForegroundColor Green
$modules=GetJson '/api/modules'
if(@($modules).Count -ne 20){throw 'Legacy 20-module registry changed; v0.3 contracts may break'}
Write-Host '[PASS] Legacy 20 modules preserved' -ForegroundColor Green
$profile=GetJson '/api/v1/research/profiles'
if(@($profile.profiles).Count -ne 6){throw 'Expected six trading-style profiles'}
if($profile.executionEnabled -ne $false){throw 'Execution must be disabled'}
Write-Host '[PASS] Six research styles; no execution' -ForegroundColor Green
$votes=GetJson '/api/v1/research/consensus?symbol=EURUSD&style=INTRADAY'
if($votes.strategyCount -ne 20 -or $votes.evaluatedCount -ne 3 -or $votes.outcome -ne 'INSUFFICIENT_EVIDENCE'){throw 'Consensus unsafe or incorrect'}
Write-Host '[PASS] 20 catalog / 3 evaluated, no fabricated consensus' -ForegroundColor Green
$knowledge=GetJson '/api/v1/research/knowledge/overview?symbol=EURUSD&style=SWING'
if($knowledge.status -ne 'WAITING_FOR_DATA' -or $knowledge.verifiedCoverageYears -ne 0 -or $knowledge.validatedModel -ne $false){throw 'Research state must not falsely claim training'}
Write-Host '[PASS] M23 zero verified historical coverage / no validated model' -ForegroundColor Green
$status=0
try{Invoke-WebRequest -UseBasicParsing -Uri ($BaseUrl+'/api/live/orders') -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 15 | Out-Null;$status=200}
catch{if($_.Exception.Response){$status=[int]$_.Exception.Response.StatusCode}else{throw}}
if($status -ne 423){throw "Real order safety regression: expected 423, got $status"}
Write-Host '[PASS] Broker order attempts rejected HTTP 423' -ForegroundColor Green
Write-Host '[PASS] TradeYar v0.4 API smoke checks passed' -ForegroundColor Green
