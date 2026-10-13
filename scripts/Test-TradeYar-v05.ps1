#requires -Version 5.1
[CmdletBinding()]
param([string]$BaseUrl='http://127.0.0.1:8080',[switch]$RunResearchDemo)
$ErrorActionPreference='Stop'
function Check([bool]$test,[string]$message){if(-not $test){throw "[FAIL] $message"};Write-Host "[PASS] $message" -ForegroundColor Green}
$h=Invoke-RestMethod -Uri "$BaseUrl/api/health" -TimeoutSec 15
Check ($h.status -eq 'READY') 'Backend READY'
$u=Invoke-RestMethod -Uri "$BaseUrl/api/v05/capabilities" -TimeoutSec 15
Check ($u.strategyDefinitions -eq 20 -and $u.independentlyValidatedStrategies -eq 0) '20 definitions, zero independently validated'
Check ($u.realExecutionEnabled -eq $false) 'Real orders disabled'
$r=Invoke-RestMethod -Uri "$BaseUrl/api/v05/snapshot?symbol=EURUSD&timeframe=M15&style=INTRADAY" -TimeoutSec 15
Check ($r.strategies.Count -eq 20) '20 strategy rows'
Check (($r.counts.BUY+$r.counts.SELL+$r.counts.NO_SIGNAL+$r.counts.NOT_EVALUATED) -eq 20) 'Vote totals are consistent'
Check ($r.entryAllowed -eq $false -and $r.realExecutionEnabled -eq $false) 'Entry authorization remains denied'
Check ($r.requestedTimeframeApplied -eq $false -or $r.localReadOnlyCsvAvailable -eq $true) 'No fake timeframe mapping'
$learning=Invoke-RestMethod -Uri "$BaseUrl/api/v05/research/status" -TimeoutSec 15
Check ($learning.machineLearningTrained -eq $false -and $learning.validatedModels -eq 0) 'No fabricated ML training state'
$code=0
try { Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/live/orders" -Method POST -ContentType 'application/json' -Body '{}' -TimeoutSec 15 | Out-Null; $code=200 }
catch {if($_.Exception.Response){$code=[int]$_.Exception.Response.StatusCode}else{throw}}
Check ($code -eq 423) 'HTTP 423 real order lock'
if($RunResearchDemo){
 $body=@{symbol='EURUSD';timeframe='H1';strategy='SMA_CROSS';spreadPips=1.5}|ConvertTo-Json -Compress
 $res=Invoke-RestMethod -Uri "$BaseUrl/api/v05/research/run" -Method POST -ContentType 'application/json' -Body $body -TimeoutSec 30
 Check ($res.trainedModel -eq $false -and $res.savedToLocalResearchLog -eq $true) 'Demo research saved, no ML training claimed'
}
Write-Host '[PASS] TradeYar v0.5 smoke tests passed.' -ForegroundColor Green
