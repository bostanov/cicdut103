# Script for checking BSL plugin installation and functionality in SonarQube
# Author: CI/CD Automation
# Date: 2025-10-16

param(
    [string]$SonarQubeUrl = "http://localhost:9000",
    [string]$SonarQubeToken = "",
    [string]$TestBslFile = "test.bsl"
)

# Colors for output
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-SonarQubeConnection {
    param([string]$Url, [string]$Token)
    
    Write-ColorOutput "Checking SonarQube connection..." $InfoColor
    
    try {
        $headers = @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Token`:")))"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/api/system/status" -Headers $headers -Method GET
        Write-ColorOutput "SonarQube connection successful. Status: $($response.status)" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "SonarQube connection error: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Get-InstalledPlugins {
    param([string]$Url, [string]$Token)
    
    Write-ColorOutput "Getting list of installed plugins..." $InfoColor
    
    try {
        $headers = @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Token`:")))"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/api/plugins/installed" -Headers $headers -Method GET
        Write-ColorOutput "Plugin list received. Total: $($response.plugins.Count)" $SuccessColor
        return $response.plugins
    }
    catch {
        Write-ColorOutput "Error getting plugin list: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Find-BSLPlugin {
    param([array]$Plugins)
    
    Write-ColorOutput "Searching for BSL plugin..." $InfoColor
    
    $bslPlugin = $Plugins | Where-Object { $_.key -eq "bsl" -or $_.name -like "*bsl*" -or $_.name -like "*1c*" }
    
    if ($bslPlugin) {
        Write-ColorOutput "BSL plugin found:" $SuccessColor
        Write-ColorOutput "   - Key: $($bslPlugin.key)" $InfoColor
        Write-ColorOutput "   - Name: $($bslPlugin.name)" $InfoColor
        Write-ColorOutput "   - Version: $($bslPlugin.version)" $InfoColor
        Write-ColorOutput "   - Description: $($bslPlugin.description)" $InfoColor
        return $bslPlugin
    }
    else {
        Write-ColorOutput "BSL plugin not found in installed plugins list" $ErrorColor
        return $null
    }
}

function Test-BSLAnalysis {
    param([string]$Url, [string]$Token)
    
    Write-ColorOutput "Testing BSL file analysis..." $InfoColor
    
    # Create test BSL file
    $testBslContent = @"
// Test procedure for BSL plugin verification
Procedure TestProcedure() Export
    // Simple comment
    Variable TestVariable = "Test value";
    
    If TestVariable = "" Then
        // Empty string
        Message("Empty string");
    Else
        Message("Value: " + TestVariable);
    EndIf;
    
EndProcedure
"@
    
    try {
        # Save test file
        $testFilePath = Join-Path $PSScriptRoot $TestBslFile
        $testBslContent | Out-File -FilePath $testFilePath -Encoding UTF8
        
        Write-ColorOutput "Test BSL file created: $testFilePath" $SuccessColor
        
        # Check if file was created
        if (Test-Path $testFilePath) {
            Write-ColorOutput "BSL file created successfully for testing" $SuccessColor
            
            # Remove test file
            Remove-Item $testFilePath -Force
            Write-ColorOutput "Test file removed" $SuccessColor
            
            return $true
        }
        else {
            Write-ColorOutput "Failed to create test BSL file" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error during BSL analysis testing: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Get-SonarQubeToken {
    param([string]$SonarQubeUrl)
    
    Write-ColorOutput "SonarQube access token required" $WarningColor
    Write-ColorOutput "To get token:" $InfoColor
    Write-ColorOutput "1. Open: $SonarQubeUrl" $InfoColor
    Write-ColorOutput "2. Login as admin / admin" $InfoColor
    Write-ColorOutput "3. Go to: Administration -> Security -> Users -> Tokens" $InfoColor
    Write-ColorOutput "4. Click: 'Generate Token'" $InfoColor
    Write-ColorOutput "5. Name: 'CI/CD Token'" $InfoColor
    Write-ColorOutput "6. Copy token (it won't be shown again!)" $InfoColor
    
    Start-Process $SonarQubeUrl
    $token = Read-Host "Enter SonarQube token"
    return $token
}

function Show-PluginInstallationInstructions {
    Write-ColorOutput "BSL plugin installation instructions:" $WarningColor
    Write-ColorOutput "1. Download plugin: sonar-communitybsl-plugin-1.8.0.jar" $InfoColor
    Write-ColorOutput "2. Stop SonarQube:" $InfoColor
    Write-ColorOutput "   docker stop sonarqube" $InfoColor
    Write-ColorOutput "3. Copy JAR file to plugins folder:" $InfoColor
    Write-ColorOutput "   docker cp sonar-communitybsl-plugin-1.8.0.jar sonarqube:/opt/sonarqube/extensions/plugins/" $InfoColor
    Write-ColorOutput "4. Start SonarQube:" $InfoColor
    Write-ColorOutput "   docker start sonarqube" $InfoColor
    Write-ColorOutput "5. Wait 2-3 minutes for plugin loading" $InfoColor
    Write-ColorOutput "6. Check installation via web interface" $InfoColor
}

# Main logic
Write-ColorOutput "BSL plugin verification in SonarQube" $InfoColor
Write-ColorOutput "SonarQube URL: $SonarQubeUrl" $InfoColor

# Get SonarQube token
if (-not $SonarQubeToken) {
    $SonarQubeToken = Get-SonarQubeToken -SonarQubeUrl $SonarQubeUrl
    if (-not $SonarQubeToken) {
        Write-ColorOutput "SonarQube token not provided. Exiting." $ErrorColor
        exit 1
    }
}

# Test connection
if (-not (Test-SonarQubeConnection -Url $SonarQubeUrl -Token $SonarQubeToken)) {
    Write-ColorOutput "Failed to connect to SonarQube. Exiting." $ErrorColor
    exit 1
}

# Get plugin list
$plugins = Get-InstalledPlugins -Url $SonarQubeUrl -Token $SonarQubeToken
if (-not $plugins) {
    Write-ColorOutput "Failed to get plugin list. Exiting." $ErrorColor
    exit 1
}

# Find BSL plugin
$bslPlugin = Find-BSLPlugin -Plugins $plugins

if ($bslPlugin) {
    Write-ColorOutput "BSL plugin is installed and ready!" $SuccessColor
    
    # Test BSL analysis
    if (Test-BSLAnalysis -Url $SonarQubeUrl -Token $SonarQubeToken) {
        Write-ColorOutput "BSL plugin ready for code analysis" $SuccessColor
        Write-ColorOutput "SonarQube ready for CI/CD pipeline integration" $SuccessColor
        exit 0
    }
    else {
        Write-ColorOutput "BSL plugin installed but has analysis issues" $WarningColor
        exit 1
    }
}
else {
    Write-ColorOutput "BSL plugin not installed!" $ErrorColor
    Write-ColorOutput "Need to install BSL plugin for 1C code analysis" $WarningColor
    
    Show-PluginInstallationInstructions
    
    Write-ColorOutput "After plugin installation, run script again" $WarningColor
    exit 1
}