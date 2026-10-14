#requires -Version 5.1
[CmdletBinding()]
param([string]$BaseUrl='http://127.0.0.1:8080')
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Label){if(-not $Value){throw "[FAIL] $Label"};Write-Host "[PASS] $Label" -ForegroundColor Green}
$Health=Invoke-RestMethod "$BaseUrl/api/health" -TimeoutSec 15
Assert ($Health.status -eq 'READY') 'Backend READY'
$Caps=Invoke-RestMethod "$BaseUrl/api/v06/capabilities" -TimeoutSec 15
Assert ($Caps.strategyDefinitions -eq 20 -and $Caps.independentlyValidatedStrategies -eq 0) '20 rules, 0 independent validations'
Assert ($Caps.realExecutionEnabled -eq $false -and $Caps.historicalTenYearTrainingComplete -eq $false) 'No false real/decade claims'
$S=Invoke-RestMethod "$BaseUrl/api/v06/snapshot?symbol=EURUSD&timeframe=M15&style=INTRADAY" -TimeoutSec 20
Assert ($S.strategies.Count -eq 20) '20 strategy results returned'
Assert (($S.counts.BUY+$S.counts.SELL+$S.counts.NO_SIGNAL+$S.counts.NOT_EVALUATED) -eq 20) 'Strategy vote totals consistent'
Assert ($S.entryAllowed -eq $false -and $S.realExecutionEnabled -eq $false) 'Real entry denied'
Assert ($S.source -eq 'SYNTHETIC_H1_DEMO' -and $S.analysisArchiveStatus -eq 'DEMO_NOT_ARCHIVED_AS_MARKET_EVIDENCE') 'Synthetic data not logged as trusted history'
$Research=Invoke-RestMethod "$BaseUrl/api/v06/calibration/status" -TimeoutSec 15
Assert ($Research.trainedMLModels -eq 0) 'No fabricated trained models'
$Code=0
try{Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/live/orders" -Method POST -Body '{}' -ContentType 'application/json' -TimeoutSec 15 | Out-Null;$Code=200}catch{if($_.Exception.Response){$Code=[int]$_.Exception.Response.StatusCode}else{throw}}
Assert ($Code -eq 423) 'Live order HTTP 423 lock'
Write-Host '[PASS] TradeYar v0.6 smoke tests passed.' -ForegroundColor Green
