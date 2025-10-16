# GitSync Service Worker - Runs continuously to sync 1C storage with Git
param(
    [int]$SyncIntervalMinutes = 5,
    [string]$LogFile = "C:\1C-CI-CD\logs\gitsync-service.log"
)

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Sync-1CStorage {
    try {
        Write-Log "Starting 1C storage synchronization..."
        
        # Load configuration
        $ConfigPath = "C:\1C-CI-CD\ci\config\ci-settings.json"
        if (!(Test-Path $ConfigPath)) {
            Write-Log "Configuration file not found: $ConfigPath" "ERROR"
            return $false
        }
        
        $Config = Get-Content $ConfigPath | ConvertFrom-Json
        
        # Set working directory
        Set-Location "C:\1C-CI-CD"
        
        # Check if GitSync is available
        $GitSyncPath = "C:\Tools\gitsync\gitsync.exe"
        if (!(Test-Path $GitSyncPath)) {
            Write-Log "GitSync not found at: $GitSyncPath" "ERROR"
            return $false
        }
        
        # Initialize GitSync if needed
        $GitSyncConfig = "C:\1C-CI-CD\.gitsync"
        if (!(Test-Path $GitSyncConfig)) {
            Write-Log "Initializing GitSync..."
            & $GitSyncPath init --storage $Config.repository.url --user $Config.repository.user --password $Config.repository.passwordEnv
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to initialize GitSync" "ERROR"
                return $false
            }
        }
        
        # Perform synchronization
        Write-Log "Synchronizing with 1C storage..."
        & $GitSyncPath sync --storage $Config.repository.url --user $Config.repository.user --password $Config.repository.passwordEnv
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Synchronization completed successfully"
            
            # Check if there are changes to commit
            $GitStatus = git status --porcelain
            if ($GitStatus) {
                Write-Log "Changes detected, committing..."
                git add -A
                git commit -m "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                git push origin master
                Write-Log "Changes committed and pushed to Git"
                
                # Trigger SonarQube analysis
                Write-Log "Triggering SonarQube analysis..."
                & "C:\1C-CI-CD\ci\scripts\trigger-sonar-analysis.ps1"
                
                return $true
            } else {
                Write-Log "No changes detected"
                return $false
            }
        } else {
            Write-Log "Synchronization failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during synchronization: $_" "ERROR"
        return $false
    }
}

# Main service loop
Write-Log "GitSync Service started (Interval: $SyncIntervalMinutes minutes)"

while ($true) {
    try {
        $SyncResult = Sync-1CStorage
        if ($SyncResult) {
            Write-Log "Sync cycle completed with changes"
        } else {
            Write-Log "Sync cycle completed (no changes)"
        }
    }
    catch {
        Write-Log "Error in sync cycle: $_" "ERROR"
    }
    
    # Wait for next sync
    Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
}
