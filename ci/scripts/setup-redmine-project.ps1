# Script for automatic Redmine project creation
# Author: CI/CD Automation
# Date: 2025-10-16

param(
    [string]$ProjectName = "UT103-CI",
    [string]$ProjectKey = "ut103",
    [string]$ProjectDescription = "CI/CD project for UT103",
    [string]$RedmineUrl = "http://localhost:3000",
    [string]$RedmineApiKey = "",
    [switch]$SkipManualSteps = $false
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

function Test-RedmineConnection {
    param([string]$Url, [string]$ApiKey)
    
    Write-ColorOutput "Checking Redmine connection..." $InfoColor
    
    try {
        $headers = @{
            "X-Redmine-API-Key" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/users/current.json" -Headers $headers -Method GET
        Write-ColorOutput "Redmine connection successful. User: $($response.user.login)" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "Redmine connection error: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Get-RedmineProjects {
    param([string]$Url, [string]$ApiKey)
    
    Write-ColorOutput "Getting project list..." $InfoColor
    
    try {
        $headers = @{
            "X-Redmine-API-Key" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/projects.json" -Headers $headers -Method GET
        Write-ColorOutput "Project list received. Total: $($response.projects.Count)" $SuccessColor
        return $response.projects
    }
    catch {
        Write-ColorOutput "Error getting project list: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Find-RedmineProject {
    param([array]$Projects, [string]$ProjectKey)
    
    Write-ColorOutput "Searching for project: $ProjectKey" $InfoColor
    
    $project = $Projects | Where-Object { $_.identifier -eq $ProjectKey }
    
    if ($project) {
        Write-ColorOutput "Project found:" $SuccessColor
        Write-ColorOutput "   - ID: $($project.id)" $InfoColor
        Write-ColorOutput "   - Name: $($project.name)" $InfoColor
        Write-ColorOutput "   - Identifier: $($project.identifier)" $InfoColor
        Write-ColorOutput "   - Description: $($project.description)" $InfoColor
        return $project
    }
    else {
        Write-ColorOutput "Project with identifier '$ProjectKey' not found" $ErrorColor
        return $null
    }
}

function New-RedmineProject {
    param(
        [string]$Name,
        [string]$Identifier,
        [string]$Description,
        [string]$Url,
        [string]$ApiKey
    )
    
    Write-ColorOutput "Creating project: $Name" $InfoColor
    
    try {
        $headers = @{
            "X-Redmine-API-Key" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        $body = @{
            project = @{
                name = $Name
                identifier = $Identifier
                description = $Description
                is_public = $false
                enabled_module_names = @("issue_tracking", "time_tracking", "news", "documents", "wiki", "files")
                trackers = @(
                    @{ name = "Bug"; is_in_changelog = $true },
                    @{ name = "Feature"; is_in_changelog = $true },
                    @{ name = "Support"; is_in_changelog = $false }
                )
                issue_custom_field_ids = @()
            }
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri "$Url/projects.json" -Headers $headers -Method POST -Body $body
        Write-ColorOutput "Project '$Name' created successfully. ID: $($response.project.id)" $SuccessColor
        return $response.project
    }
    catch {
        Write-ColorOutput "Error creating project: $($_.Exception.Message)" $ErrorColor
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-ColorOutput "Error details: $responseBody" $ErrorColor
        }
        return $null
    }
}

function Set-RedmineProjectSettings {
    param(
        [int]$ProjectId,
        [string]$Url,
        [string]$ApiKey
    )
    
    Write-ColorOutput "Setting up additional project parameters..." $InfoColor
    
    try {
        $headers = @{
            "X-Redmine-API-Key" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        # Setup issue statuses
        $statuses = @("New", "In Progress", "Resolved", "Feedback", "Closed", "Rejected")
        foreach ($status in $statuses) {
            try {
                $statusBody = @{
                    issue_status = @{
                        name = $status
                        is_closed = ($status -eq "Closed" -or $status -eq "Rejected")
                        is_default = ($status -eq "New")
                    }
                } | ConvertTo-Json
                
                $statusResponse = Invoke-RestMethod -Uri "$Url/issue_statuses.json" -Headers $headers -Method POST -Body $statusBody
                Write-ColorOutput "Status '$status' created" $SuccessColor
            }
            catch {
                Write-ColorOutput "Status '$status' already exists or creation error" $WarningColor
            }
        }
        
        return $true
    }
    catch {
        Write-ColorOutput "Error setting up project parameters: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Get-RedmineApiKey {
    param([string]$RedmineUrl)
    
    Write-ColorOutput "Redmine API key required" $WarningColor
    Write-ColorOutput "To get API key:" $InfoColor
    Write-ColorOutput "1. Open: $RedmineUrl" $InfoColor
    Write-ColorOutput "2. Login as admin / admin" $InfoColor
    Write-ColorOutput "3. Go to: My Account -> API access key" $InfoColor
    Write-ColorOutput "4. Copy API key" $InfoColor
    
    if (-not $SkipManualSteps) {
        Start-Process $RedmineUrl
        $apiKey = Read-Host "Enter Redmine API key"
        return $apiKey
    }
    else {
        Write-ColorOutput "Skipping manual API key input (SkipManualSteps = true)" $WarningColor
        return ""
    }
}

function Show-ProjectInfo {
    param([object]$Project, [string]$RedmineUrl)
    
    Write-ColorOutput "Project information:" $InfoColor
    Write-ColorOutput "   - Name: $($Project.name)" $InfoColor
    Write-ColorOutput "   - Identifier: $($Project.identifier)" $InfoColor
    Write-ColorOutput "   - ID: $($Project.id)" $InfoColor
    Write-ColorOutput "   - Description: $($Project.description)" $InfoColor
    Write-ColorOutput "   - URL: $RedmineUrl/projects/$($Project.identifier)" $InfoColor
    Write-ColorOutput "   - Access: $(if ($Project.is_public) { 'Public' } else { 'Private' })" $InfoColor
}

# Main logic
Write-ColorOutput "Creating Redmine project" $InfoColor
Write-ColorOutput "Project name: $ProjectName" $InfoColor
Write-ColorOutput "Identifier: $ProjectKey" $InfoColor
Write-ColorOutput "Redmine URL: $RedmineUrl" $InfoColor

# Get Redmine API key
if (-not $RedmineApiKey) {
    $RedmineApiKey = Get-RedmineApiKey -RedmineUrl $RedmineUrl
    if (-not $RedmineApiKey) {
        Write-ColorOutput "Redmine API key not provided. Exiting." $ErrorColor
        exit 1
    }
}

# Test connection
if (-not (Test-RedmineConnection -Url $RedmineUrl -ApiKey $RedmineApiKey)) {
    Write-ColorOutput "Failed to connect to Redmine. Exiting." $ErrorColor
    exit 1
}

# Get project list
$projects = Get-RedmineProjects -Url $RedmineUrl -ApiKey $RedmineApiKey
if (-not $projects) {
    Write-ColorOutput "Failed to get project list. Exiting." $ErrorColor
    exit 1
}

# Find existing project
$existingProject = Find-RedmineProject -Projects $projects -ProjectKey $ProjectKey

if ($existingProject) {
    Write-ColorOutput "Project already exists!" $SuccessColor
    Show-ProjectInfo -Project $existingProject -RedmineUrl $RedmineUrl
    Write-ColorOutput "Project ready for CI/CD pipeline usage" $SuccessColor
    exit 0
}
else {
    Write-ColorOutput "Creating new project..." $InfoColor
    
    # Create project
    $newProject = New-RedmineProject -Name $ProjectName -Identifier $ProjectKey -Description $ProjectDescription -Url $RedmineUrl -ApiKey $RedmineApiKey
    
    if ($newProject) {
        Write-ColorOutput "Project created successfully!" $SuccessColor
        Show-ProjectInfo -Project $newProject -RedmineUrl $RedmineUrl
        
        # Setup additional parameters
        if (Set-RedmineProjectSettings -ProjectId $newProject.id -Url $RedmineUrl -ApiKey $RedmineApiKey) {
            Write-ColorOutput "Additional settings applied" $SuccessColor
        }
        else {
            Write-ColorOutput "Failed to apply additional settings" $WarningColor
        }
        
        Write-ColorOutput "Project ready for CI/CD pipeline usage" $SuccessColor
        Write-ColorOutput "Open project: $RedmineUrl/projects/$ProjectKey" $InfoColor
        exit 0
    }
    else {
        Write-ColorOutput "Failed to create project. Check logs above." $ErrorColor
        exit 1
    }
}