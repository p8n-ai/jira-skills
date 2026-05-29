---
name: jira-issues
description: "Manages Jira issues using jira-cli. Creates, edits, views, assigns, comments on, and searches issues. Use when working with Jira tickets, creating bugs/tasks/stories, or querying issue lists."
---

# Jira Issue Management

Manages Jira issues using the `jira` CLI tool.

## Prerequisites

- `jira` CLI must be installed and configured (`jira init` completed)
- `JIRA_API_TOKEN` environment variable must be set

## Core Commands

### List Issues

```sh
# List recent issues (interactive table view)
jira issue list

# Plain output for scripting
jira issue list --plain

# JSON output
jira issue list --raw

# CSV output
jira issue list --csv
```

### Common List Filters

| Flag | Description | Example |
|------|-------------|---------|
| `-a` | Assignee | `-a$(jira me)` or `-a"John Doe"` |
| `-r` | Reporter | `-r$(jira me)` |
| `-s` | Status | `-s"To Do"` or `-s~Done` (not Done) |
| `-y` | Priority | `-yHigh` |
| `-t` | Type | `-tBug` |
| `-l` | Label | `-lbackend` |
| `-p` | Project | `-pPROJ` |
| `-w` | Watching | `-w` |
| `-q` | Raw JQL | `-q "summary ~ cli"` |
| `--created` | Created date | `--created month`, `--created -7d` |
| `--updated` | Updated date | `--updated -30m` |
| `-R` | Resolution | `-R"Won't do"` |
| `--order-by` | Sort field | `--order-by rank --reverse` |

### Filter Examples

```sh
# My open high-priority issues
jira issue list -a$(jira me) -yHigh -sopen

# Unassigned issues created this week
jira issue list -ax --created week

# Issues not done, created before 6 months, assigned to someone
jira issue list -s~Done --created-before -24w -a~x

# Recent issue history
jira issue list --history
```

### Create Issue

```sh
# Interactive creation
jira issue create

# Non-interactive with all parameters
jira issue create -tBug -s"Summary" -yHigh -lbug -b"Description" --no-input

# Create and attach to epic
jira issue create -tStory -s"Story title" -PEPIC-42

# Create from template
jira issue create --template /path/to/template.md

# Create from stdin
echo "Description" | jira issue create -s"Summary" -tTask
```

### Edit Issue

```sh
# Interactive edit
jira issue edit ISSUE-1

# Update specific fields
jira issue edit ISSUE-1 -s"New summary" -yHigh -lnew-label --no-input

# Remove and add labels/components (use minus prefix to remove)
jira issue edit ISSUE-1 --label -old-label --label new-label
```

### View Issue

```sh
# View issue details
jira issue view ISSUE-1

# View with comments
jira issue view ISSUE-1 --comments 5
```

### Assign Issue

```sh
# Interactive assignment
jira issue assign

# Assign to specific user
jira issue assign ISSUE-1 "John Doe"

# Assign to self
jira issue assign ISSUE-1 $(jira me)

# Unassign
jira issue assign ISSUE-1 x

# Default assignee
jira issue assign ISSUE-1 default
```

### Move/Transition Issue

```sh
# Interactive transition
jira issue move

# Direct transition
jira issue move ISSUE-1 "In Progress"

# Transition with comment
jira issue move ISSUE-1 "In Progress" --comment "Started work"

# Transition with resolution
jira issue move ISSUE-1 Done -RFixed -a$(jira me)
```

### Clone Issue

```sh
# Clone issue
jira issue clone ISSUE-1

# Clone with modifications
jira issue clone ISSUE-1 -s"New summary" -yHigh -a$(jira me)

# Clone and replace text in summary/description
jira issue clone ISSUE-1 -H"old text:new text"
```

### Delete Issue

```sh
# Interactive delete
jira issue delete

# Direct delete
jira issue delete ISSUE-1

# Delete with subtasks
jira issue delete ISSUE-1 --cascade
```

### Comments

```sh
# Add comment interactively
jira issue comment add

# Add comment directly
jira issue comment add ISSUE-1 "Comment body"

# Add internal comment
jira issue comment add ISSUE-1 "Internal note" --internal

# Comment from template
jira issue comment add ISSUE-1 --template /path/to/comment.md
```

### Worklog

```sh
# Add worklog interactively
jira issue worklog add

# Add worklog directly
jira issue worklog add ISSUE-1 "2d 3h 30m" --no-input

# Add worklog with comment
jira issue worklog add ISSUE-1 "1h" --comment "Worked on feature" --no-input
```

### Link Issues

```sh
# Link interactively
jira issue link

# Link directly
jira issue link ISSUE-1 ISSUE-2 Blocks

# Add remote web link
jira issue link remote ISSUE-1 https://example.com "Link text"

# Unlink issues
jira issue unlink ISSUE-1 ISSUE-2
```

## Scripting Patterns

### Plain Output for Scripts

Always use `--plain --no-headers` for scripting:

```sh
# Get issue keys only
jira issue list --plain --columns key --no-headers

# Get specific columns
jira issue list --plain --columns key,status,assignee --no-headers
```

### Download Attachments

The Jira CLI does not support attachments. Use the helper script and pass the issue key so the output filename is prefixed with the ticket ID:

```sh
./scripts/download-attachment.sh \
  --id 22303 \
  --issue PROJ-123 \
  --out ./.tmp/ \
  --base-url "$JIRA_BASE_URL" \
  --email "$JIRA_EMAIL"
```

Argument notes:

- `--id` is the attachment ID from Jira.
- `--issue` is the Jira ticket key (e.g., `PROJ-123`).
- `--out` is the output path or directory. If a directory, the filename is inferred from metadata.

Required env vars:

```sh
export JIRA_API_TOKEN="..."
export JIRA_BASE_URL="https://jira.example.com"
export JIRA_EMAIL="you@example.com"
```

### Get Current User

```sh
jira me
```

### Open Issue in Browser

```sh
jira open ISSUE-1
```

## Navigation Keys (Interactive Mode)

- `j/k` or arrows: Navigate up/down
- `g/G`: Jump to top/bottom
- `CTRL+f/b`: Page down/up
- `v`: View issue details
- `m`: Transition issue
- `ENTER`: Open in browser
- `c`: Copy URL
- `CTRL+k`: Copy issue key
- `q/ESC`: Quit
