# Precommit1C Service Worker - Monitors external files directory
param(
    [int]$CheckIntervalSeconds = 30,
    [string]$LogFile = "C:\1C-CI-CD\logs\precommit1c-service.log"
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

function Process-ExternalFile {
    param([string]$FilePath)
    
    try {
        Write-Log "Processing external file: $FilePath"
        
        $FileName = Split-Path $FilePath -Leaf
        $FileDir = Split-Path $FilePath -Parent
        
        # Create processed directory
        $ProcessedDir = Join-Path $FileDir "processed"
        if (!(Test-Path $ProcessedDir)) {
            New-Item -ItemType Directory -Path $ProcessedDir -Force | Out-Null
        }
        
        # Create sources directory
        $SourcesDir = Join-Path $FileDir "sources"
        if (!(Test-Path $SourcesDir)) {
            New-Item -ItemType Directory -Path $SourcesDir -Force | Out-Null
        }
        
        # Determine file type and extract sources
        $FileExtension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        switch ($FileExtension) {
            ".epf" {
                Write-Log "Processing EPF file: $FileName"
                # Extract EPF to sources
                $ExtractScript = @"
# Extract EPF file
`$EpfPath = "$FilePath"
`$ExtractDir = "$SourcesDir\$([System.IO.Path]::GetFileNameWithoutExtension(`$FileName))"
if (!(Test-Path `$ExtractDir)) {
    New-Item -ItemType Directory -Path `$ExtractDir -Force | Out-Null
}

# Use 1C platform to extract EPF
`$PlatformPath = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8.exe"
if (Test-Path `$PlatformPath) {
    & `$PlatformPath /C"`$EpfPath" /Extract"`$ExtractDir"
    Write-Log "EPF extracted to: `$ExtractDir"
} else {
    Write-Log "1C Platform not found for EPF extraction" "WARNING"
}
"@
                Invoke-Expression $ExtractScript
            }
            ".erf" {
                Write-Log "Processing ERF file: $FileName"
                # Extract ERF to sources
                $ExtractScript = @"
# Extract ERF file
`$ErfPath = "$FilePath"
`$ExtractDir = "$SourcesDir\$([System.IO.Path]::GetFileNameWithoutExtension(`$FileName))"
if (!(Test-Path `$ExtractDir)) {
    New-Item -ItemType Directory -Path `$ExtractDir -Force | Out-Null
}

# Use 1C platform to extract ERF
`$PlatformPath = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8.exe"
if (Test-Path `$PlatformPath) {
    & `$PlatformPath /C"`$ErfPath" /Extract"`$ExtractDir"
    Write-Log "ERF extracted to: `$ExtractDir"
} else {
    Write-Log "1C Platform not found for ERF extraction" "WARNING"
}
"@
                Invoke-Expression $ExtractScript
            }
            ".bsl" {
                Write-Log "Processing BSL file: $FileName"
                # Copy BSL file to sources
                $SourcePath = Join-Path $SourcesDir $FileName
                Copy-Item $FilePath $SourcePath -Force
                Write-Log "BSL file copied to sources: $SourcePath"
            }
            ".txt" {
                Write-Log "Processing TXT file: $FileName"
                # Copy TXT file to sources
                $SourcePath = Join-Path $SourcesDir $FileName
                Copy-Item $FilePath $SourcePath -Force
                Write-Log "TXT file copied to sources: $SourcePath"
            }
            default {
                Write-Log "Unknown file type: $FileExtension" "WARNING"
                # Copy unknown file to sources
                $SourcePath = Join-Path $SourcesDir $FileName
                Copy-Item $FilePath $SourcePath -Force
                Write-Log "Unknown file copied to sources: $SourcePath"
            }
        }
        
        # Move original file to processed directory
        $ProcessedPath = Join-Path $ProcessedDir $FileName
        Move-Item $FilePath $ProcessedPath -Force
        Write-Log "File moved to processed: $ProcessedPath"
        
        # Commit sources to Git
        Set-Location "C:\1C-CI-CD"
        $GitStatus = git status --porcelain
        if ($GitStatus) {
            Write-Log "Committing extracted sources to Git..."
            git add -A
            git commit -m "Auto-commit: Processed external file $FileName"
            git push origin master
            Write-Log "Sources committed and pushed to Git"
            
            # Trigger SonarQube analysis
            Write-Log "Triggering SonarQube analysis for new sources..."
            & "C:\1C-CI-CD\ci\scripts\trigger-sonar-analysis.ps1"
        }
        
        return $true
    }
    catch {
        Write-Log "Error processing file $FilePath : $_" "ERROR"
        return $false
    }
}

function Monitor-ExternalFiles {
    try {
        $ExternalDir = "C:\1C-CI-CD\externals"
        if (!(Test-Path $ExternalDir)) {
            New-Item -ItemType Directory -Path $ExternalDir -Force | Out-Null
            Write-Log "Created external files directory: $ExternalDir"
            return
        }
        
        # Get all files in external directory
        $Files = Get-ChildItem -Path $ExternalDir -File -Recurse | Where-Object { $_.Extension -match '\.(epf|erf|bsl|txt)$' }
        
        foreach ($File in $Files) {
            $Processed = Process-ExternalFile -FilePath $File.FullName
            if ($Processed) {
                Write-Log "Successfully processed: $($File.Name)"
            } else {
                Write-Log "Failed to process: $($File.Name)" "ERROR"
            }
        }
    }
    catch {
        Write-Log "Error in monitoring cycle: $_" "ERROR"
    }
}

# Main service loop
Write-Log "Precommit1C Service started (Check interval: $CheckIntervalSeconds seconds)"

while ($true) {
    try {
        Monitor-ExternalFiles
    }
    catch {
        Write-Log "Error in main loop: $_" "ERROR"
    }
    
    # Wait for next check
    Start-Sleep -Seconds $CheckIntervalSeconds
}
