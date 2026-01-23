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
2. **Confirm with user:** Use `ask_followup_question` to confirm the user is satisfied with the review:
   - "Yes, I'm satisfied. Return to original branch."
   - "No, I want to stay on this branch to validate the review."
   - "I have feedback on the review."
3. **If user confirms satisfaction:**
   - Run `git checkout <original-branch>`.
   - If stashed earlier, run `git stash pop` to restore changes.
   - Inform user: review complete, file saved, returned to original branch, changes restored (if applicable).
4. **If user wants to stay:** Leave them on the PR branch and inform them how to return manually.


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

## Review Checklist

Use this checklist during every review to ensure high-quality feedback:

- [ ] **Context check** — Does this fit into the broader codebase design?
- [ ] **Critical feedback ≤ 6 comments** — Are the comments high-impact?
- [ ] **Grouped similar issues** — Did you lump repetitive concerns into one?
- [ ] **Respect multiple valid solutions** — Is this your personal preference or an actual problem?
- [ ] **Clear review status** — Approve, Request Changes, or Block with reason.
- [ ] **Rationale provided** — Does each comment explain *why*, not just *what*?
- [ ] **Review saved** — Is the review written to `.ai/code-reviews/` directory?
