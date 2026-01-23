<#
.SYNOPSIS
    Creates an Azure DevOps pull request from the current branch.

.DESCRIPTION
    Uses Azure CLI to create a pull request in Azure DevOps.
    Extracts organization, project, and repository from the git remote URL.
    Optionally links a work item to the PR.

.PARAMETER Title
    The title of the pull request (commit message).

.PARAMETER Description
    The description/body of the pull request (filled PR template).
    Cannot be used together with DescriptionFile.

.PARAMETER DescriptionFile
    Path to a file containing the PR description.
    Cannot be used together with Description.

.PARAMETER SourceBranch
    The source branch name. Defaults to current branch.

.PARAMETER TargetBranch
    The target branch name. Defaults to 'master'.

.PARAMETER WorkItemId
    Optional work item ID to link to the PR.

.OUTPUTS
    PSCustomObject with PR details: PullRequestId, Url, Title, WorkItemId

.EXAMPLE
    .\New-PullRequest.ps1 -Title "Add retry logic" -Description "## Type`n- [x] Bug fix"

.EXAMPLE
    .\New-PullRequest.ps1 -Title "Add retry logic" -DescriptionFile ".ai/pullrequests/my-branch.md"

.EXAMPLE
    .\New-PullRequest.ps1 -Title "Add retry logic" -DescriptionFile ".ai/pullrequests/my-branch.md" -WorkItemId 12345
#>

param(
    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory, ParameterSetName = 'InlineDescription')]
    [string]$Description,

    [Parameter(Mandatory, ParameterSetName = 'FileDescription')]
    [string]$DescriptionFile,

    [Parameter()]
    [string]$SourceBranch,

    [Parameter()]
    [string]$TargetBranch = "master",

    [Parameter()]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

#region Prerequisites Check

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed. Install from: https://aka.ms/installazurecliwindows"
}

# Check if azure-devops extension is installed
$extensions = az extension list --only-show-errors 2>$null | ConvertFrom-Json
if (-not ($extensions | Where-Object { $_.name -eq 'azure-devops' })) {
    Write-Host "Installing Azure DevOps extension..." -ForegroundColor Yellow
    az extension add --name azure-devops --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Azure DevOps extension. Run: az extension add --name azure-devops"
    }
}

# Verify we're in a git repository
if (-not (Test-Path .git) -and -not (git rev-parse --git-dir 2>$null)) {
    throw "Not in a git repository. Please run from a git repository root."
}

#endregion

#region Extract Remote Info

# Get the remote URL
$remoteUrl = git remote get-url origin 2>$null
if (-not $remoteUrl) {
    throw "No 'origin' remote configured. Please add a remote first."
}

Write-Host "Remote URL: $remoteUrl" -ForegroundColor Cyan

# Parse Azure DevOps URL formats:
# HTTPS: https://dev.azure.com/{org}/{project}/_git/{repo}
# HTTPS with username: https://{username}@dev.azure.com/{org}/{project}/_git/{repo}

$org = $null
$project = $null
$repo = $null

if ($remoteUrl -match 'https://(?:[^@]+@)?dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)') {
    $org = $Matches[1]
    $project = $Matches[2]
    $repo = $Matches[3]
}
else {
    throw "Unsupported remote URL format. Expected: https://dev.azure.com/{org}/{project}/_git/{repo}"
}

# Clean up repo name (remove .git suffix if present)
$repo = $repo -replace '\.git$', ''

Write-Host "Organization: $org" -ForegroundColor Cyan
Write-Host "Project: $project" -ForegroundColor Cyan
Write-Host "Repository: $repo" -ForegroundColor Cyan

#endregion

#region Get Current Branch

if (-not $SourceBranch) {
    $SourceBranch = git branch --show-current
    if (-not $SourceBranch) {
        throw "Could not determine current branch. Are you in detached HEAD state?"
    }
}

Write-Host "Source Branch: $SourceBranch" -ForegroundColor Cyan
Write-Host "Target Branch: $TargetBranch" -ForegroundColor Cyan

# Validate we're not on the target branch
if ($SourceBranch -eq $TargetBranch) {
    throw "Source and target branches are the same ($SourceBranch). Please switch to a feature branch."
}

#endregion

#region Push Branch

Write-Host "`nEnsuring branch is pushed to origin..." -ForegroundColor Yellow

# Check if branch exists on remote
$remoteBranch = git ls-remote --heads origin $SourceBranch 2>$null
if (-not $remoteBranch) {
    Write-Host "Pushing branch to origin..." -ForegroundColor Yellow
    git push -u origin $SourceBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push branch to origin."
    }
}
else {
    # Push any new commits
    git push origin $SourceBranch 2>$null
}

#endregion

#region Resolve Description

# If DescriptionFile is provided, read the content from the file
if ($DescriptionFile) {
    if (-not (Test-Path $DescriptionFile)) {
        throw "Description file not found: $DescriptionFile"
    }
    Write-Host "Reading description from file: $DescriptionFile" -ForegroundColor Cyan
    $Description = Get-Content -Path $DescriptionFile -Raw
}

#endregion

#region Create Pull Request

Write-Host "`nCreating pull request..." -ForegroundColor Yellow

$orgUrl = "https://dev.azure.com/$org"

# Write description to temp file to handle special characters
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    # Ensure proper encoding for the description
    $Description | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

    # Build the base command arguments
    $prArgs = @(
        'repos', 'pr', 'create',
        '--org', $orgUrl,
        '--project', $project,
        '--repository', $repo,
        '--source-branch', $SourceBranch,
        '--target-branch', $TargetBranch,
        '--title', $Title,
        '--description', "@$tempFile",
        '--only-show-errors'
    )

    # Add work item if provided
    if ($WorkItemId -gt 0) {
        Write-Host "Linking work item #$WorkItemId..." -ForegroundColor Yellow
        $prArgs += '--work-items'
        $prArgs += $WorkItemId.ToString()
    }

    # Create the PR using Azure CLI
    $prJson = & az @prArgs

    if ($LASTEXITCODE -ne 0 -or -not $prJson) {
        throw "Failed to create pull request. Ensure you're logged in (az login) and have permissions."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

$pr = $prJson | ConvertFrom-Json

#endregion

#region Output Result

$prUrl = "https://dev.azure.com/$org/$project/_git/$repo/pullrequest/$($pr.pullRequestId)"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Pull Request Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "PR #$($pr.pullRequestId): $($pr.title)" -ForegroundColor White
Write-Host "URL: $prUrl" -ForegroundColor Cyan
if ($WorkItemId -gt 0) {
    Write-Host "Linked Work Item: #$WorkItemId" -ForegroundColor Cyan
}
Write-Host "========================================`n" -ForegroundColor Green

# Return structured object
[PSCustomObject]@{
    PullRequestId = $pr.pullRequestId
    Title         = $pr.title
    Url           = $prUrl
    SourceBranch  = $SourceBranch
    TargetBranch  = $TargetBranch
    Status        = $pr.status
    WorkItemId    = if ($WorkItemId -gt 0) { $WorkItemId } else { $null }
}

#endregion
