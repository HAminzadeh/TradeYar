#requires -Version 5.1
<#
TradeYar v0.6.3 / Phase 2: strictly offline, per-project specialist Docker image depot.
This script never pulls, downloads, installs, starts containers, or modifies volumes.
#>
[CmdletBinding()]
param(
    [ValidateSet('Status','Seed','Verify','Restore')][string]$Mode = 'Status',
    [string]$ProjectPath = '',
    [string]$DepotPath = '',
    [ValidateSet('timescale','neo4j','clickhouse')][string[]]$Services = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) { throw "TradeYar project missing: $ProjectPath" }
$Project = (Resolve-Path -LiteralPath $ProjectPath).Path
$LockPath = Join-Path $Project 'infrastructure\v063\offline-images.lock.json'
if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) { throw "Offline image lock missing: $LockPath" }
$Lock = Get-Content -LiteralPath $LockPath -Encoding UTF8 -Raw | ConvertFrom-Json
if ($Lock.schemaVersion -ne 1 -or [string]$Lock.projectName -ne 'tradeyar-v063') { throw 'Unexpected offline image lock version/project' }
$Known = @('timescale','neo4j','clickhouse')
$Assets = @($Lock.assets)
if ($Assets.Count -ne $Known.Count) { throw 'Expected exactly three TradeYar-owned image records' }
$SeenServices = @{}
$SeenFiles = @{}
foreach ($item in $Assets) {
    $svc = [string]$item.service
    $img = [string]$item.image
    $file = [string]$item.archive
    if ($svc -notin $Known -or $SeenServices.ContainsKey($svc)) { throw "Invalid or duplicate service: $svc" }
    if ($file -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.tar$' -or $SeenFiles.ContainsKey($file)) { throw "Unsafe or duplicate archive name: $file" }
    if ($img -notmatch '^[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$' -or $img -match ':latest$') { throw "Invalid/unpinned image: $img" }
    $SeenServices[$svc] = $true
    $SeenFiles[$file] = $true
}
foreach ($svc in $Known) { if (-not $SeenServices.ContainsKey($svc)) { throw "Missing service in lock: $svc" } }
if ([string]$Lock.composeFile -ne 'infrastructure/v063/compose.yml') { throw 'Unexpected Compose location in image lock' }
$Compose = Join-Path $Project ([string]$Lock.composeFile)
if (-not (Test-Path -LiteralPath $Compose -PathType Leaf)) { throw "Missing Compose file: $Compose" }
$Source = Get-Content -LiteralPath $Compose -Encoding UTF8 -Raw
$ImageLines = @([regex]::Matches($Source, '(?m)^\s*image:\s*["'']?([^\s"'']+)["'']?\s*(?:#.*)?$'))
if ($ImageLines.Count -ne $Assets.Count) { throw 'Compose images differ from the lock; review before proceeding' }
foreach ($item in $Assets) {
    if (@($ImageLines | Where-Object { $_.Groups[1].Value -ceq [string]$item.image }).Count -ne 1) {
        throw "Compose image not locked exactly once: $($item.image)"
    }
}
if ([string]::IsNullOrWhiteSpace($DepotPath)) { $DepotPath = Join-Path (Split-Path -Parent $Project) 'TradeYar-OfflineDepot' }
$Depot = [IO.Path]::GetFullPath($DepotPath).TrimEnd([char[]]@('\','/'))
$ProjectNormal = [IO.Path]::GetFullPath($Project).TrimEnd([char[]]@('\','/'))
if ($Depot -ieq $ProjectNormal -or $Depot.StartsWith($ProjectNormal + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Depot must be outside Git checkout'
}
$ImageDir = Join-Path $Depot 'docker-images'
$ManifestDir = Join-Path $Depot 'manifests'
$AuditPath = Join-Path $ManifestDir 'images.manifest.json'
if ($Services.Count -eq 0) { $Services = $Known }
$Selected = @($Assets | Where-Object { $_.service -in $Services })
if ($Selected.Count -ne $Services.Count) { throw 'Repeated/unknown service selection' }
function Report([string]$message) { Write-Host ('[TRADEYAR-DEPOT] ' + $message) }
function Check-Exit([string]$what) { if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" } }
function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'OFFLINE MISS: Docker CLI not installed' }
    & docker info --format '{{.ServerVersion}}' | Out-Null
    Check-Exit 'Docker Engine'
}
function Get-ImageId([string]$reference) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return '' }
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = (& docker image inspect $reference --format '{{.Id}}' 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $output) { return '' }
        return ([string]($output | Select-Object -First 1)).Trim()
    } finally { $ErrorActionPreference = $oldPreference }
}
function Read-Audit {
    if (-not (Test-Path -LiteralPath $AuditPath -PathType Leaf)) {
        return [pscustomobject]@{schemaVersion=1;projectName='tradeyar-v063';items=@()}
    }
    $data = Get-Content -LiteralPath $AuditPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.schemaVersion -ne 1 -or [string]$data.projectName -ne 'tradeyar-v063' -or $null -eq $data.items) {
        throw 'Invalid audit manifest; no silent reconstruction'
    }
    return $data
}
function Get-AuditRecord($audit,[string]$service) {
    $records = @($audit.items | Where-Object { $_.service -ceq $service })
    if ($records.Count -gt 1) { throw "Duplicate audit record: $service" }
    if ($records.Count -eq 0) { return $null }
    return $records[0]
}
function Verify-Asset($item,$audit) {
    $archive = Join-Path $ImageDir ([string]$item.archive)
    $sidecar = $archive + '.sha256'
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf) -or -not (Test-Path -LiteralPath $sidecar -PathType Leaf)) {
        throw "OFFLINE MISS: archive/sidecar absent: $archive"
    }
    $record = Get-AuditRecord $audit ([string]$item.service)
    if ($null -eq $record) { throw "OFFLINE MISS: audited record missing for $($item.service)" }
    if ([string]$record.service -cne [string]$item.service -or [string]$record.image -cne [string]$item.image -or
        [string]$record.archive -cne [string]$item.archive -or [string]$record.imageId -cnotmatch '^sha256:[a-fA-F0-9]{64}$') {
        throw "Audited identity mismatch: $($item.service)"
    }
    $expected = (Get-Content -LiteralPath $sidecar -Raw -Encoding UTF8).Trim()
    if ($expected -cnotmatch '^[a-f0-9]{64}$' -or [string]$record.sha256 -cne $expected) {
        throw "Invalid SHA-256 sidecar/manifest: $($item.service)"
    }
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $expected) { throw "SHA-256 FAILED: $archive" }
    Report "VERIFIED: $($item.service) ($expected)"
    return $record
}
function Write-Audit($audit) {
    $pending = $AuditPath + '.partial'
    if (Test-Path -LiteralPath $pending) { throw "Pending audit file exists, review manually: $pending" }
    $json = $audit | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($pending, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $pending -Destination $AuditPath -Force
}
function Seed-Asset($item) {
    $reference = [string]$item.image
    $archive = Join-Path $ImageDir ([string]$item.archive)
    $sidecar = $archive + '.sha256'
    $audit = Read-Audit
    $imageId = Get-ImageId $reference
    if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $sidecar)) {
        $record = Verify-Asset $item $audit
        if ($imageId -and [string]$record.imageId -cne $imageId) {
            throw "TAG DRIFT: local $reference differs from archived ID"
        }
        Report "REUSED VERIFIED ARCHIVE: $reference"
        return
    }
    if (-not $imageId) { throw "OFFLINE MISS: $reference not present in local Docker. Operator must acquire it explicitly." }
    if ($imageId -notmatch '^sha256:[a-fA-F0-9]{64}$') { throw "Unexpected Docker image ID: $imageId" }
    $partial = $archive + '.partial'
    if (Test-Path -LiteralPath $partial) { throw "Partial Docker export exists, inspect it: $partial" }
    Report "EXPORT: $reference (no pull)"
    & docker save --output $partial $reference
    Check-Exit "Docker save $reference"
    if (-not (Test-Path -LiteralPath $partial -PathType Leaf)) { throw "Missing export: $partial" }
    if ((Get-ImageId $reference) -cne $imageId) { throw "TAG DRIFT during export: $reference" }
    $sha = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
    Move-Item -LiteralPath $partial -Destination $archive
    [IO.File]::WriteAllText($sidecar, $sha + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $newRecord = [pscustomobject]@{
        service=[string]$item.service;image=$reference;archive=[string]$item.archive
        imageId=$imageId;sha256=$sha;createdUtc=[DateTime]::UtcNow.ToString('o')
        source='operator-approved-local-docker-image'
    }
    $kept = @($audit.items | Where-Object { $_.service -cne [string]$item.service })
    $audit.items = @($kept + @($newRecord))
    Write-Audit $audit
    $null = Verify-Asset $item (Read-Audit)
    Report "SEEDED: $reference"
}
function Restore-Asset($item) {
    $reference = [string]$item.image
    $archive = Join-Path $ImageDir ([string]$item.archive)
    $record = $null
    if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath ($archive + '.sha256'))) {
        $record = Verify-Asset $item (Read-Audit)
    }
    $localId = Get-ImageId $reference
    if ($localId) {
        if ($null -ne $record -and [string]$record.imageId -cne $localId) { throw "TAG DRIFT: $reference differs from audit" }
        Report "LOCAL REUSE: $reference"
        return
    }
    if ($null -eq $record) { throw "OFFLINE MISS: no local image or verified archive: $reference" }
    Report "LOAD: $reference (verified archive only)"
    & docker load --input $archive
    Check-Exit "Docker load $reference"
    if ((Get-ImageId $reference) -cne [string]$record.imageId) { throw "Image ID mismatch after Docker load: $reference" }
    Report "RESTORED: $reference"
}
switch ($Mode) {
    'Status' {
        Report "Project: $Project"
        Report "Depot: $Depot"
        foreach ($item in $Selected) {
            $archive = Join-Path $ImageDir ([string]$item.archive)
            $files = if ((Test-Path -LiteralPath $archive -PathType Leaf) -and
                (Test-Path -LiteralPath ($archive + '.sha256') -PathType Leaf)) { 'ARCHIVED_UNVERIFIED' } else { 'OFFLINE_MISS' }
            $local = if (Get-ImageId ([string]$item.image)) { 'LOCAL_PRESENT' } else { 'LOCAL_MISSING_OR_DOCKER_OFFLINE' }
            Report "$($item.service): $local / $files"
        }
        Report 'Status does not hash files. Run -Mode Verify for integrity validation.'
    }
    'Seed' {
        Assert-Docker
        foreach ($dir in @($Depot,$ImageDir,$ManifestDir)) {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        foreach ($item in $Selected) { Seed-Asset $item }
    }
    'Verify' {
        $audit = Read-Audit
        foreach ($item in $Selected) { $null = Verify-Asset $item $audit }
        Report 'Selected archive integrity and image identity checks passed.'
    }
    'Restore' {
        Assert-Docker
        foreach ($item in $Selected) { Restore-Asset $item }
    }
}
