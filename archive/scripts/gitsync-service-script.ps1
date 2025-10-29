# GitSync Service Script - Working Version
$LogFile = "C:\1C-CI-CD\logs\gitsync-service.log"
$SyncIntervalMinutes = 10

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-ServiceLog {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Initialize-GitSyncEnvironment {
    try {
        Write-ServiceLog "Initializing GitSync environment"
        
        # Set environment variables
        $env:REPO_PWD = "123"
        $env:GITSYNC_STORAGE_PATH = "file://C:/1crepository"
        $env:GITSYNC_WORKDIR = "."
        $env:GITSYNC_STORAGE_USER = "gitsync"
        $env:GITSYNC_STORAGE_PASSWORD = $env:REPO_PWD
        $env:GITSYNC_V8VERSION = "8.3.12.1714"
        $env:GITSYNC_V8_PATH = "C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe"
        $env:GITSYNC_TEMP = "C:/Temp/1C-CI-CD/ib"
        
        # Ensure temp directory exists
        if (!(Test-Path $env:GITSYNC_TEMP)) {
            New-Item -ItemType Directory -Path $env:GITSYNC_TEMP -Force | Out-Null
        }
        
        Write-ServiceLog "Environment initialized successfully"
        return $true
    } catch {
        Write-ServiceLog "Error initializing environment: $_" "ERROR"
        return $false
    }
}

function Start-GitSyncLoop {
    Write-ServiceLog "Starting GitSync service loop"
    
    # Change to working directory
    Set-Location "C:\1C-CI-CD"
    
    while ($true) {
        try {
            Write-ServiceLog "Starting synchronization cycle"
            
            # Initialize environment
            if (!(Initialize-GitSyncEnvironment)) {
                Write-ServiceLog "Environment initialization failed" "ERROR"
                Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
                continue
            }
            
            # Run GitSync with all plugins enabled
            Write-ServiceLog "Executing GitSync sync with plugins"
            
            # Use direct command execution
            $syncResult = & gitsync sync -R -F -P -G -l 5 2>&1
            $output = $syncResult -join "`n"
            
            if ($LASTEXITCODE -eq 0) {
                Write-ServiceLog "Synchronization completed successfully"
                Write-ServiceLog "Output: $output"
            } else {
                Write-ServiceLog "Synchronization failed with exit code: $LASTEXITCODE" "ERROR"
                Write-ServiceLog "Output: $output" "ERROR"
            }
            
        } catch {
            Write-ServiceLog "Error in synchronization cycle: $_" "ERROR"
        }
        
        Write-ServiceLog "Waiting $SyncIntervalMinutes minutes before next sync"
        Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
    }
}

# Main execution
try {
    Write-ServiceLog "GitSync Service starting"
    Start-GitSyncLoop
} catch {
    Write-ServiceLog "Fatal error in service: $_" "ERROR"
    exit 1
}
