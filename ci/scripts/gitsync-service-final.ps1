# GitSync Service Final Script
param(
    [string]$Action = "start"
)

$LogFile = "C:\1C-CI-CD\logs\gitsync-service-final.log"
$SyncIntervalMinutes = 10

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    Write-Host $LogEntry
}

function Initialize-Environment {
    try {
        Write-Log "Initializing environment"
        
        # Set working directory
        Set-Location "C:\1C-CI-CD"
        
        # Set environment variables
        $env:REPO_PWD = "123"
        $env:GITSYNC_STORAGE_PATH = "file://C:/1crepository"
        $env:GITSYNC_WORKDIR = "C:\1C-CI-CD"
        $env:GITSYNC_STORAGE_USER = "gitsync"
        $env:GITSYNC_STORAGE_PASSWORD = $env:REPO_PWD
        $env:GITSYNC_V8VERSION = "8.3.12.1714"
        $env:GITSYNC_V8_PATH = "C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe"
        $env:GITSYNC_TEMP = "C:/Temp/1C-CI-CD/ib"
        $env:GITSYNC_RENAME_MODULE = "true"
        $env:GITSYNC_RENAME_FORM = "true"
        $env:GITSYNC_PROJECT_NAME = "ut103-ci"
        $env:GITSYNC_WORKSPACE_LOCATION = "C:/1C-CI-CD"
        $env:GITSYNC_LIMIT = "5"
        
        # Ensure temp directory exists
        if (!(Test-Path $env:GITSYNC_TEMP)) {
            New-Item -ItemType Directory -Path $env:GITSYNC_TEMP -Force | Out-Null
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
            
            # Initialize environment
            if (!(Initialize-Environment)) {
                Write-Log "Environment initialization failed" "ERROR"
                Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
                continue
            }
            
            # Run GitSync
            Write-Log "Executing GitSync sync"
            $syncResult = & "C:\Program Files\OneScript\bin\gitsync.bat" sync 2>&1
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
    Write-Log "GitSync Service Final Script starting"
    Write-Log "Action: $Action"
    
    if ($Action -eq "start") {
        Start-SyncLoop
    } else {
        Write-Log "Service action: $Action"
    }
    
} catch {
    Write-Log "Fatal error in service: $_" "ERROR"
    exit 1
}

