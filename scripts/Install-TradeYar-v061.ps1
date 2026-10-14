#requires -Version 5.1
<#
TradeYar v0.6.1 source-only staged installer.
Plain, auditable PowerShell. Nothing downloaded or executed from the internet.
A separate ZIP contains human-readable source; no Base64 payload is embedded.
No Git commit/push, no antivirus changes, no broker order changes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProjectPath,
    [Parameter(Mandatory=$true)][string]$PayloadZip,
    [ValidateSet('Verify','All','S1','S2','S3','S4','S5')][string]$Stage='All',
    [switch]$RunTests
)
$ErrorActionPreference='Stop'
$ExpectedZipSha256='6873f8924bd5fd1d3d97c26ef95c8d2a49d1e0af073403ad42068e6b85f9cb40'
$Required=@('backend\pom.xml','backend\app\pom.xml','frontend\src\App.tsx','backend\app\src\main\java\com\tradeyar\app\execution\LiveExecutionController.java')
if(-not (Test-Path -LiteralPath $PayloadZip -PathType Leaf)){throw 'Source ZIP is missing.'}
if(-not (Test-Path -LiteralPath $ProjectPath -PathType Container)){throw 'TradeYar project folder is missing.'}
$Root=(Resolve-Path -LiteralPath $ProjectPath).Path
foreach($name in $Required){if(-not (Test-Path -LiteralPath (Join-Path $Root $name))){throw "Project baseline missing: $name"}}
$LockSource=Get-Content -LiteralPath (Join-Path $Root $Required[3]) -Raw -Encoding UTF8
if($LockSource -notmatch 'HttpStatus\.LOCKED'){throw 'Live-order HTTP 423 safety gate missing from baseline. Refusing to patch.'}
$hash=(Get-FileHash -LiteralPath $PayloadZip -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -ne $ExpectedZipSha256){throw "Source ZIP SHA-256 mismatch. Expected $ExpectedZipSha256; found $hash"}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Archive=[System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PayloadZip).Path)
$ExtractRoot=Join-Path $env:TEMP ('TradeYar-v06-'+[guid]::NewGuid().ToString('N'))
$Backup=Join-Path $Root ('.tradeyar-backups\v06-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$SelectedCount=0;$UpdatedCount=0;$SkippedCount=0
try {
    $ManifestEntry=$Archive.GetEntry('source-manifest.json')
    if($null -eq $ManifestEntry){throw 'source-manifest.json is missing from ZIP.'}
    $Reader=New-Object System.IO.StreamReader($ManifestEntry.Open(),[System.Text.Encoding]::UTF8)
    try{$Manifest=ConvertFrom-Json -InputObject $Reader.ReadToEnd()}finally{$Reader.Dispose()}
    if($Manifest.release -ne '0.6.1-windows-archive-sync-repair'){throw 'Unexpected payload release.'}
    $Items=@($Manifest.files)
    if($Items.Count -lt 15){throw 'Source manifest has too few files.'}
    $Found=@{}
    foreach($Item in $Items){
        $Relative=[string]$Item.path
        if($Relative -notmatch '^(backend|frontend|scripts|infrastructure|docs|tests)/[A-Za-z0-9_./-]+$' -or $Relative.Contains('..') -or $Found.ContainsKey($Relative)){
            throw "Unsafe or duplicate archive path: $Relative"
        }
        $Found[$Relative]=$true
        if(@('S1','S2','S3','S4','S5') -notcontains [string]$Item.stage){throw "Unknown stage in manifest: $Relative"}
        $Entry=$Archive.GetEntry($Relative)
        if($null -eq $Entry){throw "Required entry missing: $Relative"}
        if($Entry.Length -gt 2097152){throw "Unexpectedly large source file: $Relative"}
    }
    New-Item -ItemType Directory -Path $ExtractRoot -Force | Out-Null
    # Verify every source before changing any project file, even for a single-stage install.
    foreach($Item in $Items){
        $Relative=[string]$Item.path
        $Target=Join-Path $ExtractRoot ($Relative.Replace('/','\'))
        New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force | Out-Null
        $ReadStream=$Archive.GetEntry($Relative).Open()
        $WriteStream=[System.IO.File]::Create($Target)
        try{$ReadStream.CopyTo($WriteStream)}finally{$WriteStream.Dispose();$ReadStream.Dispose()}
        $Actual=(Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant()
        if($Actual -ne ([string]$Item.sha256).ToLowerInvariant()){throw "SHA-256 mismatch inside archive: $Relative"}
    }
    Write-Host "[PASS] Archive verified: $($Items.Count) source files." -ForegroundColor Green
    if($Stage -eq 'Verify'){
        Write-Host '[PASS] Verify-only mode. No files modified.' -ForegroundColor Green
        return
    }
    $Stages=if($Stage -eq 'All'){@('S1','S2','S3','S4','S5')}else{@($Stage)}
    foreach($Current in $Stages){
        Write-Host "[STAGE] $Current" -ForegroundColor Cyan
        foreach($Item in $Items){
            if($Item.stage -ne $Current){continue}
            $Relative=[string]$Item.path
            $Source=Join-Path $ExtractRoot ($Relative.Replace('/','\'))
            $Target=Join-Path $Root ($Relative.Replace('/','\'))
            $SelectedCount++
            if(Test-Path -LiteralPath $Target){
                $oldHash=(Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant()
                if($oldHash -eq ([string]$Item.sha256).ToLowerInvariant()){
                    $SkippedCount++
                    Write-Host "[UNCHANGED] $Relative"
                    continue
                }
                $BackupFile=Join-Path $Backup ($Relative.Replace('/','\'))
                New-Item -ItemType Directory -Path (Split-Path -Parent $BackupFile) -Force | Out-Null
                Copy-Item -LiteralPath $Target -Destination $BackupFile -Force
                Write-Host "[BACKUP] $Relative" -ForegroundColor Yellow
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force | Out-Null
            Copy-Item -LiteralPath $Source -Destination $Target -Force
            $UpdatedCount++
            Write-Host "[UPDATED] $Relative" -ForegroundColor Cyan
        }
    }
    Write-Host "[DONE] selected=$SelectedCount updated=$UpdatedCount unchanged=$SkippedCount" -ForegroundColor Green
    Write-Host "[INFO] Backup location: $Backup"
    if($RunTests){
        if($Stage -ne 'All') {throw '-RunTests requires -Stage All so that all v0.6 files are present.'}
        Write-Host '[TEST] Backend Maven unit and contract tests...' -ForegroundColor Cyan
        $MavenWrapper=Join-Path $Root 'scripts\Invoke-TradeYar-Maven.ps1'
        if(-not (Test-Path $MavenWrapper)){throw 'Expected project-local Maven wrapper is missing.'}
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MavenWrapper -Goal Test
        if($LASTEXITCODE -ne 0){throw 'Backend Maven tests failed.'}
        Write-Host '[TEST] Frontend TypeScript and Vite...' -ForegroundColor Cyan
        Push-Location (Join-Path $Root 'frontend')
        try{ & npm run build; if($LASTEXITCODE -ne 0){throw 'Frontend npm run build failed.'} }finally{Pop-Location}
        Write-Host '[TEST] Offline archive/resume tests...' -ForegroundColor Cyan
        Push-Location $Root
        try{
            if(Get-Command py -ErrorAction SilentlyContinue){ & py -3 -m unittest discover -s tests -p 'test_*.py' -v }
            elseif(Get-Command python -ErrorAction SilentlyContinue){ & python -m unittest discover -s tests -p 'test_*.py' -v }
            else{throw 'Python 3 is required for archive tests.'}
            if($LASTEXITCODE -ne 0){throw 'Python archive tests failed.'}
        }finally{Pop-Location}
        Write-Host '[PASS] Backend, frontend and offline archive tests passed.' -ForegroundColor Green
    }
    Write-Host '[SAFETY] Broker order API untouched; production execution remains locked.' -ForegroundColor Green
    Write-Host '[DATA] PostgreSQL sync requires a configured local DB/TRADEYAR_PG_DSN; it was not silently simulated.' -ForegroundColor Yellow
    if($Stage -eq 'All') {
        $self = $MyInvocation.MyCommand.Path
        if (-not [string]::IsNullOrWhiteSpace($self)) {
            $repoCopy = Join-Path $Root 'scripts\Install-TradeYar-v061.ps1'
            if (([System.IO.Path]::GetFullPath($self)) -ne ([System.IO.Path]::GetFullPath($repoCopy))) {
                if(Test-Path -LiteralPath $repoCopy) {
                    $existing=(Get-FileHash -LiteralPath $repoCopy -Algorithm SHA256).Hash
                    $incoming=(Get-FileHash -LiteralPath $self -Algorithm SHA256).Hash
                    if($existing -ne $incoming){
                        $backupSelf=Join-Path $Backup 'scripts\Install-TradeYar-v061.ps1'
                        New-Item -ItemType Directory -Path (Split-Path -Parent $backupSelf) -Force | Out-Null
                        Copy-Item -LiteralPath $repoCopy -Destination $backupSelf -Force
                    }
                }
                Copy-Item -LiteralPath $self -Destination $repoCopy -Force
                Write-Host '[SOURCE] Portable installer saved in scripts/Install-TradeYar-v061.ps1' -ForegroundColor Cyan
            }
        }
    }
    Write-Host '[GIT] No automatic commit or push.' -ForegroundColor Cyan
}
finally{
    $Archive.Dispose()
    # PowerShell 5.1 Remove-Item may mishandle an 8.3 short TEMP pathname.
    # .NET cleanup is best-effort: it must never mask Maven/Python test failures.
    if([System.IO.Directory]::Exists($ExtractRoot)) {
        try { [System.IO.Directory]::Delete($ExtractRoot, $true) }
        catch { Write-Warning ("Temporary staging cleanup deferred: " + $_.Exception.Message) }
    }
}
