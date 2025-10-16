# SonarQube Analysis Trigger Script
param(
    [string]$ProjectKey = "ut103-ci",
    [string]$LogFile = "C:\1C-CI-CD\logs\sonar-analysis.log"
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

function Trigger-SonarAnalysis {
    try {
        Write-Log "Starting SonarQube analysis..."
        
        # Load configuration
        $ConfigPath = "C:\1C-CI-CD\ci\config\ci-settings.json"
        if (!(Test-Path $ConfigPath)) {
            Write-Log "Configuration file not found: $ConfigPath" "ERROR"
            return $false
        }
        
        $Config = Get-Content $ConfigPath | ConvertFrom-Json
        
        # Set working directory
        Set-Location "C:\1C-CI-CD"
        
        # Check if SonarQube scanner is available
        $SonarScannerPath = "C:\Tools\sonar-scanner\bin\sonar-scanner.bat"
        if (!(Test-Path $SonarScannerPath)) {
            Write-Log "SonarQube scanner not found at: $SonarScannerPath" "ERROR"
            return $false
        }
        
        # Prepare SonarQube properties
        $SonarProperties = @{
            "sonar.projectKey" = $ProjectKey
            "sonar.projectName" = "1C UT 10.3 CI/CD"
            "sonar.projectVersion" = "1.0"
            "sonar.host.url" = $Config.sonarQube.url
            "sonar.login" = $Config.sonarQube.token
            "sonar.sources" = "."
            "sonar.exclusions" = "**/node_modules/**,**/externals/**,**/logs/**,**/build/**"
            "sonar.bsl.plugin.version" = "1.0.0"
        }
        
        # Create sonar-project.properties file
        $PropertiesContent = @()
        foreach ($Key in $SonarProperties.Keys) {
            $PropertiesContent += "$Key=$($SonarProperties[$Key])"
        }
        $PropertiesContent | Out-File -FilePath "sonar-project.properties" -Encoding UTF8
        
        Write-Log "SonarQube properties configured"
        
        # Run SonarQube analysis
        Write-Log "Running SonarQube analysis..."
        & $SonarScannerPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SonarQube analysis completed successfully"
            
            # Get analysis results
            $SonarUrl = "$($Config.sonarQube.url)/dashboard?id=$ProjectKey"
            Write-Log "Analysis results available at: $SonarUrl"
            
            # Check quality gate status
            Start-Sleep -Seconds 10
            $QualityGateResult = Get-QualityGateStatus -ProjectKey $ProjectKey -SonarUrl $Config.sonarQube.url -Token $Config.sonarQube.token
            
            if ($QualityGateResult -eq "PASSED") {
                Write-Log "Quality Gate: PASSED ✓" "SUCCESS"
            } else {
                Write-Log "Quality Gate: FAILED ✗" "WARNING"
            }
            
            return $true
        } else {
            Write-Log "SonarQube analysis failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during SonarQube analysis: $_" "ERROR"
        return $false
    }
}

function Get-QualityGateStatus {
    param(
        [string]$ProjectKey,
        [string]$SonarUrl,
        [string]$Token
    )
    
    try {
        $Headers = @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Token`:")))"
        }
        
        $Response = Invoke-RestMethod -Uri "$SonarUrl/api/qualitygates/project_status?projectKey=$ProjectKey" -Headers $Headers
        
        return $Response.projectStatus.status
    }
    catch {
        Write-Log "Error getting quality gate status: $_" "ERROR"
        return "UNKNOWN"
    }
}

# Main execution
Write-Log "SonarQube Analysis Trigger started"
$Result = Trigger-SonarAnalysis

if ($Result) {
    Write-Log "SonarQube analysis completed successfully" "SUCCESS"
    exit 0
} else {
    Write-Log "SonarQube analysis failed" "ERROR"
    exit 1
}
