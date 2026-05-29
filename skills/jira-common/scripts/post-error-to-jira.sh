#!/bin/bash
set -euo pipefail

# ============================================================================
# post-error-to-jira.sh
# Interactive error logging script - posts execution errors to Jira tickets
# ============================================================================

ISSUE=""
STEP=""
ERROR=""
ERROR_LOG=""
AUTO_POST=false

# ============================================================================
# Usage
# ============================================================================

usage() {
  cat <<EOF
Usage: post-error-to-jira.sh --issue ISSUE-123 --step "step name" [--error "message" | --error-log PATH] [--auto-post] [--help]

Interactive script to post execution errors to Jira tickets.

REQUIRED ARGUMENTS:
  --issue ISSUE-123        Jira issue key (e.g., PROJ-123)
  --step "step name"       Name of the step where error occurred
  --error "message"        Error message to post (mutually exclusive with --error-log)
  --error-log PATH         Path to error log file to read (mutually exclusive with --error)

OPTIONAL ARGUMENTS:
  --auto-post             Skip interactive prompt and post automatically
  --help                  Display this help message

EXIT CODES:
  0                       Error posted to Jira OR user skipped (both are success)
  1                       Invalid arguments or missing required parameters
  2                       Jira CLI error or failure to post

EXAMPLES:
  # Interactive prompt with direct error message
  post-error-to-jira.sh --issue PROJ-123 --step "Build compilation" --error "gcc: command not found"

  # Read error from file with interactive prompt
  post-error-to-jira.sh --issue PROJ-123 --step "Deploy" --error-log /tmp/error.log

  # Auto-post without prompting
  post-error-to-jira.sh --issue PROJ-123 --step "Test" --error "All tests failed" --auto-post

EOF
}

# ============================================================================
# Parse arguments
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE="$2"
      shift 2
      ;;
    --step)
      STEP="$2"
      shift 2
      ;;
    --error)
      ERROR="$2"
      shift 2
      ;;
    --error-log)
      ERROR_LOG="$2"
      shift 2
      ;;
    --auto-post)
      AUTO_POST=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ============================================================================
# Validate required arguments
# ============================================================================

if [[ -z "$ISSUE" ]]; then
  echo "Error: --issue is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "$STEP" ]]; then
  echo "Error: --step is required" >&2
  usage >&2
  exit 1
fi

# Check that exactly one of --error or --error-log is provided
if [[ -z "$ERROR" && -z "$ERROR_LOG" ]]; then
  echo "Error: Either --error or --error-log must be provided" >&2
  usage >&2
  exit 1
fi

if [[ -n "$ERROR" && -n "$ERROR_LOG" ]]; then
  echo "Error: --error and --error-log are mutually exclusive" >&2
  usage >&2
  exit 1
fi

# ============================================================================
# Read error content
# ============================================================================

if [[ -n "$ERROR_LOG" ]]; then
  if [[ ! -f "$ERROR_LOG" ]]; then
    echo "Error: Error log file not found: $ERROR_LOG" >&2
    exit 1
  fi
  ERROR="$(cat "$ERROR_LOG")"
fi

# ============================================================================
# Check jira CLI availability
# ============================================================================

if ! command -v jira &> /dev/null; then
  echo "Error: jira CLI is not installed or not in PATH" >&2
  exit 2
fi

# ============================================================================
# Build comment message
# ============================================================================

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

COMMENT="❌ **Error in step: $STEP**

\`\`\`
$ERROR
\`\`\`

_Posted automatically by jira-rca/jira-implement workflow_
_Timestamp: $TIMESTAMP"

# ============================================================================
# Interactive prompt (unless --auto-post)
# ============================================================================

if [[ "$AUTO_POST" != "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Error to post to Jira issue: $ISSUE"
  echo "Step: $STEP"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Error message:"
  echo "---"
  echo "$ERROR"
  echo "---"
  echo ""
  
  read -p "Post error to Jira issue $ISSUE? [y/N] " -r REPLY
  REPLY="${REPLY:-N}"
  
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Skipped posting error"
    exit 0
  fi
fi

# ============================================================================
# Post comment to Jira
# ============================================================================

if ! jira issue comment add "$ISSUE" "$COMMENT" --internal --no-input 2>/dev/null; then
  echo "Error: Failed to post error comment to Jira issue $ISSUE" >&2
  exit 2
fi

echo "✓ Error posted to $ISSUE"
exit 0
