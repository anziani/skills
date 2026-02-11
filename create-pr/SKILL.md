---
name: create-pr
description: Create a pull request from the current branch against master or main. Generates commit message from git diff, fills PR description template, creates a work item if requested and creates PR via Azure CLI.
---

# Create Pull Request Skill

**Trigger:** User requests to create a pull request from the current branch.

## Prerequisites

- Azure CLI installed with `azure-devops` extension
- User authenticated via `az login`
- Azure DevOps MCP
- Current branch has commits ahead of master
- Remote repository configured

## Workflow

### 1. Validate Current State

1. **Verify not on master:** If branch is `master` or `main`, ensure there are commits ahead of the target branch:
   - Run `git rev-list --count master..HEAD`
   - If count is 0, inform user and abort:
     ```
     Your branch is up to date with master. Please make some commits before creating a PR.
     ```
   - If commits exist, create a new branch with format <username>/<name>
2. **Check for staged changes:** Run `git diff --cached --name-only`.
   - If no staged changes exist, inform the user and use `ask_followup_question`:
     ```
     No staged changes found. Please stage the changes you want to include in this PR.
     ```
     Options:
     - "I've staged my changes, continue"
     - "Abort PR creation"
   - If staged changes exist, proceed to next step.

### 2. Generate Commit Message

1. **Fetch latest master:** Run `git fetch origin master`.
2. **Get staged diff stats:** Run `git diff --cached --stat` to see staged files.
3. **Analyze staged changes:** Run `git diff --cached` to understand the staged changes.
4. **Generate message:** Create a concise 1-sentence commit message summarizing the staged changes.
   - Focus on the *what* and *why*
   - Use imperative mood (e.g., "Add feature X" not "Added feature X")
   - Keep under 72 characters if possible

### 3. Fill PR Description Template

If a template exists at `.azuredevops/pull_request_template.md`, use it, otherwise create a new description with the following structure:

1. **Type:** Determine from the changes (Bug fix / New feature / Migate Component Governance Alert / Other)
2. **Why:** Explain the reason for the change based on the diff analysis
3. **How:** Describe the implementation approach
4. **How tested:** Suggest appropriate testing (unit tests, manual, integration)
5. **Documentation:** Assess if docs are needed based on the change scope

#### Save PR Description for Review

After generating the PR description, save it to a markdown file for user review and editing:

1. **Save description:** Write the filled PR template to `.ai/pullrequests/<branch_name>.md`
   - Replace any `/` in branch name with `-` for filename compatibility
   - Example: branch `user/feature-x` → `.ai/pullrequests/user-feature-x.md`
2. **Inform user:** Let the user know the PR description has been saved and they can edit it before proceeding

### 4. Link Work Item
If user already mentioned to create a work item, skip asking and create it. Otherwise, use `ask_followup_question` to ask about work item linking:

```
Would you like to link a work item to this PR?
```

Options:
- "Yes, I'll provide the work item ID or URL"
- "Yes, create a new work item automatically"
- "No, skip work item linking"

#### If user provides work item:
- Accept work item ID (e.g., `12345`) or full URL (e.g., `https://dev.azure.com/msft-twc/Sonar/_workitems/edit/12345`)
- Extract the work item ID from URL if provided
- Validate the work item exists using Azure DevOps MCP tools

#### If user wants auto-generated work item:

To create a properly configured work item, follow these steps:

1. **Get user context:** Use `wit_my_work_items` to retrieve a recent work item assigned to the current user:
   ```
   wit_my_work_items(project: "Sonar", top: 1)
   ```

2. **Extract user details from existing work item:** Use `wit_get_work_item` to get full details:
   ```
   wit_get_work_item(id: <work_item_id>, project: "Sonar")
   ```
   Extract these fields:
   - `System.AssignedTo` → User's identity (email format: `user@microsoft.com`)
   - `System.IterationPath` → Current iteration (e.g., `Sonar\FY26Q3 - CY26Q1\2Wk14`)
   - `System.AreaPath` → Team area path (e.g., `Sonar\Sonar Detonation Platform`)

3. **Create the work item:** Use `wit_create_work_item` with all extracted context:
   ```
   wit_create_work_item(
     project: "Sonar",
     workItemType: "Task",
     fields: [
       { name: "System.Title", value: "<generated_commit_message>" },
       { name: "System.Description", value: "<brief_summary_of_changes>", format: "Html" },
       { name: "System.AssignedTo", value: "<user_email>" },
       { name: "System.IterationPath", value: "<current_iteration>" },
       { name: "System.AreaPath", value: "<area_path>" }
     ]
   )
   ```

4. **Store the work item ID** for PR linking

### 5. Confirm with User

Use `ask_followup_question` to present the generated content:

```
## Generated Commit Message
<commit_message>

## Generated PR Description
<filled_template>

## Work Item
<work_item_id or "None">

---
Please review the above. What would you like to do?
```

Options:
- "Create PR with this content"
- "Edit the commit message"
- "Edit the PR description"
- "Abort PR creation"

### 6. Create Pull Request

1. **Push branch:** Run `git push -u origin <branch_name>` if not already pushed.
2. **Create PR:** Run the script located within the skill folder with the saved description file:
   ```powershell
   pwsh -Command "& '.\scripts\New-PullRequest.ps1' -Title '<title>' -DescriptionFile '.ai/pullrequests/<branch_name>.md' -SourceBranch '<branch_name>' -TargetBranch 'master' -WorkItemId <work_item_id"
   ```
3. **Report result:** Display the PR URL to the user.

## Output

After successful PR creation:
- Display the PR URL
- Provide link to view in browser
- Suggest next steps (e.g., "Add reviewers", "Link work items")

## Error Handling

| Error | Resolution |
|-------|------------|
| Not logged in to Azure CLI | Prompt user to run `az login` |
| No commits ahead of master | Inform user branch is up to date |
| Azure DevOps MCP tools not available | Inform user to install Azure DevOps MCP |
| Push fails | Check remote permissions, branch protection |
| PR creation fails | Display Azure DevOps error message |
| Work item not found | Ask user to verify the work item ID |
| Work item creation fails | Proceed without work item, inform user |

## Configuration

The script uses the following defaults:
- **Organization:** Extracted from git remote URL
- **Project:** Extracted from git remote URL
- **Repository:** Extracted from git remote URL
- **Target Branch:** `master` (can be overridden)
- **Work Item:** Optional, can be provided or auto-generated

## Example Usage

User: "Create a PR for my current branch"

Agent:
1. Validates branch state
2. Checks for staged changes (`git diff --cached`)
3. Analyzes staged changes and generates commit message
4. Fills PR template with context
5. Asks about work item linking
6. Confirms with user
7. Commits staged changes and creates PR (with optional work item link) and returns URL

## Work Item URL Formats

The skill accepts work items in these formats:
- **ID only:** `12345`
- **Full URL:** `https://dev.azure.com/msft-twc/Sonar/_workitems/edit/12345`
- **Query URL:** `https://dev.azure.com/msft-twc/Sonar/_workitems/edit/12345?...`
