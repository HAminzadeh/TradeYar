#requires -Version 5.1
<#
.SYNOPSIS
  Run TradeYar Maven commands with portable repository-local settings.
.EXAMPLE
  .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Test
.EXAMPLE
  .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Start
.EXAMPLE
  .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Test -UseSystemSettings
#>
param(
    [ValidateSet('Test','Start','Package','OfflineTest')]
    [string]$Goal = 'Test',
    [switch]$UseSystemSettings
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pom = Join-Path $root 'backend\pom.xml'
if ($Goal -eq 'Start') { $pom = Join-Path $root 'backend\app\pom.xml' }
if (-not (Test-Path $pom)) { throw "Backend POM missing: $pom" }
$mvnCommand = Get-Command mvn -ErrorAction SilentlyContinue
if (-not $mvnCommand) { throw 'Maven (mvn) not found in PATH.' }
$arguments = @()
if (-not $UseSystemSettings) {
    $settings = Join-Path $root 'infrastructure\maven\settings-central.xml'
    $globalSettings = Join-Path $root 'infrastructure\maven\settings-empty.xml'
    foreach ($file in @($settings,$globalSettings)) {
        if (-not (Test-Path $file)) { throw "Required project settings missing: $file" }
    }
    $arguments += @('-s',$settings,'-gs',$globalSettings)
    Write-Host 'Maven repository: public Maven Central (project-only settings)' -ForegroundColor Cyan
} else {
    Write-Host 'Maven repository: user/system Maven settings (corporate policy mode)' -ForegroundColor Cyan
}
$arguments += @('-f',$pom)
switch ($Goal) {
    'Test'        { $arguments += @('-U','clean','test') }
    'OfflineTest' { $arguments += @('-o','clean','test') }
    'Package'     { $arguments += @('-pl','app','-am','clean','package','-DskipTests') }
    'Start'       { $arguments += @('org.springframework.boot:spring-boot-maven-plugin:3.5.7:run') }
}
Write-Host "Running Maven goal: $Goal" -ForegroundColor Cyan
& $mvnCommand.Source @arguments
if ($LASTEXITCODE -ne 0) {
    throw "TradeYar Maven $Goal FAILED (exit code $LASTEXITCODE). If HTTPS Maven Central is blocked, use -UseSystemSettings while connected to the approved corporate Nexus/VPN."
}
Write-Host "[PASS] Maven $Goal completed" -ForegroundColor Green