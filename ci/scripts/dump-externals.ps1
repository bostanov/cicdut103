# dump-externals.ps1 - Dump external processors/reports to XML
param(
    [string]$Config = "ci/config/ci-settings.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Dump External Processors/Reports ===" -ForegroundColor Cyan

# Load configuration
$settings = Get-Content $Config | ConvertFrom-Json
$onecExe = Join-Path $settings.oneC.binPath "1cv8.exe"
$tempIB = $settings.oneC.tempIB

# Find all external files
$externalsPath = "externals"
$externalsSourcePath = "externals-src"

if (-not (Test-Path $externalsPath)) {
    Write-Host "No externals directory found, skipping" -ForegroundColor Yellow
    exit 0
}

$externalFiles = Get-ChildItem -Path $externalsPath -Include *.epf,*.erf -Recurse

if ($externalFiles.Count -eq 0) {
    Write-Host "No external files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($externalFiles.Count) external files" -ForegroundColor Gray

# Create output directory
if (-not (Test-Path $externalsSourcePath)) {
    New-Item -ItemType Directory -Path $externalsSourcePath -Force | Out-Null
}

# Create temporary IB
$ibPath = Join-Path $tempIB "externals_temp"
if (Test-Path $ibPath) {
    Remove-Item $ibPath -Recurse -Force
}

Write-Host "Creating temporary infobase..." -ForegroundColor Yellow
& $onecExe CREATEINFOBASE File="$ibPath" /DisableStartupDialogs /Out "$tempIB\create_ext.log"

# Dump each external file
foreach ($file in $externalFiles) {
    $relativePath = $file.FullName.Substring((Resolve-Path $externalsPath).Path.Length + 1)
    $outputDir = Join-Path $externalsSourcePath ($file.BaseName)
    
    Write-Host "Dumping: $relativePath" -ForegroundColor Gray
    
    if (Test-Path $outputDir) {
        Remove-Item $outputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    
    $dumpArgs = @(
        "DESIGNER",
        "/F", "`"$ibPath`"",
        "/DumpExternalDataProcessorOrReportToFiles", "`"$($file.FullName)`"", "`"$outputDir`"",
        "/DisableStartupDialogs",
        "/DisableStartupMessages",
        "/Out", "`"$tempIB\dump_$($file.BaseName).log`""
    )
    
    & $onecExe $dumpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: Failed to dump $relativePath" -ForegroundColor Yellow
    }
}

# Cleanup
Remove-Item $ibPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "=== Dump completed ===" -ForegroundColor Green
Write-Host "External sources dumped to: $externalsSourcePath" -ForegroundColor Gray

