# export-from-storage.ps1 - Export 1C configuration from storage to Git
param(
    [string]$Config = "ci/config/ci-settings.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Export from 1C Storage ===" -ForegroundColor Cyan

# Load configuration
if (-not (Test-Path $Config)) {
    throw "Configuration file not found: $Config"
}

$settings = Get-Content $Config | ConvertFrom-Json

# Paths
$onecBin = $settings.oneC.binPath
$onecExe = Join-Path $onecBin "1cv8.exe"
$repoUrl = $settings.repository.url
$repoUser = $settings.repository.user
$repoPwd = $env:REPO_PWD

if (-not (Test-Path $onecExe)) {
    throw "1C executable not found: $onecExe"
}

# Create temporary IB
$tempIB = $settings.oneC.tempIB
if (-not (Test-Path $tempIB)) {
    New-Item -ItemType Directory -Path $tempIB -Force | Out-Null
}

$ibPath = Join-Path $tempIB "export_temp"
if (Test-Path $ibPath) {
    Remove-Item $ibPath -Recurse -Force
}

Write-Host "Creating temporary infobase..." -ForegroundColor Yellow
& $onecExe CREATEINFOBASE File="$ibPath" /DisableStartupDialogs /Out "$tempIB\create.log"
if ($LASTEXITCODE -ne 0) {
    Get-Content "$tempIB\create.log"
    throw "Failed to create temporary infobase"
}

# Load configuration from storage
Write-Host "Loading configuration from storage..." -ForegroundColor Yellow
$loadArgs = @(
    "DESIGNER",
    "/F", "`"$ibPath`"",
    "/ConfigurationRepositoryF", "`"$repoUrl`"",
    "/ConfigurationRepositoryN", $repoUser,
    "/ConfigurationRepositoryP", $repoPwd,
    "/ConfigurationRepositoryUpdateCfg",
    "-force",
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", "`"$tempIB\load.log`""
)

& $onecExe $loadArgs
if ($LASTEXITCODE -ne 0) {
    Get-Content "$tempIB\load.log"
    throw "Failed to load configuration from storage"
}

# Dump configuration to files
Write-Host "Dumping configuration to files..." -ForegroundColor Yellow
$dumpPath = "config-src"
if (-not (Test-Path $dumpPath)) {
    New-Item -ItemType Directory -Path $dumpPath -Force | Out-Null
}

$dumpArgs = @(
    "DESIGNER",
    "/F", "`"$ibPath`"",
    "/DumpConfigToFiles", "`"$dumpPath`"",
    "-format", "Hierarchical",
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", "`"$tempIB\dump.log`""
)

& $onecExe $dumpArgs
if ($LASTEXITCODE -ne 0) {
    Get-Content "$tempIB\dump.log"
    throw "Failed to dump configuration to files"
}

# Cleanup
Write-Host "Cleaning up..." -ForegroundColor Yellow
Remove-Item $ibPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "=== Export completed ===" -ForegroundColor Green
Write-Host "Configuration exported to: $dumpPath" -ForegroundColor Gray

