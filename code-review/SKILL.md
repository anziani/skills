---
name: code-review
description: Perform structured code reviews. Emphasize Microsoft engineering standards, secure coding, performance optimization, and idiomatic usage.
---

# Code Review Skill

**Trigger:** User provides a **pull request URL** or **branch name** and requests a code review.

## Branch Management

### Before Review
1. **Save state:** Run `git branch --show-current` and store the original branch name.
2. **Check for changes:** Run `git status --porcelain`.
   - If dirty, inform the user and use `ask_followup_question` with options:
     - "Yes, stash my changes and proceed with checkout"
     - "No, abort the code review"
     - "Let me commit my changes first, then retry"
   - If user confirms stashing: run `git stash push -m "Auto-stash before code review of branch <BRANCH_NAME>"` and record this.
3. **Get PR info:** Run `pwsh .roo/skills/code-review/scripts/Get-PullRequest.ps1 -PullRequestUrl "<url>"` to fetch PR details (Title, Author, SourceBranch, TargetBranch, Description).
4. **Fetch and view changes:** Run `git fetch origin <SourceBranch>` then use `git diff origin/<TargetBranch>...origin/<SourceBranch>` to view the changed code without checking out the branch.
5. **Optional checkout:** If deeper context is needed beyond the diff (e.g., examining unchanged related files), checkout the branch: `git checkout <SourceBranch>`.

### Reviewing with Git Diff
Use `git diff` commands to examine changes efficiently:
- `git diff origin/<TargetBranch>...origin/<SourceBranch> --stat` — Overview of files changed
- `git diff origin/<TargetBranch>...origin/<SourceBranch> -- <path>` — View specific file changes
- `git diff origin/<TargetBranch>...origin/<SourceBranch> --name-only` — List changed files only

### After Review
1. **Save the review:** Write the review to `.ai/code-reviews/review-<branch>-<pr-number>.md` (create the directory if needed).
2. **Save comments as JSON:** Write the structured comments to `.ai/code-reviews/comments-<pr-number>.json` for posting (see [Comment JSON Format](#comment-json-format)).
3. **Present numbered summary:** Display a numbered table of all comments with severity, file, and one-line description.
4. **Ask to post comments:** Use `ask_followup_question` to let the user choose which comments to post:
   - "Post all comments to the PR"
   - "Post specific comments (e.g. 1,2,4)"
   - "Don't post any comments, just keep the review file"
   - "I have feedback on the review"
5. **Post selected comments:** Run the posting script with the user's selection (see [Posting Comments to PR](#posting-comments-to-pr)).
6. **Return to original branch:**
   - If on a different branch, run `git checkout <original-branch>`.
   - If stashed earlier, run `git stash pop` to restore changes.
   - Inform user: review complete, file saved, comments posted, returned to original branch.


## Review Process

### 1. Understand Context
- **Look beyond the diff** — consider how changes fit the larger codebase, existing patterns, and architecture.
- Identify project(s), target framework(s), and purpose (feature / bug fix / refactor).
- Ask: *What's missing?* (functionality, tests, edge cases)

### 2. Evaluate Code Quality

| Area | Focus |
|------|-------|
| **Correctness** | Logic errors, edge cases, null checks, error handling |
| **Security** | Secure API usage, secrets handling, input validation |
| **Performance** | Inefficiencies, race conditions, unnecessary allocations |
| **Idiomatic .NET** | Microsoft conventions, modern C# patterns, clarity |
| **Tests** | Coverage of positive/negative paths, isolation, missing cases |
| **Docs** | Public API documentation; avoid redundant comments |

### 3. Deliver Feedback

**Style:**
- **~5–6 high-impact comments** — not dozens of nitpicks.
- **Group similar issues** (e.g., one naming comment, not twenty).
- **Explain *why*** something is problematic, not just *what*.
- **Respect valid alternatives** — don't impose personal preferences.
- **Distinguish blocking vs. suggestions** clearly.

**Avoid:**
- Skimming only the diff
- Commenting on every stylistic difference
- Assuming non-blocking = approval


## Output Format

1. **Summary** — Brief assessment of PR quality.
2. **Issues** — Bullets grouped by category (Security, Performance, Style, etc.).
3. **Verdict:**
   - **Approve** — OK to merge (may include optional suggestions)
   - **Request Changes** — Must address before merge
   - **Block Merge** — When you genuinely *don't* want it merged until critical issues are fixed.

## Review File Output

After completing the review, save it to a markdown file:
- **Location:** `.ai/code-reviews/review-<branch>-<pr-number>.md`
- **Naming:** Use sanitized branch name (replace `/` with `-`) and PR number

## Comment JSON Format

After completing the review, save structured comments to a JSON file for posting:
- **Location:** `.ai/code-reviews/comments-<pr-number>.json`
- **Format:** JSON array of comment objects:

```json
[
  {
    "filePath": "/path/to/File.cs",
    "line": 42,
    "content": ":x: **[Category] Title**\n\nDetailed explanation of the issue.\n\n**Fix:** Suggested resolution."
  }
]
```

### Field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filePath` | string | Yes | File path relative to repo root, **prefixed with `/`** |
| `line` | int | Yes | Line number in the right-side diff to attach the comment |
| `content` | string | Yes | Markdown comment body |
| `status` | int | No | Thread status: 1=Active (default), 2=Fixed, 3=WontFix, 4=Closed |

### Emoji conventions for severity

| Severity | Emoji | Usage |
|----------|-------|-------|
| Blocking | `:x:` | Must fix before merge |
| Warning | `:warning:` | Should fix, but non-blocking |
| Suggestion | `:bulb:` | Nice-to-have improvement |

## Posting Comments to PR

Use the script at `.roo/skills/code-review/scripts/Post-ReviewComments.ps1` to post review comments.

### Post all comments
```powershell
pwsh .roo/skills/code-review/scripts/Post-ReviewComments.ps1 -PullRequestUrl "<url>" -CommentsFile ".ai/code-reviews/comments-<pr-number>.json"
```

### Post specific comments (by 1-based index)
```powershell
pwsh .roo/skills/code-review/scripts/Post-ReviewComments.ps1 -PullRequestUrl "<url>" -CommentsFile ".ai/code-reviews/comments-<pr-number>.json" -CommentNumbers "1,3,5"
```

## Review Checklist

Use this checklist during every review to ensure high-quality feedback:

- [ ] **Context check** — Does this fit into the broader codebase design?
- [ ] **Critical feedback ≤ 6 comments** — Are the comments high-impact?
- [ ] **Grouped similar issues** — Did you lump repetitive concerns into one?
- [ ] **Respect multiple valid solutions** — Is this your personal preference or an actual problem?
- [ ] **Clear review status** — Approve, Request Changes, or Block with reason.
- [ ] **Rationale provided** — Does each comment explain *why*, not just *what*?
- [ ] **Review saved** — Is the review written to `.ai/code-reviews/` directory?
- [ ] **Comments JSON saved** — Are comments saved as `.ai/code-reviews/comments-<pr-number>.json`?
- [ ] **User chose which to post** — Did you ask the user which comments to post?
