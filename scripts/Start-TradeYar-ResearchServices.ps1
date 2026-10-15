#requires -Version 5.1
<#
TradeYar v0.6.3 - offline startup of the three owned research services.
Shared MinIO is checked/reused, NEVER managed by this launcher.
No pull, downloads, image builds, cache mirroring, database migrations,
container removal, volume modifications, or trading execution.
#>
[CmdletBinding()]
param(
    [ValidateSet('Check','Start')][string]$Mode = 'Check',
    [string]$ProjectPath = '',
    [string]$DepotPath = '',
    [ValidateSet('timescale','neo4j','clickhouse')][string[]]$Services = @('timescale','neo4j','clickhouse'),
    [int]$HealthTimeoutSeconds = 120
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($HealthTimeoutSeconds -lt 10 -or $HealthTimeoutSeconds -gt 600) { throw 'HealthTimeoutSeconds must be between 10 and 600' }
if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) { throw "Missing TradeYar project: $ProjectPath" }
$Root = (Resolve-Path -LiteralPath $ProjectPath).Path
$RootNormalized = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\','/'))
if (-not (Test-Path -LiteralPath (Join-Path $Root 'backend\app\pom.xml') -PathType Leaf)) { throw 'Not a TradeYar checkout' }
if ([string]::IsNullOrWhiteSpace($DepotPath)) { $DepotPath = Join-Path (Split-Path -Parent $Root) 'TradeYar-OfflineDepot' }
$Depot = [IO.Path]::GetFullPath($DepotPath).TrimEnd([char[]]@('\','/'))
if ($Depot -ieq $RootNormalized -or $Depot.StartsWith($RootNormalized + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Depot must remain outside Git checkout'
}
$LockPath = Join-Path $Root 'infrastructure\v063\offline-images.lock.json'
$Compose = Join-Path $Root 'infrastructure\v063\compose.yml'
$ComposeEnv = Join-Path $Root 'infrastructure\v063\.env'
$Manager = Join-Path $Root 'scripts\Manage-TradeYar-OfflineImages.ps1'
$MinioManifest = Join-Path $Depot 'manifests\shared-minio.json'
$AuditPath = Join-Path $Depot 'manifests\images.manifest.json'
foreach ($file in @($LockPath,$Compose,$Manager,$MinioManifest,$AuditPath)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "OFFLINE MISS: startup requirement missing: $file" }
}
function Say([string]$message) { Write-Host ('[TRADEYAR-STARTUP] ' + $message) }
function ExitCheck([string]$purpose) { if ($LASTEXITCODE -ne 0) { throw "$purpose failed (exit code $LASTEXITCODE)" } }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker CLI unavailable' }
& docker info --format '{{.ServerVersion}}' | Out-Null
ExitCheck 'Docker Engine'
& docker compose version --short | Out-Null
ExitCheck 'Docker Compose'
$Lock = Get-Content -LiteralPath $LockPath -Encoding UTF8 -Raw | ConvertFrom-Json
if ([int]$Lock.schemaVersion -ne 1 -or [string]$Lock.projectName -cne 'tradeyar-v063' -or
    [string]$Lock.composeFile -cne 'infrastructure/v063/compose.yml') {
    throw 'Unexpected offline image lock/project definition'
}
$Assets = @($Lock.assets)
if ($Assets.Count -ne 3) { throw 'Expected exactly three project-owned image entries' }
$Known = @('timescale','neo4j','clickhouse')
$Seen = @{}
foreach ($item in $Assets) {
    $svc = [string]$item.service
    if ($svc -notin $Known -or $Seen.ContainsKey($svc)) { throw "Unknown/duplicate service in lock: $svc" }
    $Seen[$svc] = $true
}
if (@($Seen.Keys).Count -ne 3) { throw 'Incomplete owned-service lock' }
if (@($Services | Select-Object -Unique).Count -ne $Services.Count) { throw 'Duplicate requested research service' }
$ComposeSource = Get-Content -LiteralPath $Compose -Encoding UTF8 -Raw
if ($ComposeSource -match '(?m)^\s{2}minio:\s*$') { throw 'Dedicated MinIO service is forbidden in TradeYar research Compose' }
$ComposeImages = @([regex]::Matches($ComposeSource, '(?m)^\s*image:\s*["'']?([^\s"'']+)["'']?\s*(?:#.*)?$'))
if ($ComposeImages.Count -ne 3) { throw 'Compose image count does not match lock' }
foreach ($item in $Assets) {
    if (@($ComposeImages | Where-Object { $_.Groups[1].Value -ceq [string]$item.image }).Count -ne 1) {
        throw "Compose image mismatch: $($item.image)"
    }
}
$Minio = Get-Content -LiteralPath $MinioManifest -Encoding UTF8 -Raw | ConvertFrom-Json
if ([int]$Minio.schemaVersion -ne 1 -or [string]$Minio.projectName -cne 'tradeyar-v063' -or
    $Minio.usesExistingSharedContainer -ne $true -or $Minio.minioManagedByTradeYar -ne $false -or
    [string]$Minio.sharedContainer -cne 'sakhtyar-local-minio-1' -or
    [string]$Minio.imageId -cnotmatch '^sha256:[a-fA-F0-9]{64}$' -or
    [string]$Minio.apiHostPort -cnotmatch '^[0-9]{2,5}$') {
    throw 'Shared MinIO manifest invalid or not authorized for TradeYar'
}
# Only inspect the already-running container. Do not read Env/credentials.
$RunningNames = @(& docker ps --format '{{.Names}}')
ExitCheck 'Docker container inventory'
if ($RunningNames -cnotcontains [string]$Minio.sharedContainer) {
    throw "SHARED MINIO UNAVAILABLE: $($Minio.sharedContainer) is not running. Never start/modify it from TradeYar."
}
$LiveMinioId = [string](& docker inspect --format '{{.Image}}' ([string]$Minio.sharedContainer))
ExitCheck 'Shared MinIO image identity'
if ($LiveMinioId.Trim() -cne [string]$Minio.imageId) { throw 'SHARED MINIO IMAGE DRIFT: reapprove external service identity before startup' }
$LivePortsJson = [string](& docker inspect --format '{{json .NetworkSettings.Ports}}' ([string]$Minio.sharedContainer))
ExitCheck 'Shared MinIO API port mapping'
$LivePorts = $LivePortsJson | ConvertFrom-Json
$ApiPortProperty = $LivePorts.PSObject.Properties['9000/tcp']
if ($null -eq $ApiPortProperty -or $null -eq $ApiPortProperty.Value) { throw 'SHARED MINIO API not published on container 9000' }
$Bindings = @($ApiPortProperty.Value)
if (@($Bindings | Where-Object { [string]$_.HostPort -ceq [string]$Minio.apiHostPort }).Count -lt 1) {
    throw 'SHARED MINIO PORT DRIFT: host port no longer matches approved local manifest'
}
Say "Shared MinIO REUSED (read-only check): $($Minio.sharedContainer), http://127.0.0.1:$($Minio.apiHostPort)"
Say 'MinIO credentials and bucket access have NOT been verified; no container changes made.'
if (-not (Test-Path -LiteralPath $ComposeEnv -PathType Leaf)) {
    throw 'LOCAL CONFIG MISSING: infrastructure\v063\.env. Copy .env.example and set private service credentials.'
}
$EnvContents = Get-Content -LiteralPath $ComposeEnv -Raw -Encoding UTF8
if ($EnvContents -match '(?i)replace-with|REPLACE_ME|CHANGE_ME') { throw 'Unchanged placeholder in local Compose .env' }
& docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose config --quiet
ExitCheck 'Offline research Compose validation'
$Audit = Get-Content -LiteralPath $AuditPath -Encoding UTF8 -Raw | ConvertFrom-Json
if ([int]$Audit.schemaVersion -ne 1 -or [string]$Audit.projectName -cne 'tradeyar-v063') {
    throw 'Invalid local image identity audit'
}
foreach ($svc in $Services) {
    $asset = @($Assets | Where-Object { $_.service -ceq $svc })
    $record = @($Audit.items | Where-Object { $_.service -ceq $svc })
    if ($asset.Count -ne 1 -or $record.Count -ne 1 -or
        [string]$asset[0].image -cne [string]$record[0].image -or
        [string]$asset[0].archive -cne [string]$record[0].archive -or
        [string]$record[0].imageId -cnotmatch '^sha256:[a-fA-F0-9]{64}$') {
        throw "OFFLINE MISS / IMAGE DRIFT: audited image missing for $svc"
    }
}
# Verify archive bytes and identity against audit every time. This can take time for large TARs.
# Pass one service per child invocation: powershell.exe -File does not reliably bind string[] arguments.
foreach ($svc in $Services) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Manager -ProjectPath $Root -DepotPath $Depot -Mode Verify -Services $svc
    ExitCheck "Offline archive SHA-256 verification: $svc"
}
if ($Mode -eq 'Check') { Say 'CHECK PASSED: audited archives, Compose configuration and shared MinIO are present. No services started.'; return }
# Strict offline restore: will load verified tar only if a local image is absent.
foreach ($svc in $Services) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Manager -ProjectPath $Root -DepotPath $Depot -Mode Restore -Services $svc
    ExitCheck "Offline image restore: $svc"
}
function Get-ComposeId([string]$service) {
    $ids = @(& docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose ps -a -q $service)
    ExitCheck "Docker Compose inventory for $service"
    if ($ids.Count -eq 0) { return '' }
    if ($ids.Count -ne 1) { throw "Multiple TradeYar containers found for $service" }
    return ([string]$ids[0]).Trim()
}
function Get-State([string]$id) {
    $value = [string](& docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' $id)
    ExitCheck "Docker state for container $id"
    return $value.Trim()
}
foreach ($svc in $Services) {
    $matches = @($Audit.items | Where-Object { $_.service -ceq $svc })
    $record = $matches[0]
    $cid = Get-ComposeId $svc
    if ($cid) {
        $containerImage = [string](& docker inspect --format '{{.Image}}' $cid)
        ExitCheck "Docker image of container for $svc"
        if ($containerImage.Trim() -cne [string]$record.imageId) {
            throw "CONTAINER IMAGE DRIFT: $svc uses a different image. Manual review required; not recreating it."
        }
        $state = Get-State $cid
        if ($state -match '^running\|(healthy|no-healthcheck)$') { Say "REUSE: $svc ($state)"; continue }
        if ($state -match '^running\|unhealthy$') { throw "UNHEALTHY: $svc; no forced restart" }
    }
    Say "START OFFLINE: $svc"
    & docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose up -d --pull never --no-build --no-deps --no-recreate $svc
    ExitCheck "Offline Docker Compose start for $svc"
    $cid = Get-ComposeId $svc
    if (-not $cid) { throw "Container missing after start: $svc" }
    $containerImage = [string](& docker inspect --format '{{.Image}}' $cid)
    ExitCheck "Post-start image of $svc"
    if ($containerImage.Trim() -cne [string]$record.imageId) { throw "Image identity mismatch after starting $svc" }
    $ready = $false
    $cycles = [int][Math]::Ceiling($HealthTimeoutSeconds / 2.0)
    for ($i = 0; $i -lt $cycles; $i++) {
        $state = Get-State $cid
        if ($state -match '^running\|(healthy|no-healthcheck)$') { $ready = $true; break }
        if ($state -match '^(exited|dead)\|') { break }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { throw "NOT READY: $svc state=$state; inspect its logs (no automatic restart)" }
    Say "RUNNING: $svc ($state)"
}
Say 'SUCCESS: selected owned services started/reused with --pull never; shared MinIO untouched.'
Say 'Note: RUNNING without healthcheck does not certify database query/schema readiness.'
