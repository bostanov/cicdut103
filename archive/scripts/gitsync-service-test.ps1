# Simple test script for GitSync service
$LogFile = "C:\1C-CI-CD\logs\gitsync-service-test.log"

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

Write-Log "GitSync Service Test Script Started"

# Test basic functionality
Write-Log "Current directory: $(Get-Location)"
Write-Log "Current user: $env:USERNAME"

# Test GitSync availability
try {
    $gitsyncVersion = & gitsync --version 2>&1
    Write-Log "GitSync version: $gitsyncVersion"
} catch {
    Write-Log "GitSync not available: $_"
}

# Test environment
Write-Log "Environment variables:"
Write-Log "REPO_PWD: $env:REPO_PWD"
Write-Log "GITSYNC_STORAGE_PATH: $env:GITSYNC_STORAGE_PATH"

Write-Log "Test completed - service script is working"
