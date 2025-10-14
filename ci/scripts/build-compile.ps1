# build-compile.ps1 - Compile 1C configuration
param(
    [string]$Config = "ci/config/ci-settings.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Compiling 1C Configuration ===" -ForegroundColor Cyan

# Load configuration
$settings = Get-Content $Config | ConvertFrom-Json
$onecExe = Join-Path $settings.oneC.binPath "1cv8.exe"
$tempIB = $settings.oneC.tempIB

# Create temporary IB
$ibPath = Join-Path $tempIB "build_temp"
if (Test-Path $ibPath) {
    Remove-Item $ibPath -Recurse -Force
}

Write-Host "Creating temporary infobase..." -ForegroundColor Yellow
& $onecExe CREATEINFOBASE File="$ibPath" /DisableStartupDialogs /Out "$tempIB\create_build.log"

if ($LASTEXITCODE -ne 0) {
    Get-Content "$tempIB\create_build.log"
    throw "Failed to create temporary infobase"
}

# Load configuration from files
Write-Host "Loading configuration from files..." -ForegroundColor Yellow
$configPath = "config-src"

if (-not (Test-Path $configPath)) {
    throw "Configuration source not found: $configPath"
}

$loadArgs = @(
    "DESIGNER",
    "/F", "`"$ibPath`"",
    "/LoadConfigFromFiles", "`"$configPath`"",
    "/UpdateDBCfg",
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", "`"$tempIB\load_build.log`""
)

& $onecExe $loadArgs

if ($LASTEXITCODE -ne 0) {
    Get-Content "$tempIB\load_build.log"
    throw "Failed to load configuration from files"
}

# Check modules (syntax check + compile)
Write-Host "Checking modules..." -ForegroundColor Yellow
$reportsDir = "build/reports/compile"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$checkArgs = @(
    "DESIGNER",
    "/F", "`"$ibPath`"",
    "/CheckModules",
    "-ThinClient",
    "-Server",
    "-ExternalConnection",
    "-ExternalConnectionServer",
    "-ThickClientOrdinaryApplication",
    "-ThickClientManagedApplication",
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", "`"$reportsDir\check_modules.log`""
)

& $onecExe $checkArgs

$checkResult = $LASTEXITCODE

# Dump configuration to CF file
Write-Host "Creating CF file..." -ForegroundColor Yellow
$cfDir = "build/cf"
if (-not (Test-Path $cfDir)) {
    New-Item -ItemType Directory -Path $cfDir -Force | Out-Null
}

$cfFile = Join-Path $cfDir "Configuration.cf"

$dumpCfArgs = @(
    "DESIGNER",
    "/F", "`"$ibPath`"",
    "/DumpCfg", "`"$cfFile`"",
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", "`"$reportsDir\dump_cf.log`""
)

& $onecExe $dumpCfArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Failed to create CF file" -ForegroundColor Yellow
}

# Cleanup
Remove-Item $ibPath -Recurse -Force -ErrorAction SilentlyContinue

# Check compilation result
if ($checkResult -ne 0) {
    Write-Host "=== Compilation FAILED ===" -ForegroundColor Red
    Get-Content "$reportsDir\check_modules.log"
    throw "Module check failed with errors"
}

Write-Host "=== Compilation completed ===" -ForegroundColor Green
Write-Host "CF file: $cfFile" -ForegroundColor Gray

