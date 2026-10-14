#requires -Version 5.1
<#
TradeYar managed startup / dependency recovery for Windows PowerShell 5.1.
No arbitrary web execution; HTTP downloads require an operator-approved policy,
explicit allowlisted HTTPS URL, and a pinned SHA-256 in dependencies.lock.json.
Existing Windows services may be started only if explicitly named and approved.
MT5 is NEVER logged into an account or used for order submission by this script.
#>
[CmdletBinding()]
param(
    [ValidateSet('Check','Enroll','Repair','Launch')][string]$Mode = 'Check',
    [string]$ProjectPath = '',
    [switch]$ApproveDownloads,
    [switch]$ApproveServiceStart,
    [switch]$ApproveNpmInstall,
    [switch]$ApproveSignedInstallers,
    [switch]$StartFrontend
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $Self = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($Self)) {throw 'Script location is unknown; pass -ProjectPath.'}
    $ProjectPath = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($Self)) '..'))
}
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {throw 'Project folder does not exist.'}
$Root = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $Root 'backend\app\pom.xml'))) {throw 'Not a TradeYar project.'}
$Runtime = Join-Path $Root '.tradeyar-runtime'
$PolicyPath = Join-Path $Runtime 'bootstrap-policy.json'
$LockPath = Join-Path $Root 'infrastructure\bootstrap\dependencies.lock.json'
$LogPath = Join-Path $Runtime 'logs\bootstrap.log'
if (-not (Test-Path -LiteralPath $LockPath)) {throw 'Pinned dependency lock file is missing.'}
$Lock = Get-Content -LiteralPath $LockPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Lock.schemaVersion -ne 1) {throw 'Unsupported dependency lock schema.'}
$ExpectedPackages = @('node','python','postgresql','redis','mt5','maven','jdk')
function Report([string]$Phase,[string]$Id,[string]$Message) {
    $line = '[BOOTSTRAP] [{0}] {1}: {2}' -f $Phase,$Id,$Message
    Write-Host $line
    try {
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path -LiteralPath $logDir)) {New-Item -ItemType Directory -Path $logDir -Force | Out-Null}
        Add-Content -LiteralPath $LogPath -Value ('{0} {1}' -f (Get-Date -Format o),$line) -Encoding UTF8
    } catch {Write-Warning 'File logging unavailable; console status remains visible.'}
}
function Read-Policy {
    if (-not (Test-Path -LiteralPath $PolicyPath)) {return $null}
    try {
        $p = Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($p.schemaVersion -ne 1) {throw 'Unexpected approval policy version'}
        return $p
    } catch {throw 'Local approval policy invalid. Repair aborted; re-enroll intentionally.'}
}
function Command-Exists([string]$command) {return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)}
function Find-ManagedBinary([string]$id,[string]$exe) {
    $dir = Join-Path (Join-Path $Runtime 'tools') $id
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {return $null}
    $candidates = @(Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $exe})
    if ($candidates.Count -eq 0) {return $null}
    return $candidates[0].FullName
}
function Read-Status {
    $py = (Command-Exists 'py') -or (Command-Exists 'python') -or (Find-ManagedBinary 'python' 'python.exe')
    $checks = @(
        [pscustomobject]@{Id='JAVA'; State=$(if((Command-Exists 'java') -or (Find-ManagedBinary 'jdk' 'java.exe')){'FOUND'}else{'MISSING'}); Notes='Required to run backend; Java 21 required'},
        [pscustomobject]@{Id='NODE'; State=$(if((Command-Exists 'node') -or (Find-ManagedBinary 'node' 'node.exe')){'FOUND'}else{'MISSING'}); Notes='Optional UI development server'},
        [pscustomobject]@{Id='NPM'; State=$(if((Command-Exists 'npm') -or (Find-ManagedBinary 'node' 'npm.cmd')){'FOUND'}else{'MISSING'}); Notes='For npm ci / Vite'},
        [pscustomobject]@{Id='PYTHON'; State=$(if($py){'FOUND'}else{'MISSING'}); Notes='Read-only MT5 scripts / optional AI service'},
        [pscustomobject]@{Id='PSQL_CLI'; State=$(if(Command-Exists 'psql'){'FOUND'}else{'NOT_ON_PATH'}); Notes='PostgreSQL command line client (optional)'},
        [pscustomobject]@{Id='PG_DSN'; State=$(if([string]::IsNullOrWhiteSpace($env:TRADEYAR_PG_DSN)){'NOT_CONFIGURED'}else{'CONFIGURED'}); Notes='Secret is NEVER printed'},
        [pscustomobject]@{Id='MT5_PATH'; State=$(if(-not [string]::IsNullOrWhiteSpace($env:TRADEYAR_MT5_PATH) -and (Test-Path -LiteralPath $env:TRADEYAR_MT5_PATH -PathType Leaf)){'INSTALLED'}else{'NOT_CONFIGURED'}); Notes='MT5 optional; read-only bridge requires a logged-in terminal'}
    )
    foreach ($item in $checks) {Report 'CHECK' $item.Id ($item.State + ' | ' + $item.Notes)}
    foreach ($svc in @($Lock.services)) {
        $id = [string]$svc.id
        if ($id -notin @('postgresql','redis')) {throw "Unsupported managed service identifier: $id"}
        $serviceName = [string]$svc.windowsServiceName
        if ([string]::IsNullOrWhiteSpace($serviceName)) {Report 'CHECK' $id 'NOT_CONFIGURED (no approved Windows service name)';continue}
        if ($serviceName -notmatch '^[A-Za-z0-9_.-]{1,120}$') {throw "Invalid service name for $id"}
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {Report 'CHECK' $id 'NOT_INSTALLED';continue}
        Report 'CHECK' $id ('Windows service: ' + $service.Status)
    }
}
function Get-PinnedPackage([string]$id) {
    $packages = @($Lock.packages | Where-Object { $_.id -eq $id })
    if ($packages.Count -gt 1) {throw "Duplicate package id: $id"}
    if ($packages.Count -eq 0) {return $null}
    return $packages[0]
}
function Install-Pinned([string]$id,$policy) {
    if ($id -notin $ExpectedPackages) {throw "Package not on allowlist: $id"}
    $package = Get-PinnedPackage $id
    if ($null -eq $package) {Report 'SKIP' $id 'No administrator-pinned artifact; automatic download unavailable';return}
    $url = [string]$package.url
    $hash = [string]$package.sha256
    $type = [string]$package.type
    if ($url -notmatch '^https://' -or $hash -notmatch '^[0-9a-fA-F]{64}$' -or $type -notin @('zip','exe','msi')) {
        Report 'SKIP' $id 'Missing valid HTTPS URL / fixed SHA-256 / supported type in local lock file'
        return
    }
    $uri = [uri]$url
    $allowedHosts = @('nodejs.org','www.python.org','python.org','api.adoptium.net','adoptium.net','www.postgresql.org','postgresql.org','download.postgresql.org','get.enterprisedb.com','www.enterprisedb.com','www.metatrader5.com','metatrader5.com','repo.maven.apache.org','downloads.apache.org','www.apache.org')
    if ($uri.Host -notin $allowedHosts -or $uri.UserInfo) {throw "Host not on official download allowlist for $id"}
    if (-not $policy.approveDownloads) {Report 'SKIP' $id 'One-time local download consent not enrolled';return}
    $pkgDir = Join-Path $Runtime ('packages\'+$id)
    $destination = Join-Path $pkgDir ($hash.ToLowerInvariant()+'.'+$type)
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $actual=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($actual -ine $hash) {
            Report 'WARN' $id 'Cached artifact SHA-256 incorrect; discard invalid cache'
            Remove-Item -LiteralPath $destination -Force
        } else {Report 'CACHE' $id 'Verified SHA-256; network request avoided'}
    }
    if (-not (Test-Path -LiteralPath $destination)) {
        $partial=$destination+'.part'
        if(Test-Path -LiteralPath $partial){Remove-Item -LiteralPath $partial -Force}
        Report 'DOWNLOAD' $id ('Approved official host: '+$uri.Host)
        try {
            Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing -TimeoutSec 90
            if((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ine $hash){throw 'Downloaded SHA-256 differs from pinned hash; refusing execution'}
            Move-Item -LiteralPath $partial -Destination $destination -Force
        } finally {
            if(Test-Path -LiteralPath $partial){Remove-Item -LiteralPath $partial -Force}
        }
        Report 'VERIFY' $id 'SHA-256 verified against operator-pinned artifact'
    }
    if($type -eq 'zip') {
        $installDir = Join-Path $Runtime ('tools\'+$id)
        $marker = Join-Path $installDir ('.installed-'+$hash.ToLowerInvariant())
        if((Test-Path -LiteralPath $marker) -and @(Get-ChildItem -LiteralPath $installDir -Recurse -File | Where-Object {$_.FullName -ne $marker}).Count -gt 0){Report 'READY' $id 'Cached extraction already installed';return}
        if(Test-Path -LiteralPath $installDir){Remove-Item -LiteralPath $installDir -Recurse -Force}
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($destination,$installDir)
        New-Item -ItemType File -Path $marker -Force | Out-Null
        Report 'READY' $id 'Verified local ZIP extracted into project runtime tools'
        return
    }
    if(-not $policy.approveSignedInstallers) {Report 'SKIP' $id 'Signed installer staged, but installer execution was not approved';return}
    $signature=Get-AuthenticodeSignature -FilePath $destination
    if($signature.Status -ne 'Valid') {throw "Authenticode signature invalid for $id"}
    $publisher = [string]$package.publisherContains
    if ([string]::IsNullOrWhiteSpace($publisher) -or $signature.SignerCertificate.Subject -notlike ('*'+$publisher+'*')) {
        throw "Installer signer does not match expected publisher for $id"
    }
    $args = @($package.installArgs | ForEach-Object {[string]$_})
    Report 'INSTALL' $id 'Executing signed, pinned installer with approved arguments (may require Windows UAC)'
    if($type -eq 'msi') {
        $run=Start-Process -FilePath "$env:WINDIR\System32\msiexec.exe" -ArgumentList (@('/i',$destination)+$args) -Wait -PassThru
    } else {
        $run=Start-Process -FilePath $destination -ArgumentList $args -Wait -PassThru
    }
    if($run.ExitCode -notin @(0,3010)) {throw "Installer for $id exited with code $($run.ExitCode)"}
    Report 'READY' $id ('Official signed installer completed; exit code '+$run.ExitCode)
}
function Repair-Services($policy) {
    foreach($svc in @($Lock.services)) {
        $id=[string]$svc.id;$name=[string]$svc.windowsServiceName
        if([string]::IsNullOrWhiteSpace($name)){continue}
        if($name -notmatch '^[A-Za-z0-9_.-]{1,120}$'){throw "Invalid service name for $id"}
        $service=Get-Service -Name $name -ErrorAction SilentlyContinue
        if($null -eq $service){Report 'SKIP' $id 'Configured Windows service not installed';continue}
        if($service.Status -eq 'Running'){Report 'READY' $id 'Already running; no restart';continue}
        if(-not $policy.approveServiceStart){Report 'SKIP' $id 'Service start not approved in local policy';continue}
        try {
            Start-Service -Name $name -ErrorAction Stop
            Report 'START' $id 'Windows service started; credentials and schema not verified'
        } catch {Report 'WARN' $id ('Cannot start service with current Windows privileges: '+$_.Exception.Message)}
    }
}
function Repair-Components($policy) {
    Report 'REPAIR' 'POLICY' 'Using local enrollment; no secrets or credentials are printed'
    if(-not (Command-Exists 'node') -and -not (Find-ManagedBinary 'node' 'node.exe')){Install-Pinned 'node' $policy}
    if(-not ((Command-Exists 'py') -or (Command-Exists 'python') -or (Find-ManagedBinary 'python' 'python.exe'))){Install-Pinned 'python' $policy}
    if(-not (Command-Exists 'java') -and -not (Find-ManagedBinary 'jdk' 'java.exe')){Install-Pinned 'jdk' $policy;Report 'WARN' 'JAVA' 'If installed while running IntelliJ, restart the IDE to update its Java runtime configuration'}
    if(-not (Command-Exists 'psql')){Install-Pinned 'postgresql' $policy}
    # Redis and MT5 downloads are never automatic: service/license/account setup require separate review.
    Repair-Services $policy
    # Make verified local tools visible to processes launched by this shell.
    foreach ($pair in @(@('node','node.exe'),@('python','python.exe'),@('jdk','java.exe'),@('maven','mvn.cmd'))) {
        $bin=Find-ManagedBinary $pair[0] $pair[1]
        if($bin){
            $directory=Split-Path -Parent $bin
            if(-not (($env:PATH -split ';') -contains $directory)){$env:PATH=$directory+';'+$env:PATH}
        }
    }
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    $nodeLocal = Find-ManagedBinary 'node' 'node.exe'
    if($null -eq $npm -and $nodeLocal){
        $npmLocal=Find-ManagedBinary 'node' 'npm.cmd'
        if($npmLocal){$npm=Get-Item -LiteralPath $npmLocal}
    }
    $modules=Join-Path $Root 'frontend\node_modules'
    if(-not (Test-Path -LiteralPath $modules -PathType Container)) {
        if(-not $policy.approveNpmInstall) {Report 'SKIP' 'FRONTEND' 'node_modules missing; npm ci requires explicit approval';return}
        if(-not $npm) {Report 'SKIP' 'FRONTEND' 'npm missing';return}
        if(-not (Test-Path -LiteralPath (Join-Path $Root 'frontend\package-lock.json'))) {throw 'npm lock file missing; refusing unlocked installation'}
        $npmExe=if($npm -is [System.IO.FileInfo]){$npm.FullName}else{$npm.Source}
        Report 'INSTALL' 'FRONTEND' 'npm ci with package-lock integrity checks and project-local cache'
        Push-Location (Join-Path $Root 'frontend')
        try {
            $env:npm_config_cache=Join-Path $Runtime 'npm-cache'
            & $npmExe ci --prefer-offline --no-audit --no-fund
            if($LASTEXITCODE -ne 0) {throw 'npm ci failed'}
        } finally {Pop-Location}
        Report 'READY' 'FRONTEND' 'npm dependencies installed'
    }else {Report 'READY' 'FRONTEND' 'node_modules already available'}
}
if($Mode -eq 'Enroll') {
    New-Item -ItemType Directory -Path $Runtime -Force | Out-Null
    $policy=[ordered]@{schemaVersion=1; approvedAtUtc=[DateTime]::UtcNow.ToString('o');approveDownloads=[bool]$ApproveDownloads;approveServiceStart=[bool]$ApproveServiceStart;approveNpmInstall=[bool]$ApproveNpmInstall;approveSignedInstallers=[bool]$ApproveSignedInstallers}
    $policy | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $PolicyPath -Encoding UTF8
    Report 'ENROLL' 'POLICY' 'Operator choices saved locally, never in Git. Download approvals do not bypass checksums'
    Report 'ENROLL' 'INTELLIJ' 'Add TRADEYAR_AUTO_REPAIR_ON_STARTUP=true in Run Configuration after reviewing policy'
    exit 0
}
Read-Status
if($Mode -eq 'Check'){exit 0}
$policy=Read-Policy
if($null -eq $policy){Report 'SKIP' 'POLICY' 'Not enrolled. Run -Mode Enroll with explicitly approved options first';if($Mode -eq 'Launch'){Report 'LAUNCH' 'BACKEND' 'Continuing without provisioning'}else{exit 0}}
else {Repair-Components $policy}
if($Mode -eq 'Launch') {
    if($StartFrontend){
        $npm=Get-Command npm -ErrorAction SilentlyContinue
        if($null -ne $npm -and (Test-Path -LiteralPath (Join-Path $Root 'frontend\node_modules'))){
            $frontendPath=Join-Path $Root 'frontend'
            $cmd='Set-Location -LiteralPath '+("'"+$frontendPath.Replace("'","''")+"'")+'; npm run dev'
            Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-NoExit','-Command',('"'+$cmd+'"')) | Out-Null
            Report 'LAUNCH' 'FRONTEND' 'Frontend terminal started'
        }else {Report 'SKIP' 'FRONTEND' 'npm or node_modules unavailable'}
    }
    $maven=Join-Path $Root 'scripts\Invoke-TradeYar-Maven.ps1'
    if(-not(Test-Path -LiteralPath $maven)){throw 'Project Maven launcher is missing'}
    Report 'LAUNCH' 'BACKEND' 'Launching Spring Boot in this console; its [BOOTSTRAP] messages will also appear in IntelliJ when launched there'
    & $maven -Goal Start
    if($LASTEXITCODE -ne 0){throw "Spring Boot exited with code $LASTEXITCODE"}
}
