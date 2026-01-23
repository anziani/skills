<#
.SYNOPSIS
    Fetches active (unresolved) PR comments from Azure DevOps.
.PARAMETER PullRequestUrl
    Azure DevOps PR URL (e.g., https://dev.azure.com/msft-twc/Sonar/_git/Sonar-Core/pullrequest/12345)
.OUTPUTS
    JSON object with PR details and active comment threads.
#>
param(
    [Parameter(Mandatory)]
    [string]$PullRequestUrl
)

$ErrorActionPreference = 'Stop'
$AzureDevOpsResource = '499b84ac-1321-427f-aa17-267ca6975798'

# Validate Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI not installed. Install from: https://aka.ms/installazurecliwindows"
}

# Parse PR URL
$cleanUrl = $PullRequestUrl -replace '\?.*$', ''
if ($cleanUrl -notmatch 'https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)/pullrequest/(\d+)$') {
    throw "Invalid PR URL. Expected: https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}"
}
$org, $project, $repo, $prId = $Matches[1..4]

Write-Host "Fetching comments for PR #$prId..." -ForegroundColor Cyan

# Helper to call Azure DevOps REST API
function Invoke-AzDoApi($url) {
    $response = az rest --method get --url $url --resource $AzureDevOpsResource 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed. Run 'az login'. Error: $response" }
    $response | ConvertFrom-Json
}

# Fetch PR and threads
$baseApiUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repo/pullrequests/$prId"
$pr = Invoke-AzDoApi "$baseApiUrl`?api-version=7.1"
$threads = (Invoke-AzDoApi "$baseApiUrl/threads?api-version=7.1").value

# Filter active threads (unresolved with actionable comments)
$activeThreads = $threads | Where-Object {
    $_.status -eq 'active' -and $_.comments.Count -gt 0 -and
    ($_.threadContext -or $_.comments[0].commentType -eq 'text')
}

if (-not $activeThreads) {
    Write-Host "No active comments found." -ForegroundColor Yellow
    return "[]"
}

# Helper to truncate text to ~100 chars at word boundary
function Get-Summary($text, $maxLen = 100) {
    $clean = ($text -replace '[\r\n]+', ' ').Trim()
    if ($clean.Length -le $maxLen) { return $clean }
    $truncated = $clean.Substring(0, $maxLen)
    $lastSpace = $truncated.LastIndexOf(' ')
    if ($lastSpace -gt 50) { $truncated = $truncated.Substring(0, $lastSpace) }
    "$truncated..."
}

# Helper to extract plain text from system comments (AI Code Review)
function Get-PlainContent($comment) {
    $content = $comment.content
    if ($comment.commentType -eq 'system' -and $content -match '(?s)</small>\s*\n\s*\n(.+?)(?:\nHere is the suggested code:|<table|\n```)') {
        return $Matches[1].Trim()
    }
    $content
}

# Build result
$baseUrl = "https://dev.azure.com/$org/$project/_git/$repo/pullrequest/$prId"
$result = @{
    PullRequestId = $pr.pullRequestId
    Title         = $pr.title
    Author        = $pr.createdBy.displayName
    SourceBranch  = $pr.sourceRefName -replace '^refs/heads/', ''
    TargetBranch  = $pr.targetRefName -replace '^refs/heads/', ''
    Comments      = @()
}

$index = 1
foreach ($thread in $activeThreads) {
    $first = $thread.comments[0]
    $plainContent = Get-PlainContent $first
    $ctx = $thread.threadContext
    
    # Get replies (non-system comments after the first)
    $replies = $thread.comments | Select-Object -Skip 1 | Where-Object { $_.commentType -ne 'system' } |
        ForEach-Object { @{ Author = $_.author.displayName; Content = $_.content } }

    $result.Comments += @{
        Index       = $index++
        ThreadId    = $thread.id
        CommentId   = $first.id
        Author      = $first.author.displayName
        Content     = $plainContent
        FullContent = $first.content
        Summary     = Get-Summary $plainContent
        ReplyCount  = @($replies).Count
        Replies     = @($replies)
        FilePath    = $ctx.filePath
        LineNumber  = ($ctx.rightFileStart.line, $ctx.leftFileStart.line | Where-Object { $_ } | Select-Object -First 1)
        Url         = "$baseUrl`?discussionId=$($thread.id)"
        Severity    = $thread.properties.CommentSeverity.'$value'
        Category    = $thread.properties.category.'$value'
        CommentType = $first.commentType
    }
}

Write-Host "Found $($result.Comments.Count) active comment(s)." -ForegroundColor Green
$result | ConvertTo-Json -Depth 10
