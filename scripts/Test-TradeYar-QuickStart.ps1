#requires -Version 5.1
param([string]$BaseUrl='http://127.0.0.1:8080')
$ErrorActionPreference='Stop'
$base=$BaseUrl.TrimEnd('/')
function Assert($ok,$message){if(-not $ok){throw "[FAIL] $message"};Write-Host "[PASS] $message" -ForegroundColor Green}
$health=Invoke-RestMethod "$base/api/health"
Assert ($health.status -eq 'READY') 'Backend READY'
$response=Invoke-WebRequest "$base/api/v1/workspace/snapshot?symbol=EURUSD&style=INTRADAY" -UseBasicParsing
$snapshot=ConvertFrom-Json -InputObject $response.Content
$rows=@($snapshot.strategies | ForEach-Object { $_ })
Assert ($rows.Count -eq 20) '20 strategy statuses'
Assert ($snapshot.implementedCount -eq 3) 'Exactly 3 demo algorithms currently implemented'
Assert ((@($rows | Where-Object { $_.signal -eq 'NOT_IMPLEMENTED' })).Count -eq 17) '17 algorithms clearly NOT_IMPLEMENTED'
Assert ($snapshot.decision -eq 'INSUFFICIENT_EVIDENCE' -and $snapshot.entryAllowed -eq $false -and $snapshot.realExecutionEnabled -eq $false) 'No authorized entry or live order'
Assert ($snapshot.actualLiveMarketFeed -eq $false -and $snapshot.requestedTimeframeApplied -eq $false -and $snapshot.source -eq 'SYNTHETIC_DEMO') 'Synthetic H1 data explicitly labeled'
Assert ((@($snapshot.candles | ForEach-Object { $_ })).Count -eq 100) '100 synthetic candles'
$train=Invoke-RestMethod "$base/api/v1/workspace/training/status"
Assert ($train.trainedModels -eq 0 -and $train.verifiedHistoryYears -eq 0 -and $train.readyToStart -eq $false) 'No false training claims'
$preflight=Invoke-RestMethod "$base/api/v1/workspace/training/preflight" -Method Post
Assert ($preflight.started -eq $false -and $preflight.accepted -eq $false) 'Training preflight does not start an invalid job'
$http=0
try{Invoke-WebRequest "$base/api/live/orders" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null;$http=200}catch{if($_.Exception.Response){$http=[int]$_.Exception.Response.StatusCode}else{throw}}
Assert ($http -eq 423) 'Real order submission hard-locked HTTP 423'
Write-Host '[PASS] Quick Start API smoke checks passed' -ForegroundColor Green
