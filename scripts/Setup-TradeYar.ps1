param([switch]$InstallDependencies)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

$Tools = @("java", "mvn", "node", "npm", "python")

foreach ($Tool in $Tools) {
    if (Get-Command $Tool -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $Tool" -ForegroundColor Green
    } else {
        Write-Warning "$Tool is not installed or not on PATH"
    }
}

if ($InstallDependencies) {
    if (Get-Command mvn -ErrorAction SilentlyContinue) {
        Push-Location (Join-Path $Root "backend")
        try {
            mvn clean package -DskipTests
            if ($LASTEXITCODE -ne 0) {
                throw "Maven build failed"
            }
        } finally {
            Pop-Location
        }
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Push-Location (Join-Path $Root "frontend")
        try {
            npm install
            if ($LASTEXITCODE -ne 0) {
                throw "npm install failed"
            }
        } finally {
            Pop-Location
        }
    }

    if (Get-Command python -ErrorAction SilentlyContinue) {
        Push-Location (Join-Path $Root "python/ai-service")
        try {
            python -m venv .venv

            & ".\.venv\Scripts\python.exe" -m pip install -r requirements.txt

            if ($LASTEXITCODE -ne 0) {
                throw "Python dependencies failed"
            }
        } finally {
            Pop-Location
        }
    }
}

Write-Host "TradeYar setup finished" -ForegroundColor Cyan