<#
.SYNOPSIS
    Fetches Azure DevOps pull request information.

.PARAMETER PullRequestUrl
    Azure DevOps PR URL. Supports both formats:
    - https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}
    - https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}

.OUTPUTS
    PSCustomObject with PR details: PullRequestId, Title, Author, SourceBranch, TargetBranch, Description
#>

param(
    [Parameter(Mandatory)]
    [string]$PullRequestUrl
)

$ErrorActionPreference = 'Stop'

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed. Install from: https://aka.ms/installazurecliwindows"
}

# Check if azure-devops extension is installed
$extensions = az extension list --only-show-errors 2>$null | ConvertFrom-Json
if (-not ($extensions | Where-Object { $_.name -eq 'azure-devops' })) {
    throw "Azure DevOps extension not installed. Run: az extension add --name azure-devops"
}

# Strip query params and parse PR URL
$cleanUrl = $PullRequestUrl -replace '\?.*$', ''

# Determine org URL and PR ID from supported URL formats
$org = $null
$prId = $null

if ($cleanUrl -match 'https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)/pullrequest/(\d+)$') {
    # Format: https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}
    $org = $Matches[1]
    $orgUrl = "https://dev.azure.com/$org"
    $prId = $Matches[4]
}
elseif ($cleanUrl -match 'https://([^.]+)\.visualstudio\.com/([^/]+)/_git/([^/]+)/pullrequest/(\d+)$') {
    # Format: https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}
    $org = $Matches[1]
    $orgUrl = "https://$org.visualstudio.com"
    $prId = $Matches[4]
}
else {
    throw "Invalid PR URL format. Expected:`n  https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}`n  https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}"
}

Write-Host "Fetching PR #$prId from $orgUrl ..." -ForegroundColor Cyan

# Use Azure CLI for authentication
$prJson = az repos pr show --id $prId --org $orgUrl --only-show-errors
if ($LASTEXITCODE -ne 0 -or -not $prJson) {
    throw "Failed to fetch PR #$prId. Ensure you're logged in (az login)."
}
$pr = $prJson | ConvertFrom-Json

# Output PR info
[PSCustomObject]@{
    PullRequestId = $pr.pullRequestId
    Title         = $pr.title
    Author        = $pr.createdBy.displayName
    SourceBranch  = $pr.sourceRefName -replace '^refs/heads/', ''
    TargetBranch  = $pr.targetRefName -replace '^refs/heads/', ''
    Description   = $pr.description
}
