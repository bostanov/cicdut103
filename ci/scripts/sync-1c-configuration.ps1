# sync-1c-configuration.ps1 - Sync 1C configuration to dedicated repository
param(
    [string]$ConfigPath = "C:\1C-Configuration",
    [string]$LogFile = "C:\1C-CI-CD\logs\sync-1c-config.log"
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

try {
    Write-Log "Starting 1C configuration synchronization..."
    
    # Check if 1C configuration directory exists
    if (!(Test-Path $ConfigPath)) {
        Write-Log "1C Configuration directory not found: $ConfigPath" "ERROR"
        exit 1
    }
    
    # Set working directory
    Set-Location $ConfigPath
    
    # Set GitSync environment variables
    $env:GITSYNC_STORAGE_PATH = "file://C:/1crepository"
    $env:GITSYNC_STORAGE_USER = "gitsync"
    $env:GITSYNC_STORAGE_PASSWORD = "123"
    
    # Perform synchronization
    Write-Log "Synchronizing with 1C storage..."
    $syncResult = & gitsync sync 2>&1
    $syncOutput = $syncResult -join "`n"
    Write-Log "Sync output: $syncOutput"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Synchronization completed successfully"
        
        # Check if there are changes to commit
        $GitStatus = git status --porcelain
        if ($GitStatus) {
            Write-Log "Changes detected, committing..."
            
            # Add all changes
            git add -A
            
            # Get commit message from latest storage version
            $commitMessage = "Sync: Configuration update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            
            # Try to extract issue number from storage if available
            $storageInfo = Get-Content "ConfigDumpInfo.xml" -ErrorAction SilentlyContinue
            if ($storageInfo -match "(\d+)") {
                $issueNumber = $matches[1]
                $commitMessage += " #$issueNumber"
            }
            
            # Commit changes
            git commit -m $commitMessage
            
            # Push to GitLab
            git push origin master
            
            Write-Log "Changes committed and pushed to Git"
            
            # Trigger CI/CD pipeline in configuration repository
            Write-Log "Triggering CI/CD pipeline in configuration repository..."
            $gitlabUrl = "http://localhost:8929"
            $token = "glpat-FDN8OJN_wecgT9yV0xIBFW86MQp1OjEH.01.0w06ztagq"
            $headers = @{"PRIVATE-TOKEN" = $token}
            $projectId = 2  # 1C-Configuration project ID
            
            try {
                $body = @{ref="master"} | ConvertTo-Json
                $pipeline = Invoke-RestMethod -Uri "$gitlabUrl/api/v4/projects/$projectId/pipeline" -Headers $headers -Method Post -Body $body -ContentType "application/json"
                Write-Log "Pipeline triggered: ID=$($pipeline.id)"
            } catch {
                Write-Log "Failed to trigger pipeline: $_" "WARNING"
            }
            
            exit 0
        } else {
            Write-Log "No changes detected"
            exit 0
        }
    } else {
        Write-Log "Synchronization failed with exit code: $LASTEXITCODE" "ERROR"
        exit 1
    }
} catch {
    Write-Log "Error during synchronization: $_" "ERROR"
    exit 1
}
