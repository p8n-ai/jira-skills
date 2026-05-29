#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-branch.sh [--issue ISSUE-KEY] [--help]

Creates or switches to a git branch based on Jira issue type.

Options:
  --issue ISSUE-KEY   Jira issue key (e.g., PROJ-123). Required unless --help.
  --help, -h          Show this help message.

Branch Naming:
  - Detects issue type from Jira
  - Prefix: Bug→bugfix/, Story/Task→feature/, Epic→epic/, Default→task/
  - Format: {prefix}ISSUE-KEY-{slug}
  - Slug: lowercase summary with hyphens, special chars removed

Behavior:
  - Checks for dirty working directory (offers to stash)
  - If branch exists: prompts to switch (interactive)
  - If branch missing: creates new branch
  - Outputs final branch name to stdout

Examples:
  create-branch.sh --issue PROJ-123
  create-branch.sh --issue PROJ-456 --help

Environment:
  - Must be run from within a git repository
  - Requires: git, jira CLI
EOF
}

# Configuration
issue_key=""
verbose=0

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_key="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Validation: issue key required
if [[ -z "$issue_key" ]]; then
  echo "Error: --issue ISSUE-KEY is required" >&2
  usage >&2
  exit 1
fi

# Validation: git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 2
fi

# Validation: jira CLI available
if ! command -v jira &> /dev/null; then
  echo "Error: jira CLI not found. Install and configure with 'jira init'" >&2
  exit 2
fi

# Fetch issue details from Jira
if ! issue_data=$(jira issue view "$issue_key" --raw 2>/dev/null); then
  echo "Error: Failed to fetch issue $issue_key from Jira. Issue may not exist or jira CLI not configured." >&2
  exit 3
fi

# Parse issue type from raw JSON output
# Raw format includes: "type":{"name":"Bug",...}
issue_type=$(printf '%s' "$issue_data" | python3 -c '
import sys, json
try:
  data = json.load(sys.stdin)
  issue_type = data.get("fields", {}).get("issuetype", {}).get("name", "")
  if not issue_type:
    raise SystemExit(1)
  print(issue_type)
except (json.JSONDecodeError, KeyError, AttributeError):
  raise SystemExit(1)
' 2>/dev/null || true)

if [[ -z "$issue_type" ]]; then
  echo "Error: Could not parse issue type from Jira response" >&2
  exit 3
fi

# Parse summary
summary=$(printf '%s' "$issue_data" | python3 -c '
import sys, json
try:
  data = json.load(sys.stdin)
  summary = data.get("fields", {}).get("summary", "")
  if not summary:
    raise SystemExit(1)
  print(summary)
except (json.JSONDecodeError, KeyError, AttributeError):
  raise SystemExit(1)
' 2>/dev/null || true)

if [[ -z "$summary" ]]; then
  echo "Error: Could not parse summary from Jira response" >&2
  exit 3
fi

# Determine branch prefix based on issue type
case "$issue_type" in
  Bug)
    prefix="bugfix/"
    ;;
  Story|Task)
    prefix="feature/"
    ;;
  Epic)
    prefix="epic/"
    ;;
  *)
    prefix="task/"
    ;;
esac

# Create slug from summary: lowercase, hyphens, remove special chars
# Keep alphanumerics and spaces, convert spaces to hyphens, lowercase
slug=$(printf '%s' "$summary" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 _-]//g' \
  | sed 's/_/-/g' \
  | sed 's/  */ /g' \
  | xargs echo \
  | tr ' ' '-' \
  | sed 's/-\{2,\}/-/g')

# Build final branch name
branch_name="${prefix}${issue_key,,}-${slug}"

# Limit length (git branch names can be very long, but 255 is practical limit)
if [[ ${#branch_name} -gt 255 ]]; then
  # Truncate slug part to fit
  max_slug_len=$((255 - ${#prefix} - ${#issue_key} - 2))
  slug="${slug:0:$max_slug_len}"
  branch_name="${prefix}${issue_key,,}-${slug}"
fi

# Check for dirty working directory
if ! git diff-index --quiet HEAD --; then
  echo "Warning: Working directory has uncommitted changes" >&2
  read -p "Stash changes before switching branches? [Y/n] " -r stash_response
  stash_response="${stash_response:-y}"
  
  if [[ "$stash_response" =~ ^[Yy]$ ]]; then
    git stash push -m "pre-branch-switch: $(date '+%Y-%m-%d %H:%M:%S')"
  else
    echo "Warning: Proceeding with dirty working directory" >&2
  fi
fi

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/$branch_name"; then
  # Branch exists - prompt to switch
  read -p "Branch '$branch_name' exists. Switch to it? [Y/n] " -r switch_response
  switch_response="${switch_response:-y}"
  
  if [[ "$switch_response" =~ ^[Yy]$ ]]; then
    if ! git checkout "$branch_name" > /dev/null 2>&1; then
      echo "Error: Failed to checkout branch '$branch_name'" >&2
      exit 4
    fi
  else
    echo "Branch not switched. Current branch: $(git rev-parse --abbrev-ref HEAD)" >&2
    exit 0
  fi
else
  # Create new branch
  if ! git checkout -b "$branch_name" > /dev/null 2>&1; then
    echo "Error: Failed to create branch '$branch_name'" >&2
    exit 4
  fi
fi

# Output final branch name to stdout
printf '%s\n' "$branch_name"
exit 0
