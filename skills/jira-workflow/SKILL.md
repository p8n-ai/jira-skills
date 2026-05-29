---
name: jira-workflow
description: "Automates common Jira workflows using jira-cli. Handles daily standups, issue triage, bulk operations, and project navigation. Use for Jira automation, reporting, or multi-issue operations."
---

# Jira Workflow Automation

Automates common Jira workflows using the `jira` CLI tool.

## Quick Reference

### Get Current User

```sh
jira me
```

### Open Jira in Browser

```sh
# Open project board
jira open

# Open specific issue
jira open ISSUE-1
```

### List Projects

```sh
jira project list
```

### List Boards

```sh
jira board list
```

### List Releases

```sh
jira release list
jira release list --project KEY
```

## Daily Workflow Commands

### Morning Standup

```sh
# What I'm working on
jira issue list -a$(jira me) -s"In Progress"

# What I did yesterday
jira issue list -a$(jira me) -sDone --updated -1d

# What's blocked
jira issue list -a$(jira me) -sBlocked
```

### My Workload

```sh
# All my open issues
jira issue list -a$(jira me) -s~Done

# My high priority issues
jira issue list -a$(jira me) -yHigh -s~Done

# Issues I'm watching
jira issue list -w
```

### Quick Issue Actions

```sh
# Start working on issue
jira issue move ISSUE-1 "In Progress"
jira issue assign ISSUE-1 $(jira me)

# Complete issue
jira issue move ISSUE-1 Done -RFixed

# Add quick comment
jira issue comment add ISSUE-1 "Working on this"

# Log time
jira issue worklog add ISSUE-1 "2h" --no-input
```

## Triage Workflows

### Unassigned Issues

```sh
# All unassigned
jira issue list -ax

# Unassigned high priority
jira issue list -ax -yHigh

# Unassigned created today
jira issue list -ax --created -1d
```

### New Issues Review

```sh
# Issues created today
jira issue list --created -1d

# Issues created this week needing triage
jira issue list --created week -s"To Do"

# New bugs
jira issue list -tBug --created -7d
```

## Reporting Scripts

### Tickets Created Per Day This Month

```sh
#!/usr/bin/env bash
jira issue list --created month --plain --columns created --no-headers \
  | awk '{print $1}' \
  | sort | uniq -c \
  | while read count date; do
    echo "$date: $count tickets"
  done
```

### Issues by Status

```sh
#!/usr/bin/env bash
for status in "To Do" "In Progress" "Done"; do
  count=$(jira issue list -s"$status" --plain --no-headers 2>/dev/null | wc -l)
  echo "$status: $count"
done
```

### Issues by Assignee

```sh
jira issue list --plain --columns assignee --no-headers \
  | sort | uniq -c | sort -rn
```

### Sprint Velocity

```sh
#!/usr/bin/env bash
sprints=$(jira sprint list --table --plain --columns id,name --no-headers)

echo "${sprints}" | while IFS=$'\t' read -r id name; do
  count=$(jira sprint list "${id}" --plain --no-headers 2>/dev/null | wc -l)
  printf "%s: %d issues\n" "${name}" $((count))
done
```

## Bulk Operations

### Process Multiple Issues

```sh
#!/usr/bin/env bash
# Move all my "To Do" items to "In Progress"
jira issue list -a$(jira me) -s"To Do" --plain --columns key --no-headers \
  | while read key; do
    jira issue move "$key" "In Progress"
  done
```

### Add Label to Multiple Issues

```sh
#!/usr/bin/env bash
# Add label to all bugs in current sprint
jira sprint list --current -tBug --plain --columns key --no-headers \
  | while read key; do
    jira issue edit "$key" -lneeds-review --no-input
  done
```

### Assign Unassigned Issues

```sh
#!/usr/bin/env bash
# Assign unassigned high-priority issues to self
jira issue list -ax -yHigh --plain --columns key --no-headers \
  | while read key; do
    jira issue assign "$key" $(jira me)
  done
```

## JQL Queries

Use `-q` flag for custom JQL within project context:

```sh
# Issues with "cli" in summary
jira issue list -q "summary ~ cli"

# Issues updated in last hour
jira issue list -q "updated >= -1h"

# Issues with specific component
jira issue list -q "component = Backend"

# Complex query
jira issue list -q "priority = High AND status != Done AND assignee = currentUser()"
```

## Configuration

### Multiple Projects

```sh
# Use specific config file
JIRA_CONFIG_FILE=./project-a.yaml jira issue list

# Or with flag
jira issue list -c ./project-a.yaml
```

### Output Formats

| Flag | Format | Use Case |
|------|--------|----------|
| (default) | Interactive table | Manual browsing |
| `--plain` | Plain text | Scripts, piping |
| `--raw` | JSON | API integrations |
| `--csv` | CSV | Spreadsheets |

### Useful Column Options

```sh
# Specify columns to display
jira issue list --plain --columns key,summary,status,assignee,priority

# No headers for cleaner script output
jira issue list --plain --columns key --no-headers
```

## Integration with Git

### Create Branch from Issue

```sh
#!/usr/bin/env bash
ISSUE="$1"
summary=$(jira issue view "$ISSUE" --plain 2>/dev/null | head -1)
branch_name=$(echo "$ISSUE-$summary" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
git checkout -b "$branch_name"
```

### Link Commit to Issue

```sh
# Add comment with commit link
jira issue comment add ISSUE-1 "Implemented in commit $(git rev-parse HEAD)"
```
