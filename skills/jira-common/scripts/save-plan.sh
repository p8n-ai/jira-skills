#!/bin/bash
set -euo pipefail

# Plan persistence script - saves execution plans as markdown files with metadata

usage() {
    cat <<EOF
Usage: $(basename "$0") --issue ISSUE-123 --type rca|implement [OPTIONS]

Save execution plans as markdown files with frontmatter metadata.

REQUIRED:
  --issue ISSUE-123      Issue key (format: [A-Z]+-[0-9]+)
  --type TYPE            Plan type: rca or implement

OPTIONAL:
  --content "TEXT"       Plan content (reads from stdin if not provided)
  --branch NAME          Git branch name (auto-detected if not provided)
  --help                 Show this help message

EXAMPLES:
  # With explicit content
  save-plan.sh --issue JIRA-123 --type rca --content "Root cause is X"

  # Reading from stdin
  cat plan.txt | save-plan.sh --issue JIRA-123 --type implement

  # With branch name
  save-plan.sh --issue JIRA-123 --type rca --content "Analysis" --branch feature/branch

EXIT CODES:
  0  Success
  1  Invalid arguments
  2  Write error
EOF
    exit "${1:-0}"
}

# Parse arguments
ISSUE=""
TYPE=""
CONTENT=""
BRANCH=""
READ_STDIN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue)
            ISSUE="$2"
            shift 2
            ;;
        --type)
            TYPE="$2"
            shift 2
            ;;
        --content)
            CONTENT="$2"
            READ_STDIN=false
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --help)
            usage 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ISSUE" ]]; then
    echo "Error: --issue is required" >&2
    usage 1
fi

if [[ -z "$TYPE" ]]; then
    echo "Error: --type is required" >&2
    usage 1
fi

# Validate issue key format
if ! [[ "$ISSUE" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "Error: Invalid issue key format: $ISSUE (expected: [A-Z]+-[0-9]+)" >&2
    exit 1
fi

# Validate type
if [[ "$TYPE" != "rca" && "$TYPE" != "implement" ]]; then
    echo "Error: Invalid type: $TYPE (must be 'rca' or 'implement')" >&2
    exit 1
fi

# Read content from stdin if not provided
if [[ -z "$CONTENT" && ! -t 0 ]]; then
    CONTENT=$(cat)
fi

# Auto-detect branch if not provided
if [[ -z "$BRANCH" ]]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    else
        BRANCH="unknown"
    fi
fi

# Create plans directory
if ! mkdir -p "./plans" 2>/dev/null; then
    echo "Error: Failed to create ./plans directory" >&2
    exit 2
fi

# Generate filename with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
FILENAME="./plans/${ISSUE}-${TYPE}-${TIMESTAMP}.md"

# Ensure unique filename (shouldn't happen with milliseconds, but be safe)
if [[ -f "$FILENAME" ]]; then
    FILENAME="./plans/${ISSUE}-${TYPE}-${TIMESTAMP}-$$.md"
fi

# Generate ISO 8601 timestamp for metadata
ISO_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\([0-9][0-9]\)$/:\1/')

# Create file with frontmatter
{
    cat <<FRONTMATTER
---
issue: ${ISSUE}
type: ${TYPE}
timestamp: ${ISO_TIMESTAMP}
branch: ${BRANCH}
user: $(whoami)
---

FRONTMATTER
    echo "$CONTENT"
} > "$FILENAME" || {
    echo "Error: Failed to write plan file: $FILENAME" >&2
    exit 2
}

# Make file read-only
chmod 444 "$FILENAME" || {
    echo "Error: Failed to set read-only permissions on plan file" >&2
    exit 2
}

# Output saved path
echo "$FILENAME"

exit 0
