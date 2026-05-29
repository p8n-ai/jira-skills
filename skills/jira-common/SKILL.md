---
name: jira-common
description: "Shared utilities for Jira workflow automation. Git branch management, attachment downloading, plan persistence, and error logging. Use when building Jira-integrated workflows."
---

# Jira Common Utilities

Shared utilities for Jira workflow automation including git branch creation, batch attachment downloads, plan persistence, and interactive error logging.

## Prerequisites

- `jira` CLI must be installed and configured (`jira init` completed)
- `git` must be installed (for branch creation)
- `JIRA_API_TOKEN` environment variable must be set
- `python3` available (for JSON parsing)

## Utility Scripts

### create-branch.sh

Creates or switches to a git branch based on Jira issue metadata with automatic type-based naming.

**Purpose**: Automate branch creation from Jira issues with intelligent naming based on issue type (bugfix, feature, epic, etc.).

**Branch Naming**:
- Bug issues → `bugfix/PROJ-123-issue-summary`
- Story/Task issues → `feature/PROJ-123-issue-summary`
- Epic issues → `epic/PROJ-123-issue-summary`
- Other types → `task/PROJ-123-issue-summary`
- Slug: lowercase summary with hyphens, special characters removed
- Max length: 255 characters (truncates slug if needed)

**Usage Syntax**:

```bash
create-branch.sh --issue ISSUE-KEY [--help]
```

**Arguments**:
- `--issue ISSUE-KEY` (required): Jira issue key (e.g., `PROJ-123`)
- `--help, -h`: Show help message

**Examples**:

```bash
# Create branch for bug
create-branch.sh --issue PROJ-123

# Expected output:
# bugfix/proj-123-fix-database-connection-issue

# Create branch for story
create-branch.sh --issue PROJ-456

# Expected output:
# feature/proj-456-implement-user-authentication

# Create branch for epic
create-branch.sh --issue PROJ-789

# Expected output:
# epic/proj-789-major-refactoring
```

**Behavior**:
- Checks for uncommitted changes (offers to stash)
- If branch exists: prompts to switch to it
- If branch missing: creates new branch
- Outputs final branch name to stdout
- Validates git repository and jira CLI availability

**Exit Codes**:
- `0`: Success (branch created or switched)
- `1`: Invalid arguments
- `2`: Missing git repo or jira CLI
- `3`: Jira API error or failed to parse issue
- `4`: Git operation failed

**Environment**:
- Requires: `git`, `jira` CLI, `python3`
- Must be run from within a git repository

**Integration Pattern**:
```bash
# Use in automation workflows
branch=$(create-branch.sh --issue PROJ-123) || exit 1
echo "Working on branch: $branch"
```

---

### download-all-attachments.sh

Downloads all attachments from a Jira issue in batch with progress reporting.

**Purpose**: Retrieve all attachments from an issue at once instead of manually downloading each file.

**Usage Syntax**:

```bash
download-all-attachments.sh --issue <issue-key> [--out <output-path>]
```

**Arguments**:
- `--issue ISSUE-KEY` (required): Jira issue key (e.g., `PROJ-123`)
- `--out OUTPUT-PATH` (optional): Output directory (defaults to a new temporary directory)
- `--help, -h`: Show help message

**Output**:
- stdout: JSON array of downloaded file paths
- stderr: Progress messages and errors

**Examples**:

```bash
# Download all attachments to default directory
download-all-attachments.sh --issue PROJ-123

# Output:
# ["/tmp/PROJ-123-diagram.png","/tmp/PROJ-123-spec.pdf"]

# Download to specific directory
download-all-attachments.sh --issue PROJ-123 --out /tmp/attachments

# Parse JSON output
files=$(download-all-attachments.sh --issue PROJ-123 | jq -r '.[]')
for file in $files; do
  echo "Downloaded: $file"
done

# Check for failures
if ! download-all-attachments.sh --issue PROJ-123; then
  echo "Some attachments failed to download"
fi
```

**Environment Variables** (Required):
- `JIRA_API_TOKEN`: API token for authentication

The Jira server and email are read from the `jira` CLI config created by `jira init`.

**Exit Codes**:
- `0`: All attachments downloaded successfully
- `1`: Invalid arguments
- `2`: Jira CLI error or issue fetch failure
- `3`: Some attachments failed to download (partial success)

**Dependencies**:
- Requires `download-attachment.sh` script from `jira-issues` skill
- Uses `jira issue view` to fetch attachment metadata

**Integration Pattern**:
```bash
# Download attachments and process them
files=$(download-all-attachments.sh --issue PROJ-123 | jq -r '.[]')
if [[ -z "$files" ]]; then
  echo "No attachments found"
else
  for file in $files; do
    echo "Processing: $file"
  done
fi
```

---

### save-plan.sh

Saves execution plans as markdown files with YAML frontmatter metadata for tracking decisions and analysis.

**Purpose**: Persist plans from jira-rca and jira-implement workflows as versioned markdown files with metadata.

**Usage Syntax**:

```bash
save-plan.sh --issue ISSUE-KEY --type rca|implement [--content "TEXT" | STDIN] [--branch NAME]
```

**Arguments**:
- `--issue ISSUE-KEY` (required): Issue key in format `[A-Z]+-[0-9]+` (e.g., `PROJ-123`)
- `--type TYPE` (required): Plan type: `rca` (root cause analysis) or `implement` (implementation)
- `--content "TEXT"` (optional): Plan content as string (reads from stdin if not provided)
- `--branch NAME` (optional): Git branch name (auto-detected if not provided)
- `--help`: Show help message

**Output**:
- Writes to `./plans/{ISSUE}-{TYPE}-{TIMESTAMP}.md`
- File includes YAML frontmatter with metadata
- File set to read-only mode after creation
- Outputs filename path to stdout

**Examples**:

```bash
# Save plan with explicit content
save-plan.sh --issue PROJ-123 --type rca --content "Root cause: Database deadlock in migration script"

# Output:
# ./plans/PROJ-123-rca-2024-02-03-154230.md

# Read plan from stdin (pipe)
echo "Implementation plan: 1. Update schema, 2. Test, 3. Deploy" | \
  save-plan.sh --issue PROJ-456 --type implement

# Save with specific branch
save-plan.sh --issue PROJ-789 --type rca --content "Analysis" --branch feature/fix-auth

# Read from file
cat /tmp/plan.txt | save-plan.sh --issue PROJ-100 --type implement
```

**File Format**:

Created file includes YAML frontmatter:

```markdown
---
issue: PROJ-123
type: rca
timestamp: 2024-02-03T15:42:30+00:00
branch: feature/fix-auth
user: john.doe
---

Plan content here...
```

**Exit Codes**:
- `0`: Plan saved successfully
- `1`: Invalid arguments or issue key format
- `2`: Write error or failed to create directory

**Environment**:
- Auto-detects current git branch (if in repo)
- Creates `./plans/` directory if missing
- Runs in current working directory

**Integration Pattern**:
```bash
# Save analysis and continue
plan_file=$(save-plan.sh --issue PROJ-123 --type rca --content "$analysis") || exit 1
echo "Saved plan to: $plan_file"

# In jira-rca workflow
git add plans/
git commit -m "Add RCA for $(jira issue view PROJ-123 --plain | head -1)"
```

---

### post-error-to-jira.sh

Posts execution errors to Jira issue comments with optional interactive confirmation.

**Purpose**: Log workflow errors back to Jira for tracking and debugging issues during automation.

**Usage Syntax**:

```bash
post-error-to-jira.sh --issue ISSUE-KEY --step "step name" \
  [--error "message" | --error-log PATH] [--auto-post] [--help]
```

**Arguments**:
- `--issue ISSUE-KEY` (required): Jira issue key (e.g., `PROJ-123`)
- `--step "step name"` (required): Name of the step where error occurred
- `--error "message"` (optional): Error message (mutually exclusive with `--error-log`)
- `--error-log PATH` (optional): Path to error log file (mutually exclusive with `--error`)
- `--auto-post` (optional): Skip interactive prompt and post automatically
- `--help`: Show help message

**Output**:
- Posts comment to Jira issue as internal comment
- Prints confirmation or "Skipped posting error" to stdout
- Includes timestamp and workflow attribution

**Examples**:

```bash
# Interactive prompt with direct error message
post-error-to-jira.sh --issue PROJ-123 --step "Build compilation" --error "gcc: command not found"

# Interactive prompt with error from file
post-error-to-jira.sh --issue PROJ-123 --step "Deploy" --error-log /tmp/deploy.log

# Auto-post without prompting
post-error-to-jira.sh --issue PROJ-123 --step "Test" --error "All tests failed" --auto-post

# Read error from captured output
build_output=$(make 2>&1) || {
  post-error-to-jira.sh --issue PROJ-123 --step "Build" --error "$build_output" --auto-post
  exit 1
}
```

**Comment Format** (Posted to Jira):

```
❌ **Error in step: Build compilation**

`
gcc: command not found
`

_Posted automatically by jira-rca/jira-implement workflow_
_Timestamp: 2024-02-03T15:42:30Z
```

**Exit Codes**:
- `0`: Error posted successfully OR user declined to post (both considered success)
- `1`: Invalid arguments or missing required parameters
- `2`: Jira CLI error or failed to post comment

**Environment**:
- Requires `JIRA_API_TOKEN` for authentication
- Requires `jira` CLI to be available

**Integration Pattern**:
```bash
# Capture errors and post to Jira
if ! npm run build; then
  post-error-to-jira.sh --issue PROJ-123 --step "Build" --error-log /tmp/build.log --auto-post
  exit 1
fi
```

---

## Integration Patterns

### Used by jira-rca Workflow

The `jira-rca` skill uses these utilities for root cause analysis:

1. **create-branch.sh**: Create analysis branch from issue
2. **download-all-attachments.sh**: Retrieve issue artifacts for analysis
3. **save-plan.sh**: Save RCA findings as markdown
4. **post-error-to-jira.sh**: Log analysis errors back to issue

Example flow:
```bash
branch=$(create-branch.sh --issue PROJ-123)
attachments=$(download-all-attachments.sh --issue PROJ-123)
plan_file=$(save-plan.sh --issue PROJ-123 --type rca --content "$analysis")
```

### Used by jira-implement Workflow

The `jira-implement` skill uses these utilities for implementation tasks:

1. **create-branch.sh**: Create feature/bugfix branch
2. **save-plan.sh**: Save implementation strategy
3. **post-error-to-jira.sh**: Report execution errors during implementation

Example flow:
```bash
branch=$(create-branch.sh --issue PROJ-456)
plan=$(save-plan.sh --issue PROJ-456 --type implement --content "$strategy")
if ! npm test; then
  post-error-to-jira.sh --issue PROJ-456 --step "Test" --error-log /tmp/test.log
fi
```

---

## Troubleshooting

### create-branch.sh Issues

**Error: "jira CLI not found"**
- Install jira CLI: `go install github.com/go-jira/jira/cmd/jira@latest`
- Configure with: `jira init`

**Error: "Not in a git repository"**
- Navigate to git repository root
- Verify with: `git rev-parse --git-dir`

**Error: "Could not parse issue type from Jira response"**
- Verify issue exists: `jira issue view PROJ-123`
- Check JIRA_API_TOKEN is set: `test -n "$JIRA_API_TOKEN" && echo "JIRA_API_TOKEN is set"`
- Verify issue key format (e.g., `PROJ-123`)

**Dirty working directory warning**
- Stash changes when prompted, or manually: `git stash`
- Unstash later: `git stash pop`

### download-all-attachments.sh Issues

**Error: "JIRA_API_TOKEN env var missing"**
- Set token: `export JIRA_API_TOKEN="your-token"`
- Verify without printing the token: `test -n "$JIRA_API_TOKEN" && echo "JIRA_API_TOKEN is set"`

**Error: "Could not find download-attachment.sh script"**
- Requires `jira-issues` skill to be installed
- Check path: `path/to/jira-issues/scripts/download-attachment.sh`

**Exit code 3 (partial success)**
- Some attachments downloaded, some failed
- Check stderr output for which files failed
- Network or permissions issues may cause individual failures

### save-plan.sh Issues

**Error: "Failed to create ./plans directory"**
- Check current directory: `pwd`
- Verify write permissions: `touch ./test.txt`
- May need parent directory created manually

**Error: "Invalid issue key format"**
- Use format: `[A-Z]+-[0-9]+` (e.g., `PROJ-123`)
- No lowercase letters or special characters in key

**Error: "Invalid type"**
- Use `rca` or `implement` only
- Check spelling

### post-error-to-jira.sh Issues

**Error: "jira CLI is not installed"**
- Install jira CLI: `go install github.com/go-jira/jira/cmd/jira@latest`

**Error: "Failed to post error comment"**
- Verify issue exists: `jira issue view PROJ-123`
- Check JIRA_API_TOKEN without printing it: `test -n "$JIRA_API_TOKEN" && echo "JIRA_API_TOKEN is set"`
- Verify write permissions on issue
