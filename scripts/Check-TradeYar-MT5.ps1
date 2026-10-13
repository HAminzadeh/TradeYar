#requires -Version 5.1
# Read-only detection tool. Does not download, install, log in, or launch MT5.
param()
$ErrorActionPreference='Stop'
$paths=@(
  (Join-Path $env:ProgramFiles 'MetaTrader 5\terminal64.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'MetaTrader 5\terminal64.exe')
)
if($env:LOCALAPPDATA){$paths+=Join-Path $env:LOCALAPPDATA 'Programs\MetaTrader 5\terminal64.exe'}
$found=@($paths | Where-Object {$_ -and (Test-Path -LiteralPath $_)})
if($found.Count -eq 0){
  Write-Host '[INFO] MT5 not found in common installation paths.' -ForegroundColor Yellow
  Write-Host 'Existing broker-branded installations may be located elsewhere.'
  Write-Host 'Official information: https://www.metatrader5.com/en/download'
  Write-Host 'No installer has been downloaded or executed.'
} else {
  $found | ForEach-Object {Write-Host "[FOUND] $_" -ForegroundColor Green}
}
