---
name: address-pr-comments
description: Address PR comments from Azure DevOps pull requests. Fetches active comments, displays summaries, and helps address them with user confirmation before making changes.
---

# Address PR Comments Skill

**Trigger:** User provides a **pull request URL** and requests to address PR comments.

## Workflow

### Step 1: Fetch PR Comments

Run the script to fetch active (unresolved) PR comments:

```powershell
pwsh .\scripts\Get-PullRequestComments.ps1 -PullRequestUrl "<url>"
```

The script returns a JSON array of comments with:
- `ThreadId` - Unique thread identifier
- `CommentId` - Comment identifier
- `Author` - Who posted the comment
- `Content` - Full comment text
- `Summary` - One-sentence summary (first 100 chars)
- `ReplyCount` - Number of replies
- `FilePath` - File the comment is on (if applicable)
- `LineNumber` - Line number (if applicable)
- `Url` - Direct link to the comment thread

### Step 2: Display Comments Summary

Present comments to user in a table format:

| # | Summary | Author | Replies | Link |
|---|---------|--------|---------|------|
| 1 | Fix null check in... | John Doe | 2 | [View](url) |
| 2 | Consider using... | Jane Smith | 0 | [View](url) |

### Step 3: Ask User Which Comments to Address

Use `ask_followup_question` with options:
- "Address all comments"
- "Address comment #1"
- "Address comment #2" (etc., up to 4 options total)
- If more than 3 comments, include "Let me specify which comments to address"

### Step 4: Create PR Comments Analysis File

Create a markdown file at `.ai/pr-comments/pr-<pr-number>-comments.md` with:

```markdown
# PR #<number> - Comment Analysis

**PR Title:** <title>
**Author:** <author>
**Date:** <current date>

## Comments to Address

### Comment #1: <summary>
**Author:** <author>
**File:** <file path>:<line number>
**Link:** [View Comment](<url>)

**Full Comment:**
> <full comment text>

**Replies:**
> - <reply 1>
> - <reply 2>

**Proposed Resolution:**
<AI analysis and proposed fix>

---
(repeat for each selected comment)
```

### Step 5: Confirm Before Making Changes

Use `ask_followup_question` to confirm:
- "Yes, proceed with the proposed changes"
- "No, I want to modify the approach"
- "Show me the proposed changes first"
- "Cancel - I'll address these manually"

### Step 6: Apply Changes

Only after user confirmation:
1. Make the necessary code changes to address each comment
2. Update the markdown file with the changes made
3. Summarize what was done

## Script Requirements

The [`Get-PullRequestComments.ps1`](scripts/Get-PullRequestComments.ps1) script:
- Uses Azure CLI (`az repos pr thread list`)
- Filters to active (unresolved) threads only
- Returns structured JSON for processing

## Output Files

- **Analysis file:** `.ai/pr-comments/pr-<pr-number>-comments.md`
- Create the `.ai/pr-comments/` directory if it doesn't exist

## Error Handling

- If no active comments found, inform user: "No active (unresolved) comments found on this PR."
- If Azure CLI not authenticated, provide guidance: "Run `az login` to authenticate."
- If PR URL is invalid, show expected format.

## References

- Uses same Azure CLI authentication as [`code-review`](../code-review/SKILL.md) skill
- PR comments API: `az repos pr thread list`
