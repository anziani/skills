<#
.SYNOPSIS
    Posts code review comments to an Azure DevOps pull request.

.DESCRIPTION
    Reads a JSON file containing review comments and posts them as comment threads
    on the specified pull request using the Azure DevOps REST API.

.PARAMETER PullRequestUrl
    Azure DevOps PR URL. Supports both formats:
    - https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}
    - https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}

.PARAMETER CommentsFile
    Path to a JSON file containing an array of comment objects. Each object must have:
      - filePath:  (string) File path relative to repo root, prefixed with /
      - line:      (int)    Line number in the right-side diff to attach the comment
      - content:   (string) Markdown comment body
    Optional fields:
      - status:    (int)    Thread status (1=Active, 2=Fixed, 3=WontFix, 4=Closed, 5=ByDesign, 6=Pending). Default: 1

.PARAMETER CommentNumbers
    Optional comma-separated list of 1-based comment indices to post (e.g. "1,3,5").
    If omitted, all comments in the file are posted.

.EXAMPLE
    .\Post-ReviewComments.ps1 -PullRequestUrl "https://dev.azure.com/org/project/_git/repo/pullrequest/123" -CommentsFile ".ai/code-reviews/comments-123.json"

.EXAMPLE
    .\Post-ReviewComments.ps1 -PullRequestUrl "https://dev.azure.com/org/project/_git/repo/pullrequest/123" -CommentsFile ".ai/code-reviews/comments-123.json" -CommentNumbers "1,2,4"
#>

param(
    [Parameter(Mandatory)]
    [string]$PullRequestUrl,

    [Parameter(Mandatory)]
    [string]$CommentsFile,

    [string]$CommentNumbers
)

$ErrorActionPreference = 'Stop'

# --- Validate prerequisites ---
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed. Install from: https://aka.ms/installazurecliwindows"
}

if (-not (Test-Path $CommentsFile)) {
    throw "Comments file not found: $CommentsFile"
}

# --- Parse PR URL ---
$cleanUrl = $PullRequestUrl -replace '\?.*$', ''

$orgUrl = $null
$project = $null
$repoId = $null
$prId = $null

if ($cleanUrl -match 'https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)/pullrequest/(\d+)$') {
    $orgUrl = "https://dev.azure.com/$($Matches[1])"
    $project = $Matches[2]
    $repoId = $Matches[3]
    $prId = [int]$Matches[4]
}
elseif ($cleanUrl -match 'https://([^.]+)\.visualstudio\.com/([^/]+)/_git/([^/]+)/pullrequest/(\d+)$') {
    $orgUrl = "https://dev.azure.com/$($Matches[1])"
    $project = $Matches[2]
    $repoId = $Matches[3]
    $prId = [int]$Matches[4]
}
else {
    throw "Invalid PR URL format. Expected:`n  https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}`n  https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}"
}

# --- Get access token ---
$token = az account get-access-token --resource '499b84ac-1321-427f-aa17-267ca6975798' --query accessToken -o tsv
if (-not $token) {
    throw "Failed to get access token. Ensure you're logged in (az login)."
}

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
}

$baseUri = "$orgUrl/$project/_apis/git/repositories/$repoId/pullRequests/$prId/threads?api-version=7.1"

# --- Load comments ---
$allComments = Get-Content $CommentsFile -Raw | ConvertFrom-Json

if ($allComments.Count -eq 0) {
    Write-Host "No comments found in $CommentsFile" -ForegroundColor Yellow
    exit 0
}

# --- Filter by comment numbers if specified ---
$selectedComments = @()
if ($CommentNumbers) {
    $indices = $CommentNumbers -split ',' | ForEach-Object { [int]$_.Trim() }
    foreach ($idx in $indices) {
        if ($idx -lt 1 -or $idx -gt $allComments.Count) {
            Write-Warning "Comment number $idx is out of range (1-$($allComments.Count)). Skipping."
            continue
        }
        $selectedComments += $allComments[$idx - 1]
    }
}
else {
    $selectedComments = $allComments
}

if ($selectedComments.Count -eq 0) {
    Write-Host "No comments selected to post." -ForegroundColor Yellow
    exit 0
}

Write-Host "Posting $($selectedComments.Count) comment(s) to PR #$prId..." -ForegroundColor Cyan

# --- Post each comment ---
$posted = 0
$failed = 0

foreach ($comment in $selectedComments) {
    $status = if ($comment.status) { $comment.status } else { 1 }  # Default: Active

    $threadBody = @{
        comments = @(
            @{
                parentCommentId = 0
                content         = $comment.content
                commentType     = 1
            }
        )
        status        = $status
        threadContext = @{
            filePath       = $comment.filePath
            rightFileStart = @{ line = $comment.line; offset = 1 }
            rightFileEnd   = @{ line = $comment.line; offset = 2 }
        }
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        $response = Invoke-RestMethod -Uri $baseUri -Method Post -Headers $headers -Body $threadBody
        $posted++
        Write-Host "  Posted on $($comment.filePath):$($comment.line) - Thread ID: $($response.id)" -ForegroundColor Green
    }
    catch {
        $failed++
        Write-Host "  FAILED on $($comment.filePath):$($comment.line): $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails) { Write-Host "    $($_.ErrorDetails.Message)" -ForegroundColor Red }
    }
}

Write-Host "`nDone. Posted: $posted, Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
