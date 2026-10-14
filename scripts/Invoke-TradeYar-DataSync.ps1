#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectPath = '',
    [string]$ArchiveRoot = '',
    [string]$ResearchRoot = '',
    [switch]$Watch,
    [ValidateRange(60,86400)][int]$IntervalSeconds = 300,
    [switch]$VerifyOnly
)
$ErrorActionPreference='Stop'
# Determine script directory after the parameter block: $PSScriptRoot can be
# empty when PowerShell 5.1 evaluates a parameter's default expression.
$ScriptFile = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ScriptFile)) { $ScriptFile = $PSCommandPath }
if ([string]::IsNullOrWhiteSpace($ScriptFile)) { throw 'Cannot determine DataSync script location.' }
$ScriptDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ScriptFile))
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = [System.IO.Path]::GetFullPath((Join-Path $ScriptDirectory '..'))
}
$ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    $LocalBase = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($LocalBase)) { $LocalBase = Join-Path $HOME 'AppData\Local' }
    $ArchiveRoot = Join-Path $LocalBase 'TradeYar\history'
}
if ([string]::IsNullOrWhiteSpace($ResearchRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:TRADEYAR_RESEARCH_DIR)) {
        $ResearchRoot = $env:TRADEYAR_RESEARCH_DIR
    } else {
        $ResearchRoot = Join-Path $HOME '.tradeyar\research'
    }
}
$Collector=Join-Path $ProjectPath 'scripts\import_history_postgres_v06.py'
$Research=Join-Path $ProjectPath 'scripts\import_calibration_postgres_v06.py'
if(-not (Test-Path -LiteralPath $Collector) -or -not (Test-Path -LiteralPath $Research)){ throw 'TradeYar v0.6 data sync scripts are not installed.' }
if(-not $VerifyOnly -and [string]::IsNullOrWhiteSpace($env:TRADEYAR_PG_DSN)){
    throw 'TRADEYAR_PG_DSN is not configured on this computer. Archived source files remain safe; PostgreSQL sync was NOT done.'
}
$Python='py';$PythonArgs=@('-3')
if(-not (Get-Command py -ErrorAction SilentlyContinue)){
    $Python='python';$PythonArgs=@()
    if(-not (Get-Command python -ErrorAction SilentlyContinue)){throw 'Python 3 not installed / not on PATH.'}
}
function Invoke-DataSyncOnce {
    $checked=0;$failed=0
    if(Test-Path -LiteralPath $ArchiveRoot){
        $manifests=@(Get-ChildItem -LiteralPath $ArchiveRoot -Recurse -Filter '_manifest.json' -File -ErrorAction Stop)
        foreach($manifest in $manifests){
            $args=@($PythonArgs)+@($Collector,'--folder',$manifest.Directory.FullName)
            if($VerifyOnly){$args+= '--verify-only'}
            & $Python @args
            if($LASTEXITCODE -ne 0){$failed++;Write-Warning "Sync failed: $($manifest.Directory.FullName)"}else{$checked++}
        }
    }
    if(-not $VerifyOnly){
        $args=@($PythonArgs)+@($Research,'--folder',$ResearchRoot)
        & $Python @args
        if($LASTEXITCODE -ne 0){$failed++;Write-Warning 'Research run and strategy event sync failed'}else{$checked++}
    }
    if($checked -eq 0 -and $failed -eq 0){Write-Warning 'No historical archive manifests found; nothing was synchronized or verified.'}
    if($failed -gt 0){throw "Sync partially failed. $failed operation(s) could not be completed. Raw archives have NOT been deleted."}
    Write-Host "[PASS] Data sync/verify completed; processed $checked sources" -ForegroundColor Green
}
do {
    Invoke-DataSyncOnce
    if($Watch){Start-Sleep -Seconds $IntervalSeconds}
} while($Watch)
