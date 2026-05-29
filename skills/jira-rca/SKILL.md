---
name: jira-rca
description: "Root cause analysis workflow for Jira bugs. Automates ticket analysis, git branch creation, AI-powered RCA, plan generation, and supervised execution. Use when debugging, performing bug fixes, conducting incident investigation, or analyzing production issues."
---

# Jira RCA Workflow

Automated root cause analysis workflow that guides you through ticket investigation, AI-powered analysis, and supervised plan execution with full transparency and control.

## Overview

The RCA (Root Cause Analysis) workflow streamlines bug investigation through a 10-step process:

1. **Ticket Selection** - Choose a Jira bug ticket
2. **Details Fetch** - Retrieve full ticket information
3. **Attachments Download** - Get all related files
4. **Context Input** - Add additional context
5. **Git Branch** - Create/switch to analysis branch
6. **AI Analysis** - Delegate to AI agent (manual step)
7. **Plan Save** - Persist RCA findings as markdown
8. **Approval** - Review and approve execution plan
9. **Supervised Execution** - Execute steps with control
10. **Completion** - Summary and Jira update

## Prerequisites

- `jira` CLI installed and configured (`jira init` completed)
- `git` must be installed (for branch creation)
- `JIRA_API_TOKEN` environment variable set
- `python3` available (for JSON parsing)
- `jira-common` skill installed (for shared utilities)
- AI agent access (for RCA analysis delegation)

## Quick Start

### Basic Usage

```bash
# Interactive mode - choose ticket when prompted
./rca-workflow.sh

# Direct issue key
./rca-workflow.sh BUG-123

# Auto-approve all gates (for CI/automation)
./rca-workflow.sh BUG-123 --auto-approve
```

## Workflow Steps

### Step 1: Get Ticket

Accept issue key as command-line argument or interactive prompt.

```bash
# Validates issue key format: [A-Z]+-[0-9]+
# Examples: PROJ-123, BUG-456, INFRA-789
```

### Step 2: Fetch Ticket Details

Retrieves ticket information from Jira:
- Summary
- Description (handles Atlassian Document Format)
- Issue type
- Last 10 comments
- All metadata

Displays formatted ticket summary for review.

### Step 3: Download Attachments

Batch downloads all attachments from the issue (requires `JIRA_API_TOKEN`).

Skips gracefully if:
- Token not set
- No attachments present
- Script not available

Outputs list of downloaded file paths.

### Step 4: Additional Context

Prompts for manual context input (multi-line, Ctrl+D to finish).

Use for:
- Recent error messages
- Reproduction steps
- System state information
- Customer impact details

### Step 5: Git Branch

Automatically creates or switches to a feature branch with intelligent naming:

- **Bugs** → `bugfix/PROJ-123-summary`
- **Stories/Tasks** → `feature/PROJ-123-summary`
- **Epics** → `epic/PROJ-123-summary`

Handles:
- Uncommitted changes (prompts to stash)
- Existing branches (switches if present)
- Non-git directories (skips gracefully)

### Step 6: AI Analysis Delegation

**This is a manual step requiring human action.**

The workflow creates a context file and instructs you to run AI analysis:

```bash
omo delegate --subagent librarian --prompt "$(cat /tmp/rca-context-BUG-123.txt)"
```

**What happens:**
1. Context file created with all ticket information
2. Displays command to run AI analysis
3. **You paste the analysis result** when ready (multi-line input)

**Example context file includes:**
```
# RCA Analysis Request

## Ticket: BUG-123
Summary: Database connection timeout on login
Type: Bug
Branch: bugfix/bug-123-database-connection-timeout

## Description
Login requests timeout intermittently, affecting ~5% of users...

## Comments
[User]: Happens every Tuesday evening
[Dev]: Only affects us-east-1 region
---

## Attachments
- /tmp/BUG-123-error-logs.zip
- /tmp/BUG-123-network-trace.pcap

## Additional Context
Started 3 days ago after database migration

## Task
Perform root cause analysis for this bug. Provide:
1. Root cause identification
2. Affected components
3. Fix plan with specific steps
4. Testing strategy
```

### Step 7: Save Plan

Saves AI analysis as markdown with YAML frontmatter:

```markdown
---
issue: BUG-123
type: rca
timestamp: 2024-02-03T15:42:30Z
branch: bugfix/bug-123-database-connection-timeout
user: john.doe
---

# Root Cause Analysis

## Root Cause
Database connection pool exhaustion...

## Affected Components
- AuthService (login endpoint)
- ConnectionPool (MySQL)
- LoadBalancer (health checks)

## Fix Plan
1. Increase connection pool size from 20 to 50
2. Add connection timeout monitoring
3. Deploy to staging for testing
...
```

File saved to: `./plans/BUG-123-rca-2024-02-03-154230.md`

### Step 8: Approval Gate

Displays plan preview (first 100 lines) for review.

**Interactive approval:**
- `y` - Proceed with execution
- `N` - Decline and exit (plan saved for later)

**Auto-approve mode:** Skips review with `--auto-approve` flag

### Step 9: Step-by-Step Execution

Extracts numbered steps from analysis and executes with supervision:

```
📌 **Step 1:** Increase connection pool size from 20 to 50

Execute this step? [Y/n/skip/abort]: y

**Action Required:** Please execute: Increase connection pool size from 20 to 50

Step completed successfully? [y/N/error]: y
✓ Step 1 completed
```

**Response options:**
- `Y` (default) - Execute and mark complete
- `n` - Skip step
- `skip` - Skip step
- `abort` - Stop execution
- `error` - Report failure and post to Jira

**Error handling:**
- Prompted for error details
- Posted to Jira as internal comment
- Logged for debugging

Provides execution summary at completion:
```
Execution Summary:
  Completed: 8
  Skipped:   2
  Errors:    1
  Total:     11
```

### Step 10: Completion

Posts summary comment to Jira issue:

```
✅ **RCA Complete**

**Branch:** bugfix/bug-123-database-connection-timeout
**Plan:** ./plans/BUG-123-rca-2024-02-03-154230.md

**Summary:**
- Completed 8 steps
- 2 steps skipped
- 1 error encountered

Fix implementation plan ready for review.

_Posted automatically by jira-rca workflow_
```

## Usage Examples

### Basic Bug Analysis

```bash
./rca-workflow.sh BUG-123
```

**Workflow:**
1. Fetches BUG-123 details
2. Downloads attachments
3. Prompts for additional context
4. Creates bugfix branch
5. Instructs manual AI delegation
6. Saves analysis when provided
7. Reviews plan interactively
8. Supervises step execution
9. Posts completion to Jira

### Production Incident Investigation

```bash
./rca-workflow.sh INFRA-456 --auto-approve
```

**With auto-approve:**
- Skips manual approval gates
- Still shows all steps and context
- Useful for documented incidents
- Audit trail in Jira comments

### Interactive Mode

```bash
./rca-workflow.sh

# Prompts for issue key
# Enter: BUG-789
```

## AI Delegation

The workflow requires **manual AI delegation** for analysis.

### The Delegation Step

At Step 6, you'll see:

```
┌─────────────────────────────────────────────────────────────────────┐
│ AI ANALYSIS DELEGATION                                              │
├─────────────────────────────────────────────────────────────────────┤
│ Context file created with all ticket information.                   │
│                                                                     │
│ Please run the following command manually to get AI analysis:       │
└─────────────────────────────────────────────────────────────────────┘

  omo delegate --subagent librarian --prompt "$(cat /tmp/rca-context-BUG-123.txt)"

Or copy the context file path and use your preferred AI tool:
  /tmp/rca-context-BUG-123.txt

────────────────────────────────────────────────────────────────────────
```

### Running the Delegation Command

```bash
# Using omo librarian agent
omo delegate --subagent librarian --prompt "$(cat /tmp/rca-context-BUG-123.txt)"

# Or with your own AI tool
cat /tmp/rca-context-BUG-123.txt | your-ai-tool
```

### Providing the Analysis

After running analysis, copy the result and paste into the workflow:

```
Paste the analysis result below (Ctrl+D when done):

[Paste full analysis here]
[Ctrl+D to finish]
```

## Plan Format

RCA plans are saved as markdown with YAML frontmatter and structured sections:

```markdown
---
issue: BUG-123
type: rca
timestamp: 2024-02-03T15:42:30Z
branch: bugfix/bug-123-issue-name
user: john.doe
---

# Root Cause Analysis: BUG-123

## Root Cause
Clear identification of what caused the issue...

## Affected Components
- Component A (specific impact)
- Component B (specific impact)
- Database migration (configuration change)

## Timeline
- 2024-02-01 08:00 - Issue first reported
- 2024-02-01 10:30 - Root cause identified
- 2024-02-03 15:00 - Fix deployed

## Fix Plan
1. First step with specific details
2. Second step with specific details
3. Third step with rollback procedure
4. Testing and verification steps

## Testing Strategy
- Unit tests for changed components
- Integration tests for data flow
- Load testing for performance

## Prevention
- Monitoring alerts for early detection
- Code review checklist items
- Documentation updates
```

## Supervised Execution

The workflow provides fine-grained control during execution:

### Per-Step Supervision

Each step displays:
- Step number and description
- Execution prompt with options
- Completion confirmation
- Error handling with logging

### Execution Flow

```
Step 1: Update database configuration
Execute this step? [Y/n/skip/abort]: Y

**Action Required:** Please execute: Update database configuration

Step completed successfully? [y/N/error]: y
✓ Step 1 completed
```

### Error Handling

If a step fails:

```
Step 2: Deploy to staging
Execute this step? [Y/n/skip/abort]: Y

**Action Required:** Please execute: Deploy to staging

Step completed successfully? [y/N/error]: error

Enter error details (Ctrl+D when done):
Deployment failed: Docker image not found in registry
[Ctrl+D]

✗ Error posted to Jira
✗ Step 2 failed
```

## Integration with jira-common

The RCA workflow uses shared utilities from `jira-common`:

1. **create-branch.sh** - Git branch creation with type-based naming
2. **download-all-attachments.sh** - Batch attachment retrieval
3. **save-plan.sh** - Plan persistence with metadata
4. **post-error-to-jira.sh** - Error logging to issues

Fallbacks provided if scripts unavailable.

## Exit Codes

| Code | Meaning | Scenario |
|------|---------|----------|
| 0 | Success | RCA completed or plan saved/declined |
| 1 | Invalid arguments | Bad issue key format or missing args |
| 2 | Jira error | API failure or issue not found |
| 3 | User abort | Declined analysis or approval |
| 4 | Execution error | Script failures or runtime issues |

## Environment Variables

| Variable | Required | Usage |
|----------|----------|-------|
| `JIRA_API_TOKEN` | Optional | Attachment downloads |

## Troubleshooting

### "jira CLI is not installed"

Install with:
```bash
go install github.com/go-jira/jira/cmd/jira@latest
jira init  # Configure with your instance
```

### "Failed to fetch issue"

Check:
```bash
# Verify issue exists
jira issue view BUG-123

# Check API token
test -n "$JIRA_API_TOKEN" && echo "JIRA_API_TOKEN is set"

# Verify issue key format (e.g., PROJ-123)
```

### "Not in a git repository"

Workflow continues without branch creation. Either:
- Run from git repo root: `cd /path/to/repo && rca-workflow.sh BUG-123`
- Or accept skipped git branch step

### "Attachment download failed"

Common causes:
- `JIRA_API_TOKEN` not set: `export JIRA_API_TOKEN="..."`
- Network issues or permissions
- Workflow continues without attachments

### "No executable steps found"

Plan may be informational without numbered steps. Either:
- Use the plan manually for reference
- Request AI analysis in numbered step format (1., 2., 3., etc.)

## Best Practices

### Before Starting RCA

- Ensure you're in the correct git repository
- Have recent Jira credentials available
- Gather any supplementary context before running

### During AI Analysis

- Provide comprehensive context via the delegation command
- Ask for numbered steps for supervised execution
- Request specific file paths and code references

### During Execution

- Execute steps in order unless explicitly noted
- Document any deviations or issues
- Use error reporting for tracking failures

### After Completion

- Review Jira comments for summary
- Commit the plan file with your changes
- Archive plans for incident post-mortems

## Advanced Usage

### Batch RCA for Multiple Bugs

```bash
#!/bin/bash
for issue in BUG-100 BUG-101 BUG-102; do
  echo "Analyzing $issue..."
  ./rca-workflow.sh "$issue" --auto-approve
done
```

### Integration with CI/CD

```bash
# In your CI pipeline
./rca-workflow.sh "$ISSUE_KEY" --auto-approve
plan_file=$(find ./plans -name "${ISSUE_KEY}-rca-*.md" -newest -1)
git add "$plan_file"
git commit -m "Add RCA for $ISSUE_KEY"
```

### Custom AI Tools

Instead of `omo delegate`, use any AI system:

```bash
# Using Claude directly
claude "$(cat /tmp/rca-context-BUG-123.txt)" > /tmp/analysis.txt

# Using your organization's analysis tool
internal-rca-tool < /tmp/rca-context-BUG-123.txt > /tmp/analysis.txt
```

Then paste the output when prompted.

## Examples

### Example: Database Connection Issue

**Input:**
```bash
./rca-workflow.sh BUG-5432
```

**Steps:**
1. Fetch: BUG-5432 "Login timeout - database unavailable"
2. Download: Error logs, network traces
3. Context: "Started after migration to new cluster"
4. Branch: Creates `bugfix/bug-5432-database-connection-issue`
5. AI Analysis: Delegates to librarian
6. Plan: Saved with connection pool sizing, monitoring setup
7. Execution: 3 steps (config update, deploy, verify)

**Output:**
```
✓ Ticket details fetched
✓ Downloaded 2 attachment(s)
✓ Additional context captured
✓ Branch: bugfix/bug-5432-database-connection-issue
[... AI analysis delegation ...]
✓ Plan saved: ./plans/BUG-5432-rca-2024-02-03-154230.md
✓ Plan approved for execution
  Completed: 3
  Skipped:   0
  Errors:    0
```

### Example: Failed Deployment

**Input:**
```bash
./rca-workflow.sh INFRA-89 --auto-approve
```

**With auto-approve:**
- Skips review prompts
- Still displays all steps
- Still posts to Jira
- Useful for automated incident response

## Support

For issues with the workflow:

1. Check prerequisites are installed
2. Verify Jira credentials and connectivity
3. Review error messages in stderr
4. Check plan file for analysis details
5. Consult jira-common skill for utility issues
