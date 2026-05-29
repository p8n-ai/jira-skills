---
name: jira-epics
description: "Manages Jira epics using jira-cli. Creates epics, lists epic issues, adds/removes issues from epics. Use when organizing work into epics, tracking epic progress, or managing epic backlogs."
---

# Jira Epic Management

Manages Jira epics using the `jira` CLI tool.

## Prerequisites

- `jira` CLI must be installed and configured
- Epic issue type must be available in your project

## Core Commands

### List Epics

```sh
# List epics in explorer view (interactive)
jira epic list

# List epics in table view
jira epic list --table

# Plain output for scripting
jira epic list --plain --no-headers
```

### Filter Epics

All issue list filters work for epics:

```sh
# Epics reported by me
jira epic list -r$(jira me)

# Open epics
jira epic list -sOpen

# High priority epics
jira epic list -yHigh

# Epics created this month
jira epic list --created month
```

### View Epic Issues

```sh
# List all issues in an epic
jira epic list EPIC-KEY

# Unassigned high priority issues in epic
jira epic list EPIC-KEY -ax -yHigh

# Epic issues ordered by rank
jira epic list EPIC-KEY --order-by rank --reverse

# Bugs in epic
jira epic list EPIC-KEY -tBug

# My issues in epic
jira epic list EPIC-KEY -a$(jira me)
```

### Create Epic

```sh
# Interactive creation
jira epic create

# Non-interactive with parameters
jira epic create -n"Epic Name" -s"Epic Summary" -yHigh -b"Description" --no-input

# Create with labels
jira epic create -n"Q1 Goals" -s"Q1 2024 Objectives" -lquarterly -lgoals
```

**Note:** Epic creation requires the epic name (`-n`) in addition to summary (`-s`).

### Add Issues to Epic

```sh
# Interactive add
jira epic add

# Add specific issues to epic
jira epic add EPIC-KEY ISSUE-1 ISSUE-2 ISSUE-3
```

**Note:** You can add up to 50 issues at once.

### Remove Issues from Epic

```sh
# Interactive remove
jira epic remove

# Remove specific issues from epic
jira epic remove ISSUE-1 ISSUE-2
```

**Note:** You can remove up to 50 issues at once.

### Attach Issue to Epic During Creation

```sh
# Create issue and attach to epic
jira issue create -tStory -s"New Story" -PEPIC-42
```

## Scripting Examples

### Get Epic Progress

```sh
#!/usr/bin/env bash
EPIC_KEY="$1"

total=$(jira epic list "$EPIC_KEY" --plain --no-headers | wc -l)
done=$(jira epic list "$EPIC_KEY" -sDone --plain --no-headers | wc -l)

echo "Epic $EPIC_KEY: $done/$total issues done"
```

### List All Epics with Issue Counts

```sh
#!/usr/bin/env bash
epics=$(jira epic list --plain --columns key,summary --no-headers)

echo "${epics}" | while IFS=$'\t' read -r key summary; do
  count=$(jira epic list "$key" --plain --no-headers 2>/dev/null | wc -l)
  printf "%s (%d issues): %s\n" "$key" $((count)) "$summary"
done
```

### Find Epics Without Issues

```sh
#!/usr/bin/env bash
jira epic list --plain --columns key --no-headers | while read -r key; do
  count=$(jira epic list "$key" --plain --no-headers 2>/dev/null | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "$key has no issues"
  fi
done
```

## Navigation Keys (Interactive Mode)

- `j/k` or arrows: Navigate
- `w` or `TAB`: Toggle sidebar/content focus
- `v`: View issue details
- `m`: Transition issue
- `ENTER`: Open in browser
- `CTRL+r` or `F5`: Refresh
- `q/ESC`: Quit
