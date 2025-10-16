# Main script for full CI/CD setup automation
# Author: CI/CD Automation
# Date: 2025-10-16

param(
    [string]$RepoPassword = "",
    [string]$SonarToken = "",
    [string]$RedmineApiKey = "",
    [string]$ProjectName = "ut103-ci",
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$SonarQubeUrl = "http://localhost:9000",
    [string]$RedmineUrl = "http://localhost:3000",
    [switch]$SkipManualSteps = $false,
    [switch]$Force = $false
)

# Colors for output
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"
$HeaderColor = "Magenta"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Message)
    Write-ColorOutput "`n" + "=" * 60 $HeaderColor
    Write-ColorOutput $Message $HeaderColor
    Write-ColorOutput "=" * 60 $HeaderColor
}

function Write-Step {
    param([string]$Message, [int]$StepNumber, [int]$TotalSteps)
    Write-ColorOutput "`n[STEP $StepNumber/$TotalSteps] $Message" $InfoColor
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites" 1 7
    
    $prerequisites = @{}
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        $prerequisites["Docker"] = $true
        Write-ColorOutput "Docker: $dockerVersion" $SuccessColor
    }
    catch {
        $prerequisites["Docker"] = $false
        Write-ColorOutput "Docker not installed or unavailable" $ErrorColor
    }
    
    # Check Git
    try {
        $gitVersion = git --version
        $prerequisites["Git"] = $true
        Write-ColorOutput "Git: $gitVersion" $SuccessColor
    }
    catch {
        $prerequisites["Git"] = $false
        Write-ColorOutput "Git not installed or unavailable" $ErrorColor
    }
    
    # Check PowerShell
    $prerequisites["PowerShell"] = $true
    Write-ColorOutput "PowerShell: $($PSVersionTable.PSVersion)" $SuccessColor
    
    # Check Docker containers
    try {
        $containers = docker ps --format "table {{.Names}}\t{{.Status}}"
        if ($containers -match "gitlab|sonarqube|redmine|postgres") {
            $prerequisites["Docker Containers"] = $true
            Write-ColorOutput "Docker containers running" $SuccessColor
        }
        else {
            $prerequisites["Docker Containers"] = $false
            Write-ColorOutput "Required Docker containers not running" $ErrorColor
        }
    }
    catch {
        $prerequisites["Docker Containers"] = $false
        Write-ColorOutput "Failed to check Docker containers" $ErrorColor
    }
    
    $failedPrerequisites = $prerequisites.GetEnumerator() | Where-Object { $_.Value -eq $false }
    
    if ($failedPrerequisites.Count -gt 0) {
        Write-ColorOutput "Some prerequisites not met:" $ErrorColor
        foreach ($failed in $failedPrerequisites) {
            Write-ColorOutput "   - $($failed.Key)" $ErrorColor
        }
        return $false
    }
    
    Write-ColorOutput "All prerequisites met" $SuccessColor
    return $true
}

function Wait-ForServices {
    Write-Step "Waiting for services readiness" 2 7
    
    $services = @(
        @{ Name = "GitLab"; Url = $GitLabUrl; Timeout = 300 },
        @{ Name = "SonarQube"; Url = $SonarQubeUrl; Timeout = 180 },
        @{ Name = "Redmine"; Url = $RedmineUrl; Timeout = 180 }
    )
    
    foreach ($service in $services) {
        Write-ColorOutput "Waiting for $($service.Name)..." $InfoColor
        
        $timeout = $service.Timeout
        $elapsed = 0
        
        while ($elapsed -lt $timeout) {
            try {
                $response = Invoke-WebRequest -Uri $service.Url -UseBasicParsing -TimeoutSec 5
                if ($response.StatusCode -eq 200) {
                    Write-ColorOutput "$($service.Name) ready" $SuccessColor
                    break
                }
            }
            catch {
                # Service not ready yet
            }
            
            Start-Sleep -Seconds 10
            $elapsed += 10
            Write-ColorOutput "   Waiting... ($elapsed/$timeout sec)" $InfoColor
        }
        
        if ($elapsed -ge $timeout) {
            Write-ColorOutput "$($service.Name) not ready after $timeout seconds" $WarningColor
        }
    }
}

function Get-RequiredCredentials {
    Write-Step "Getting required credentials" 3 7
    
    $credentials = @{}
    
    # Get 1C repository password
    if (-not $RepoPassword) {
        Write-ColorOutput "1C repository password required" $WarningColor
        $credentials["RepoPassword"] = Read-Host "Enter 1C repository password"
    }
    else {
        $credentials["RepoPassword"] = $RepoPassword
        Write-ColorOutput "1C repository password received" $SuccessColor
    }
    
    # Get SonarQube token
    if (-not $SonarToken) {
        Write-ColorOutput "SonarQube token required" $WarningColor
        Write-ColorOutput "1. Open: $SonarQubeUrl" $InfoColor
        Write-ColorOutput "2. Login as admin / admin" $InfoColor
        Write-ColorOutput "3. Go to: Administration -> Security -> Users -> Tokens" $InfoColor
        Write-ColorOutput "4. Create token 'CI/CD Token'" $InfoColor
        
        if (-not $SkipManualSteps) {
            Start-Process $SonarQubeUrl
            $credentials["SonarToken"] = Read-Host "Enter SonarQube token"
        }
        else {
            $credentials["SonarToken"] = ""
        }
    }
    else {
        $credentials["SonarToken"] = $SonarToken
        Write-ColorOutput "SonarQube token received" $SuccessColor
    }
    
    # Get Redmine API key
    if (-not $RedmineApiKey) {
        Write-ColorOutput "Redmine API key required" $WarningColor
        Write-ColorOutput "1. Open: $RedmineUrl" $InfoColor
        Write-ColorOutput "2. Login as admin / admin" $InfoColor
        Write-ColorOutput "3. Go to: My Account -> API access key" $InfoColor
        
        if (-not $SkipManualSteps) {
            Start-Process $RedmineUrl
            $credentials["RedmineApiKey"] = Read-Host "Enter Redmine API key"
        }
        else {
            $credentials["RedmineApiKey"] = ""
        }
    }
    else {
        $credentials["RedmineApiKey"] = $RedmineApiKey
        Write-ColorOutput "Redmine API key received" $SuccessColor
    }
    
    return $credentials
}

function Invoke-SetupScript {
    param([string]$ScriptPath, [string]$ScriptName, [hashtable]$Parameters = @{})
    
    Write-ColorOutput "Running: $ScriptName" $InfoColor
    
    try {
        $scriptPath = Join-Path $PSScriptRoot $ScriptPath
        
        if (-not (Test-Path $scriptPath)) {
            Write-ColorOutput "Script not found: $scriptPath" $ErrorColor
            return $false
        }
        
        # Prepare script parameters
        $paramString = ""
        foreach ($param in $Parameters.GetEnumerator()) {
            if ($param.Value -ne $null -and $param.Value -ne "") {
                $paramString += " -$($param.Key) `"$($param.Value)`""
            }
        }
        
        # Execute script
        $command = "& `"$scriptPath`"$paramString"
        Invoke-Expression $command
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "$ScriptName completed successfully" $SuccessColor
            return $true
        }
        else {
            Write-ColorOutput "$ScriptName failed with error code: $LASTEXITCODE" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error executing $ScriptName : $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Setup-GitLabProject {
    param([hashtable]$Credentials)
    
    Write-Step "Setting up GitLab project" 4 7
    
    # Get GitLab token
    Write-ColorOutput "GitLab token required" $WarningColor
    Write-ColorOutput "1. Open: $GitLabUrl" $InfoColor
    Write-ColorOutput "2. Login as root / Gitlab123Admin!" $InfoColor
    Write-ColorOutput "3. Go to: User Settings -> Access Tokens" $InfoColor
    Write-ColorOutput "4. Create token with rights: api, read_user, read_repository, write_repository" $InfoColor
    
    if (-not $SkipManualSteps) {
        Start-Process $GitLabUrl
        $gitlabToken = Read-Host "Enter GitLab token"
    }
    else {
        $gitlabToken = ""
    }
    
    if (-not $gitlabToken) {
        Write-ColorOutput "GitLab token not received. Skipping project setup." $WarningColor
        return $false
    }
    
    # Setup GitLab variables
    $gitlabParams = @{
        ProjectId = "root/$ProjectName"
        GitLabUrl = $GitLabUrl
        GitLabToken = $gitlabToken
        RepoPassword = $Credentials["RepoPassword"]
        SonarToken = $Credentials["SonarToken"]
        RedmineApiKey = $Credentials["RedmineApiKey"]
    }
    
    return Invoke-SetupScript -ScriptPath "setup-gitlab-variables.ps1" -ScriptName "GitLab Variables Setup" -Parameters $gitlabParams
}

function Setup-SonarQube {
    param([hashtable]$Credentials)
    
    Write-Step "Setting up SonarQube" 5 7
    
    $sonarParams = @{
        SonarQubeUrl = $SonarQubeUrl
        SonarQubeToken = $Credentials["SonarToken"]
    }
    
    return Invoke-SetupScript -ScriptPath "verify-bsl-plugin.ps1" -ScriptName "BSL Plugin Verification" -Parameters $sonarParams
}

function Setup-Redmine {
    param([hashtable]$Credentials)
    
    Write-Step "Setting up Redmine" 6 7
    
    $redmineParams = @{
        ProjectName = "UT103-CI"
        ProjectKey = "ut103"
        RedmineUrl = $RedmineUrl
        RedmineApiKey = $Credentials["RedmineApiKey"]
    }
    
    return Invoke-SetupScript -ScriptPath "setup-redmine-project.ps1" -ScriptName "Redmine Project Creation" -Parameters $redmineParams
}

function Setup-GitRepository {
    Write-Step "Setting up Git repository" 7 7
    
    $gitParams = @{
        RemoteUrl = "$GitLabUrl/root/$ProjectName.git"
        GitLabUrl = $GitLabUrl
    }
    
    return Invoke-SetupScript -ScriptPath "initial-git-setup.ps1" -ScriptName "Git Repository Setup" -Parameters $gitParams
}

function Test-FullSetup {
    Write-Header "TESTING FULL SETUP"
    
    $testParams = @{
        ProjectId = "root/$ProjectName"
        GitLabUrl = $GitLabUrl
        SonarQubeUrl = $SonarQubeUrl
        RedmineUrl = $RedmineUrl
    }
    
    return Invoke-SetupScript -ScriptPath "test-full-pipeline.ps1" -ScriptName "CI/CD Pipeline Testing" -Parameters $testParams
}

function Show-FinalInstructions {
    Write-Header "FINAL SETUP INSTRUCTIONS"
    
    Write-ColorOutput "CI/CD infrastructure setup completed!" $SuccessColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "Next steps for full activation:" $InfoColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "1. GitLab Runner Registration:" $InfoColor
    Write-ColorOutput "   - Open: $GitLabUrl" $InfoColor
    Write-ColorOutput "   - Go to: Project -> Settings -> CI/CD -> Runners" $InfoColor
    Write-ColorOutput "   - Copy Registration Token" $InfoColor
    Write-ColorOutput "   - Run: .\ci\scripts\register-runner-auto.ps1" $InfoColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "2. First Synchronization:" $InfoColor
    Write-ColorOutput "   - Ensure 1C repository is accessible" $InfoColor
    Write-ColorOutput "   - Run: .\ci\scripts\export-from-storage.ps1" $InfoColor
    Write-ColorOutput "   - Commit and push changes" $InfoColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "3. Pipeline Launch:" $InfoColor
    Write-ColorOutput "   - Open project in GitLab: $GitLabUrl/root/$ProjectName" $InfoColor
    Write-ColorOutput "   - Go to: CI/CD -> Pipelines" $InfoColor
    Write-ColorOutput "   - Click 'Run Pipeline'" $InfoColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "Useful links:" $InfoColor
    Write-ColorOutput "   - GitLab: $GitLabUrl/root/$ProjectName" $InfoColor
    Write-ColorOutput "   - SonarQube: $SonarQubeUrl" $InfoColor
    Write-ColorOutput "   - Redmine: $RedmineUrl" $InfoColor
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "Monitoring:" $InfoColor
    Write-ColorOutput "   - Pipeline status: GitLab -> CI/CD -> Pipelines" $InfoColor
    Write-ColorOutput "   - Code quality: SonarQube -> Projects" $InfoColor
    Write-ColorOutput "   - Tasks and notifications: Redmine -> Projects -> ut103" $InfoColor
}

# Main logic
Write-Header "FULL CI/CD SETUP AUTOMATION"
Write-ColorOutput "Goal: Complete CI/CD pipeline setup from 1C repository to Redmine" $InfoColor
Write-ColorOutput "Project: $ProjectName" $InfoColor

# Step 1: Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "Prerequisites not met. Exiting." $ErrorColor
    exit 1
}

# Step 2: Wait for services
Wait-ForServices

# Step 3: Get credentials
$credentials = Get-RequiredCredentials

# Step 4: Setup GitLab
$gitlabSuccess = Setup-GitLabProject -Credentials $credentials

# Step 5: Setup SonarQube
$sonarSuccess = Setup-SonarQube -Credentials $credentials

# Step 6: Setup Redmine
$redmineSuccess = Setup-Redmine -Credentials $credentials

# Step 7: Setup Git
$gitSuccess = Setup-GitRepository

# Results summary
Write-Header "SETUP RESULTS"

$results = @{
    "GitLab project" = $gitlabSuccess
    "SonarQube BSL plugin" = $sonarSuccess
    "Redmine project" = $redmineSuccess
    "Git repository" = $gitSuccess
}

$successCount = ($results.Values | Where-Object { $_ -eq $true }).Count
$totalCount = $results.Count

Write-ColorOutput "Components configured: $successCount/$totalCount" $InfoColor

foreach ($result in $results.GetEnumerator()) {
    $status = if ($result.Value) { "SUCCESS" } else { "ERROR" }
    $color = if ($result.Value) { $SuccessColor } else { $ErrorColor }
    Write-ColorOutput "  $($result.Key): $status" $color
}

# Test full setup
if ($successCount -eq $totalCount) {
    Write-ColorOutput "`nRunning full setup testing..." $InfoColor
    $testSuccess = Test-FullSetup
    
    if ($testSuccess) {
        Write-ColorOutput "All tests passed!" $SuccessColor
    }
    else {
        Write-ColorOutput "Some tests failed" $WarningColor
    }
}

# Final instructions
Show-FinalInstructions

if ($successCount -eq $totalCount) {
    Write-ColorOutput "`nCI/CD SETUP COMPLETED SUCCESSFULLY!" $SuccessColor
    Write-ColorOutput "Infrastructure ready for operation!" $SuccessColor
    exit 0
}
else {
    Write-ColorOutput "`nSETUP COMPLETED WITH ERRORS" $WarningColor
    Write-ColorOutput "Check errors above and resolve issues" $WarningColor
    exit 1
}