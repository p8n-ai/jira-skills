---
name: jira-sprints
description: "Manages Jira sprints using jira-cli. Lists sprints, views sprint issues, adds issues to sprints. Use when working with agile sprints, sprint planning, or tracking sprint progress."
---

# Jira Sprint Management

Manages Jira sprints using the `jira` CLI tool.

## Prerequisites

- `jira` CLI must be installed and configured
- Project must use Scrum board with sprints enabled

## Core Commands

### List Sprints

```sh
# List sprints in explorer view (interactive)
jira sprint list

# List sprints in table view
jira sprint list --table

# Plain output for scripting
jira sprint list --table --plain --no-headers
```

### Sprint Filters

| Flag | Description | Example |
|------|-------------|---------|
| `--current` | Current active sprint | `jira sprint list --current` |
| `--prev` | Previous sprint | `jira sprint list --prev` |
| `--next` | Next planned sprint | `jira sprint list --next` |
| `--state` | Sprint state filter | `--state future,active` |

### View Sprint Issues

```sh
# Issues in current sprint
jira sprint list --current

# Issues in current sprint assigned to me
jira sprint list --current -a$(jira me)

# Issues in specific sprint (use sprint ID from `jira sprint list`)
jira sprint list SPRINT_ID

# High priority issues in sprint assigned to me
jira sprint list SPRINT_ID -yHigh -a$(jira me)

# Sprint issues ordered by rank
jira sprint list SPRINT_ID --order-by rank --reverse
```

### Add Issues to Sprint

```sh
# Interactive add
jira sprint add

# Add specific issues to sprint
jira sprint add SPRINT_ID ISSUE-1 ISSUE-2 ISSUE-3
```

**Note:** You can add up to 50 issues at once.

## Issue Filters in Sprints

All issue list filters work within sprint context:

```sh
# My unfinished issues in current sprint
jira sprint list --current -a$(jira me) -s~Done

# Bugs in current sprint
jira sprint list --current -tBug

# High priority items in next sprint
jira sprint list --next -yHigh
```

## Scripting Examples

### Get Sprint IDs

```sh
# Get sprint IDs and names
jira sprint list --table --plain --columns id,name --no-headers
```

### Count Issues per Sprint

```sh
#!/usr/bin/env bash
sprints=$(jira sprint list --table --plain --columns id,name --no-headers)

echo "${sprints}" | while IFS=$'\t' read -r id name; do
  count=$(jira sprint list "${id}" --plain --no-headers 2>/dev/null | wc -l)
  printf "%s: %d issues\n" "${name}" $((count))
done
```

### Current Sprint Progress

```sh
# Total issues in current sprint
jira sprint list --current --plain --no-headers | wc -l

# Done issues in current sprint
jira sprint list --current -sDone --plain --no-headers | wc -l
```

### Find Unassigned Issues in Sprint

```sh
jira sprint list --current -ax --plain
```

## Navigation Keys (Interactive Mode)

- `j/k` or arrows: Navigate
- `w` or `TAB`: Toggle sidebar/content focus
- `v`: View issue details
- `m`: Transition issue
- `ENTER`: Open in browser
- `CTRL+r` or `F5`: Refresh
- `q/ESC`: Quit
