#requires -Version 5.1
<#
TradeYar v0.6.3 offline-only startup and per-project asset depot.
This script never downloads, pulls, contacts package registries, or runs installers.
Use this launcher as the project startup entry point.
#>
[CmdletBinding()]
param(
  [ValidateSet('Init','Status','SeedImages','SeedCaches','Prepare','Start')]
  [string]$Mode = 'Status',
  [string]$ProjectPath = 'D:\ChatGPT_Projects\TradeYar',
  [string]$DepotPath = '',
  [ValidateSet('timescale','neo4j','clickhouse','minio')]
  [string[]]$Services = @('timescale'),
  [switch]$StartFrontend,
  [switch]$NoServices
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "TradeYar project path not found: $ProjectPath"
}
$Project=(Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $Project 'backend\app\pom.xml'))) {
  throw 'Invalid TradeYar project directory'
}
if ([string]::IsNullOrWhiteSpace($DepotPath)) {
  $DepotPath=Join-Path (Split-Path -Parent $Project) 'TradeYar-OfflineDepot'
}
$Depot=[IO.Path]::GetFullPath($DepotPath)
if ($Depot.TrimEnd('\') -eq $Project.TrimEnd('\') -or $Depot.StartsWith($Project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Offline depot must be OUTSIDE the Git repository to avoid exposing credentials and huge image archives.'
}
$Compose=Join-Path $Project 'infrastructure\v063\compose.yml'
$ComposeEnv=Join-Path $Project 'infrastructure\v063\.env'
$LogDir=Join-Path $Depot 'logs'
$ImageDir=Join-Path $Depot 'docker-images'
$ArchiveDir=Join-Path $Depot 'archives'
$ToolDir=Join-Path $Depot 'tools'
$MavenDir=Join-Path $Depot 'maven-repo'
$NpmDir=Join-Path $Depot 'npm-cache'
$WheelDir=Join-Path $Depot 'python-wheelhouse'
$Images=[ordered]@{
  timescale  = @{image='timescale/timescaledb:2.18.2-pg16';file='timescaledb-2.18.2-pg16.tar'}
  neo4j     = @{image='neo4j:5.26-community';file='neo4j-5.26-community.tar'}
  clickhouse= @{image='clickhouse/clickhouse-server:25.3';file='clickhouse-25.3.tar'}
  minio     = @{image='minio/minio:RELEASE.2025-02-07T23-21-09Z';file='minio-2025-02-07.tar'}
}
function Say([string]$Message) {Write-Host ('[TRADEYAR-OFFLINE] '+$Message) -ForegroundColor Cyan}
function Ensure-Depot {
  foreach($dir in @($Depot,$LogDir,$ImageDir,$ArchiveDir,$ToolDir,$MavenDir,$NpmDir,$WheelDir,(Join-Path $Depot 'manifests'),(Join-Path $Depot 'backups'))) {
    if(-not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Force -Path $dir | Out-Null}
  }
}
function HasCommand([string]$cmd){return ($null -ne (Get-Command $cmd -ErrorAction SilentlyContinue))}
function Assert-Success([string]$What){if($LASTEXITCODE -ne 0){throw "$What failed (exit code $LASTEXITCODE)"}}
function Assert-Docker {
  if (-not (HasCommand 'docker')) {throw 'Docker CLI missing. Supply/install it separately; never download during startup.'}
  & docker info --format '{{.ServerVersion}}' | Out-Null
  Assert-Success 'Docker Engine connection'
}
function Assert-ComposeConfig {
  if (-not (Test-Path -LiteralPath $Compose -PathType Leaf)) {throw "Missing compose: $Compose"}
  # Abort rather than silently using an image tag that differs from the audited v063 bundle.
  $src=Get-Content -LiteralPath $Compose -Raw
  foreach($item in $Images.Values){
    if(-not $src.Contains('image: '+$item.image)) {throw "Compose changed: expected pinned image $($item.image); review/update offline inventory first"}
  }
  if (-not (Test-Path -LiteralPath $ComposeEnv -PathType Leaf)) {throw 'Missing infrastructure/v063/.env; configure LOCAL secrets first; do not commit .env.'}
  if ((Get-Content -LiteralPath $ComposeEnv -Raw) -match 'replace-with|REPLACE_ME|CHANGE_ME') {throw 'Placeholder secrets still present in local Compose .env'}
  & docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose config --quiet
  Assert-Success 'Docker Compose config'
}
function Image-Available([string]$reference){
  & docker image inspect $reference '--format={{.Id}}' 1>$null 2>$null
  return ($LASTEXITCODE -eq 0)
}
function Get-ContainerId([string]$svc){
  $id=(& docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose ps -q $svc 2>$null | Select-Object -First 1)
  if(-not $id){return ''};return ([string]$id).Trim()
}
function Get-ContainerState([string]$svc){
  $id=Get-ContainerId $svc
  if(-not $id){return 'ABSENT'}
  $status=(& docker inspect $id '--format={{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>$null)
  if($LASTEXITCODE -ne 0 -or -not $status){return 'UNKNOWN'}
  return ([string]$status).Trim()
}
function Restore-Image([string]$svc){
  $record=$Images[$svc]
  $reference=[string]$record.image
  if(Image-Available $reference){Say "Image already available locally: $reference";return}
  $archive=Join-Path $ImageDir ([string]$record.file)
  $digestFile=$archive+'.sha256'
  if(-not (Test-Path -LiteralPath $archive -PathType Leaf) -or -not (Test-Path -LiteralPath $digestFile -PathType Leaf)) {
    throw "OFFLINE MISS: $reference not loaded; audited archive and SHA-256 required: $archive"
  }
  $expected=(Get-Content -LiteralPath $digestFile -Raw).Trim().Split(' ')[0].ToLowerInvariant()
  if($expected -notmatch '^[a-f0-9]{64}$'){throw "Invalid checksum sidecar for $archive"}
  $actual=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  if($actual -ne $expected){throw "SHA-256 mismatch. Refusing Docker load: $archive"}
  Say "Loading audited offline image: $reference"
  & docker load --input $archive
  Assert-Success "Docker load $reference"
  if(-not (Image-Available $reference)){throw "Offline archive did not contain expected image: $reference"}
}
function Save-Images {
  Assert-Docker
  foreach($svc in $Images.Keys){
    $record=$Images[$svc];$reference=[string]$record.image
    if(-not (Image-Available $reference)) {Write-Warning "Not locally available; skipped (no pull): $reference";continue}
    $archive=Join-Path $ImageDir ([string]$record.file)
    if(Test-Path -LiteralPath $archive){
      if(-not (Test-Path -LiteralPath ($archive+'.sha256'))){throw "Archive exists without checksum; inspect manually: $archive"}
      $want=(Get-Content -LiteralPath ($archive+'.sha256') -Raw).Trim().Split(' ')[0]
      $got=(Get-FileHash $archive -Algorithm SHA256).Hash
      if($want -ine $got){throw "Archive checksum mismatch: $archive"}
      Say "Existing verified archive reused: $archive";continue
    }
    $temp=$archive+'.partial'
    if(Test-Path -LiteralPath $temp){throw "Incomplete previous export exists: $temp"}
    Say "Saving local Docker image (may require several GB of free disk): $reference"
    & docker save --output $temp $reference
    Assert-Success "Docker save $reference"
    $sha=(Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant()
    Move-Item -LiteralPath $temp -Destination $archive
    [IO.File]::WriteAllText($archive+'.sha256',$sha+"`n",[Text.UTF8Encoding]::new($false))
    Say "Archived with SHA-256: $archive"
  }
}
function Copy-LocalCache([string]$src,[string]$target,[string]$label){
  if(-not (Test-Path -LiteralPath $src -PathType Container)){Write-Warning "$label cache missing: $src";return}
  $srcPath=[IO.Path]::GetFullPath($src).TrimEnd('\')
  $dstPath=[IO.Path]::GetFullPath($target).TrimEnd('\')
  if($srcPath -ieq $dstPath){Say "$label cache already at depot";return}
  Say "Seeding $label cache from local computer. May take time; no download."
  & robocopy $srcPath $dstPath /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if($LASTEXITCODE -gt 7){throw "robocopy failed for $label with code $LASTEXITCODE"}
}
function Seed-Caches {
  Copy-LocalCache (Join-Path $HOME '.m2\repository') $MavenDir 'Maven'
  if(HasCommand 'npm'){
    $npmSource=(& npm config get cache 2>$null | Select-Object -Last 1)
    if($LASTEXITCODE -eq 0 -and $npmSource){Copy-LocalCache ([string]$npmSource).Trim() $NpmDir 'npm'}
  }
  Say 'Python wheels must be placed separately in python-wheelhouse with verified provenance; installed packages do not reconstruct original wheels.'
}
function Resolve-Tool([string]$id,[string]$command,[string]$executable,[string]$versionArgs,[int]$minMajor){
  $cmd=Get-Command $command -ErrorAction SilentlyContinue
  if($null -ne $cmd){
    # Windows PowerShell 5.1 treats some native stderr (e.g. java -version) as error records.
    $oldPref=$ErrorActionPreference
    try {$ErrorActionPreference='Continue'; $v=(& $cmd.Source $versionArgs 2>&1 | Out-String)}
    finally {$ErrorActionPreference=$oldPref}
    if($v -match '(?<!\d)(\d+)(?:\.\d+)?' -and [int]$Matches[1] -ge $minMajor){
      Say "Using installed ${id}: $($cmd.Source)"
      return $cmd.Source
    }
    Write-Warning "Installed $id version not compatible: $($v.Trim().Split("`n")[0]); checking offline depot"
  }
  $homeDir=Join-Path $ToolDir $id
  $found=@()
  if(Test-Path -LiteralPath $homeDir){$found=@(Get-ChildItem -LiteralPath $homeDir -Filter $executable -File -Recurse -ErrorAction SilentlyContinue)}
  if($found.Count -eq 0){
    $zip=Join-Path $ArchiveDir ($id+'.zip');$shaFile=$zip+'.sha256'
    if(-not (Test-Path -LiteralPath $zip) -or -not (Test-Path -LiteralPath $shaFile)){
      throw "OFFLINE MISS: compatible $id not installed and audited portable $id.zip + .sha256 absent. No internet request attempted."
    }
    $expected=(Get-Content -LiteralPath $shaFile -Raw).Trim().Split(' ')[0]
    if($expected -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash $zip -Algorithm SHA256).Hash -ine $expected){throw "Untrusted offline tool archive: $zip"}
    if(Test-Path -LiteralPath $homeDir){throw "Tool folder exists but executable missing; manually review: $homeDir"}
    Say "Unpacking audited portable tool: $id"
    Expand-Archive -LiteralPath $zip -DestinationPath $homeDir
    $found=@(Get-ChildItem -LiteralPath $homeDir -Filter $executable -File -Recurse -ErrorAction SilentlyContinue)
  }
  if($found.Count -ne 1){throw "Expected one portable $executable under $homeDir, found $($found.Count)"}
  $binary=$found[0].FullName
  $oldPref=$ErrorActionPreference
  try {$ErrorActionPreference='Continue'; $v=(& $binary $versionArgs 2>&1 | Out-String)}
  finally {$ErrorActionPreference=$oldPref}
  if(-not ($v -match '(?<!\d)(\d+)(?:\.\d+)?') -or [int]$Matches[1] -lt $minMajor){throw "Offline $id version is too old or invalid"}
  $binDir=Split-Path -Parent $binary
  $env:PATH=$binDir+';'+$env:PATH
  if($id -eq 'jdk'){$env:JAVA_HOME=Split-Path -Parent $binDir}
  Say "Using audited offline ${id}: $binary"
  return $binary
}
function Prepare-LocalTools {
  # All package managers are forced offline even if separately invoked by child processes.
  $env:TRADEYAR_AUTO_REPAIR_ON_STARTUP='false'
  $env:TRADEYAR_OFFLINE_ONLY='true'
  $env:PIP_NO_INDEX='1'
  $env:PIP_FIND_LINKS=$WheelDir
  $env:PIP_DISABLE_PIP_VERSION_CHECK='1'
  $env:npm_config_offline='true'
  $env:npm_config_cache=$NpmDir
  $env:TRADEYAR_OFFLINE_DEPOT=$Depot
  $script:JavaExe=Resolve-Tool 'jdk' 'java' 'java.exe' '-version' 21
  $script:MvnExe=Resolve-Tool 'maven' 'mvn' 'mvn.cmd' '--version' 3
}
function Start-ResearchServices {
  if($NoServices){Say 'Services intentionally skipped (-NoServices)';return}
  Assert-Docker
  Assert-ComposeConfig
  foreach($svc in $Services){
    $state=Get-ContainerState $svc
    if($state -match '^running\|healthy$|^running\|no-healthcheck$'){
      Say "Already running: $svc ($state)";continue
    }
    if($state -match '^running\|unhealthy$'){throw "Service $svc is UNHEALTHY; refusing to claim success or re-create it automatically"}
    Restore-Image $svc
    Say "Starting service from existing local image, with --pull never: $svc"
    & docker compose --project-name tradeyar-v063 --env-file $ComposeEnv -f $Compose up -d --pull never --no-build $svc
    Assert-Success "Offline start of $svc"
    $healthy=$false
    for($i=0;$i -lt 90;$i++){
      $s=Get-ContainerState $svc
      if($s -match '^running\|healthy$|^running\|no-healthcheck$'){$healthy=$true;break}
      if($s -match '^exited\||^dead\|'){break}
      Start-Sleep -Seconds 2
    }
    if(-not $healthy){throw "Service $svc did not reach a running/healthy state in time. State: $(Get-ContainerState $svc)"}
    Say "Service active: $svc ($s)"
  }
}
function Show-Status {
  Say "Project: $Project"
  Say "Depot: $Depot"
  Say 'Startup policy: reuse existing compatible tools + local image archives; NO online downloads'
  foreach($s in $Images.Keys){
    $arc=Join-Path $ImageDir ([string]$Images[$s].file)
    $st=if(Test-Path -LiteralPath $arc){'ARCHIVE_PRESENT'}else{'NOT_ARCHIVED'}
    Say "$s $st"
  }
  foreach($id in @('jdk','maven','node','python')){
    $dir=Join-Path $ToolDir $id
    Say "tool/${id}: $(if(Test-Path $dir){'PRESENT'}else{'NOT_CACHED'})"
  }
  Say "Local secrets file exists: $(Test-Path -LiteralPath $ComposeEnv) (contents never displayed)"
}
Ensure-Depot
switch($Mode){
  'Init' {Show-Status;Say 'Offline depot initialized. No packages downloaded.'}
  'Status' {Show-Status}
  'SeedImages' {Save-Images}
  'SeedCaches' {Seed-Caches}
  'Prepare' {Prepare-LocalTools;Start-ResearchServices;Say 'Offline startup prerequisites prepared.'}
  'Start' {
    Prepare-LocalTools
    Start-ResearchServices
    if($StartFrontend){
      $node=Resolve-Tool 'node' 'node' 'node.exe' '--version' 22
      if(-not (Test-Path -LiteralPath (Join-Path $Project 'frontend\node_modules'))){
        throw 'Offline frontend node_modules missing. Seed npm cache and run npm ci --offline manually after reviewing lockfile.'
      }
      if(-not (HasCommand 'npm')){throw 'npm executable not found; portable node archive must include npm.cmd'}
      $frontend=Join-Path $Project 'frontend'
      Say 'Starting frontend from installed local packages (npm run dev).'
      Start-Process -FilePath 'npm.cmd' -ArgumentList @('run','dev') -WorkingDirectory $frontend | Out-Null
    }
    $settings=Join-Path $Project 'infrastructure\maven\settings-central.xml'
    $globalSettings=Join-Path $Project 'infrastructure\maven\settings-empty.xml'
    foreach($file in @($settings,$globalSettings)){if(-not (Test-Path -LiteralPath $file)){throw "Maven project settings missing: $file"}}
    $pom=Join-Path $Project 'backend\app\pom.xml'
    Say 'Starting Spring Boot in FOREGROUND using Maven -o (strict offline); no dependency download.'
    & $script:MvnExe '-o' '-s' $settings '-gs' $globalSettings "-Dmaven.repo.local=$MavenDir" '-f' $pom 'org.springframework.boot:spring-boot-maven-plugin:3.5.7:run'
    Assert-Success 'Offline Spring Boot startup'
  }
}
