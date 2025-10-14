# lint-bsl.ps1 - BSL syntax checking with precommit1c
param(
    [string]$Config = "ci/config/ci-settings.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== BSL Linting (precommit1c) ===" -ForegroundColor Cyan

# Check if precommit1c is installed
$precommit1c = Get-Command precommit1c -ErrorAction SilentlyContinue
if (-not $precommit1c) {
    throw "precommit1c not found. Install with: pip install precommit1c"
}

# Create reports directory
$reportsDir = "build/reports/precommit1c"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

# Run precommit1c
$precommit1cConfig = "ci/config/precommit1c.json"
$sourcePath = "config-src"

if (-not (Test-Path $sourcePath)) {
    Write-Host "No config-src directory found, skipping" -ForegroundColor Yellow
    exit 0
}

Write-Host "Running precommit1c on $sourcePath..." -ForegroundColor Yellow

$reportFile = Join-Path $reportsDir "precommit1c-report.xml"

try {
    precommit1c check-bsl `
        --path $sourcePath `
        --config $precommit1cConfig `
        --junit-report $reportFile `
        --verbose
    
    Write-Host "=== Linting completed ===" -ForegroundColor Green
} catch {
    Write-Host "=== Linting found issues ===" -ForegroundColor Red
    throw "BSL linting failed. Check report: $reportFile"
}

