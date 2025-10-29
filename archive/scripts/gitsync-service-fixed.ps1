# GitSync Service Fixed Script
$LogFile = "C:\1C-CI-CD\logs\gitsync-service-fixed.log"
$SyncIntervalMinutes = 10

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Write initial log entry
Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] GitSync Service Script Started" -Encoding UTF8

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Initialize-Environment {
    try {
        Write-Log "Initializing environment"
        
        # Set working directory
        Set-Location "C:\1C-CI-CD"
        Write-Log "Working directory: $(Get-Location)"
        
        # Set environment variables - CRITICAL: Must be done before any GitSync calls
        $env:REPO_PWD = "123"
        $env:GITSYNC_STORAGE_PATH = "file://C:/1crepository"
        $env:GITSYNC_WORKDIR = "."
        $env:GITSYNC_STORAGE_USER = "gitsync"
        $env:GITSYNC_STORAGE_PASSWORD = $env:REPO_PWD
        $env:GITSYNC_V8VERSION = "8.3.12.1714"
        $env:GITSYNC_V8_PATH = "C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe"
        $env:GITSYNC_TEMP = "C:/Temp/1C-CI-CD/ib"
        
        Write-Log "Environment variables set:"
        Write-Log "  REPO_PWD: $env:REPO_PWD"
        Write-Log "  GITSYNC_STORAGE_PATH: $env:GITSYNC_STORAGE_PATH"
        Write-Log "  GITSYNC_STORAGE_USER: $env:GITSYNC_STORAGE_USER"
        Write-Log "  GITSYNC_V8_PATH: $env:GITSYNC_V8_PATH"
        
        # Ensure temp directory exists
        if (!(Test-Path $env:GITSYNC_TEMP)) {
            New-Item -ItemType Directory -Path $env:GITSYNC_TEMP -Force | Out-Null
            Write-Log "Created temp directory: $env:GITSYNC_TEMP"
        }
        
        Write-Log "Environment initialized successfully"
        return $true
    } catch {
        Write-Log "Error initializing environment: $_" "ERROR"
        return $false
    }
}

function Start-SyncLoop {
    Write-Log "Starting sync loop"
    
    while ($true) {
        try {
            Write-Log "Starting synchronization cycle"
            
            # Initialize environment EVERY time
            if (!(Initialize-Environment)) {
                Write-Log "Environment initialization failed" "ERROR"
                Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
                continue
            }
            
            # Test GitSync availability
            Write-Log "Testing GitSync availability"
            $gitsyncTest = & gitsync --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "GitSync test successful: $gitsyncTest"
            } else {
                Write-Log "GitSync test failed: $gitsyncTest" "ERROR"
                Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
                continue
            }
            
            # Run GitSync
            Write-Log "Executing GitSync sync"
            $syncResult = & gitsync sync -R -F -P -G -l 5 2>&1
            $output = $syncResult -join "`n"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Synchronization completed successfully"
                Write-Log "Output: $output"
            } else {
                Write-Log "Synchronization failed with exit code: $LASTEXITCODE" "ERROR"
                Write-Log "Output: $output" "ERROR"
            }
            
        } catch {
            Write-Log "Error in synchronization cycle: $_" "ERROR"
        }
        
        Write-Log "Waiting $SyncIntervalMinutes minutes before next sync"
        Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
    }
}

# Main execution
try {
    Write-Log "GitSync Service Fixed Script starting"
    Write-Log "Script path: $($MyInvocation.MyCommand.Path)"
    Write-Log "Current user: $env:USERNAME"
    Write-Log "Current directory: $(Get-Location)"
    Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"
    
    Start-SyncLoop
    
} catch {
    Write-Log "Fatal error in service: $_" "ERROR"
    Write-Log "Error details: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
