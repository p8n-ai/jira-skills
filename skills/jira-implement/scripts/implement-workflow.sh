#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Implementation Workflow Orchestrator
# Manages the full feature implementation workflow with AI delegation
# ============================================================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMON_SCRIPTS_DIR="${SKILLS_ROOT}/jira-common/scripts"

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_JIRA_ERROR=2
EXIT_USER_ABORT=3
EXIT_EXECUTION_ERROR=4

# Global state
ISSUE_KEY=""
AUTO_APPROVE=false
ISSUE_DATA=""
SUMMARY=""
DESCRIPTION=""
ISSUE_TYPE=""
COMMENTS=""
ATTACHMENT_PATHS=""
USER_CONTEXT=""
BRANCH_NAME=""
IMPLEMENTATION_PLAN=""
PLAN_PATH=""

# ============================================================================
# Usage / Help
# ============================================================================

usage() {
  cat <<'EOF'
Usage: implement-workflow.sh [ISSUE-KEY] [OPTIONS]

Implementation Workflow Orchestrator - Manages full feature implementation workflow with AI delegation.

ARGUMENTS:
  ISSUE-KEY               Jira issue key (e.g., PROJ-123). If not provided, prompts interactively.

OPTIONS:
  --auto-approve          Skip approval gates and execute automatically
  -h, --help              Show this help message

WORKFLOW STEPS:
  1. Get Ticket        - Accept issue key (arg or prompt)
  2. Fetch Details     - Retrieve ticket info from Jira
  3. Download Files    - Get all attachments (designs, mockups)
  4. Context Gather    - Accept additional user context
  5. Git Branch        - Create/switch to feature branch
  6. AI Planning       - Delegate implementation planning to AI agent (manual)
  7. Save Plan         - Persist implementation plan as markdown
  8. Approval Gate     - Review and approve plan
  9. Step Execution    - Execute plan steps with supervision
  10. Completion       - Summary and Jira comment

EXIT CODES:
  0  Success
  1  Invalid arguments
  2  Jira CLI error
  3  User abort
  4  Execution error

EXAMPLES:
  # Interactive mode
  implement-workflow.sh

  # Direct issue key
  implement-workflow.sh PROJ-123

  # Auto-approve mode (for CI/automation)
  implement-workflow.sh PROJ-123 --auto-approve

ENVIRONMENT:
  Requires: jira CLI (configured), git, python3
  Optional: JIRA_API_TOKEN (for attachments)

EOF
}

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
  local title="$1"
  echo ""
  echo "============================================================================"
  echo "  $title"
  echo "============================================================================"
  echo ""
}

print_step() {
  local step_num="$1"
  local step_name="$2"
  echo ""
  echo "────────────────────────────────────────────────────────────────────────────"
  echo "  Step $step_num: $step_name"
  echo "────────────────────────────────────────────────────────────────────────────"
  echo ""
}

print_success() {
  echo "✓ $1"
}

print_error() {
  echo "✗ $1" >&2
}

print_warning() {
  echo "⚠ $1" >&2
}

print_info() {
  echo "ℹ $1"
}

# Validate Jira issue key format
validate_issue_key() {
  local key="$1"
  if [[ ! "$key" =~ ^[A-Z]+-[0-9]+$ ]]; then
    return 1
  fi
  return 0
}

# Read multi-line input until EOF (Ctrl+D)
read_multiline() {
  local input=""
  while IFS= read -r line; do
    if [[ -z "$input" ]]; then
      input="$line"
    else
      input="$input"$'\n'"$line"
    fi
  done
  echo "$input"
}

# Check if required tools are available
check_dependencies() {
  local missing=()
  
  if ! command -v jira &> /dev/null; then
    missing+=("jira CLI")
  fi
  
  if ! command -v git &> /dev/null; then
    missing+=("git")
  fi
  
  if ! command -v python3 &> /dev/null; then
    missing+=("python3")
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    print_error "Missing required tools: ${missing[*]}"
    exit $EXIT_INVALID_ARGS
  fi
}

# ============================================================================
# Step 1: Get Ticket
# ============================================================================

step_get_ticket() {
  print_step "1" "Get Ticket"
  
  if [[ -n "$ISSUE_KEY" ]]; then
    print_info "Using provided issue key: $ISSUE_KEY"
  else
    echo -n "Enter Jira ticket number: "
    read -r ISSUE_KEY
    
    if [[ -z "$ISSUE_KEY" ]]; then
      print_error "No issue key provided"
      exit $EXIT_INVALID_ARGS
    fi
  fi
  
  # Normalize to uppercase
  ISSUE_KEY="${ISSUE_KEY^^}"
  
  if ! validate_issue_key "$ISSUE_KEY"; then
    print_error "Invalid issue key format: $ISSUE_KEY (expected: [A-Z]+-[0-9]+)"
    exit $EXIT_INVALID_ARGS
  fi
  
  print_success "Issue key validated: $ISSUE_KEY"
}

# ============================================================================
# Step 2: Fetch Ticket Details
# ============================================================================

step_fetch_details() {
  print_step "2" "Fetch Ticket Details"
  
  print_info "Fetching issue details from Jira..."
  
  if ! ISSUE_DATA=$(jira issue view "$ISSUE_KEY" --raw 2>&1); then
    print_error "Failed to fetch issue $ISSUE_KEY from Jira"
    echo "$ISSUE_DATA" >&2
    exit $EXIT_JIRA_ERROR
  fi
  
  # Parse fields using Python
  SUMMARY=$(echo "$ISSUE_DATA" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("fields", {}).get("summary", ""))
except:
    pass
' 2>/dev/null || echo "")

  DESCRIPTION=$(echo "$ISSUE_DATA" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    desc = data.get("fields", {}).get("description", "") or ""
    # Handle Atlassian Document Format (ADF)
    if isinstance(desc, dict):
        # Extract text content from ADF
        def extract_text(node):
            if isinstance(node, str):
                return node
            if isinstance(node, dict):
                text = node.get("text", "")
                content = node.get("content", [])
                return text + "".join(extract_text(c) for c in content)
            if isinstance(node, list):
                return "".join(extract_text(n) for n in node)
            return ""
        desc = extract_text(desc)
    print(desc)
except:
    pass
' 2>/dev/null || echo "")

  ISSUE_TYPE=$(echo "$ISSUE_DATA" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("fields", {}).get("issuetype", {}).get("name", ""))
except:
    pass
' 2>/dev/null || echo "")

  COMMENTS=$(echo "$ISSUE_DATA" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    comments = data.get("fields", {}).get("comment", {}).get("comments", [])
    for c in comments[-10:]:  # Last 10 comments
        author = c.get("author", {}).get("displayName", "Unknown")
        body = c.get("body", "")
        # Handle ADF body
        if isinstance(body, dict):
            def extract_text(node):
                if isinstance(node, str):
                    return node
                if isinstance(node, dict):
                    text = node.get("text", "")
                    content = node.get("content", [])
                    return text + "".join(extract_text(c) for c in content)
                if isinstance(node, list):
                    return "".join(extract_text(n) for n in node)
                return ""
            body = extract_text(body)
        print(f"[{author}]: {body}")
        print("---")
except:
    pass
' 2>/dev/null || echo "")

  # Display summary
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────────────┐"
  echo "│ TICKET SUMMARY                                                          │"
  echo "├─────────────────────────────────────────────────────────────────────────┤"
  printf "│ %-71s │\n" "Key: $ISSUE_KEY"
  printf "│ %-71s │\n" "Type: $ISSUE_TYPE"
  echo "├─────────────────────────────────────────────────────────────────────────┤"
  echo "│ Summary:                                                                │"
  echo "$SUMMARY" | fold -w 71 | while read -r line; do
    printf "│ %-71s │\n" "$line"
  done
  echo "├─────────────────────────────────────────────────────────────────────────┤"
  echo "│ Description:                                                            │"
  if [[ -n "$DESCRIPTION" ]]; then
    echo "$DESCRIPTION" | head -20 | fold -w 71 | while read -r line; do
      printf "│ %-71s │\n" "$line"
    done
  else
    printf "│ %-71s │\n" "(No description)"
  fi
  echo "└─────────────────────────────────────────────────────────────────────────┘"
  echo ""
  
  print_success "Ticket details fetched"
}

# ============================================================================
# Step 3: Download Attachments
# ============================================================================

step_download_attachments() {
  print_step "3" "Download Attachments"
  
  local download_script="${COMMON_SCRIPTS_DIR}/download-all-attachments.sh"
  
  if [[ ! -x "$download_script" ]]; then
    print_warning "Attachment download script not found: $download_script"
    print_info "Skipping attachment download"
    ATTACHMENT_PATHS="[]"
    return
  fi
  
  if [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    print_warning "JIRA_API_TOKEN not set - skipping attachment download"
    ATTACHMENT_PATHS="[]"
    return
  fi
  
  print_info "Downloading attachments (designs, mockups, etc.)..."
  
  local download_output
  if download_output=$("$download_script" --issue "$ISSUE_KEY" 2>&1); then
    # Last line is the JSON array
    ATTACHMENT_PATHS=$(echo "$download_output" | tail -1)
    
    # Count downloaded files
    local count
    count=$(echo "$ATTACHMENT_PATHS" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "0")
    
    print_success "Downloaded $count attachment(s)"
    
    if [[ "$count" -gt 0 ]]; then
      echo "Files:"
      echo "$ATTACHMENT_PATHS" | python3 -c '
import json, sys
paths = json.load(sys.stdin)
for p in paths:
    print(f"  - {p}")
' 2>/dev/null || true
    fi
  else
    print_warning "Failed to download attachments"
    echo "$download_output" >&2
    ATTACHMENT_PATHS="[]"
  fi
}

# ============================================================================
# Step 4: Additional Context
# ============================================================================

step_gather_context() {
  print_step "4" "Additional Context"
  
  echo "Any additional context for implementation? (Enter to skip, Ctrl+D to finish multi-line input)"
  echo "Examples: tech constraints, existing patterns to follow, related features..."
  echo ""
  
  # Read from terminal if available
  if [[ -t 0 ]]; then
    USER_CONTEXT=$(read_multiline 2>/dev/null || echo "")
  else
    USER_CONTEXT=""
  fi
  
  if [[ -n "$USER_CONTEXT" ]]; then
    print_success "Additional context captured (${#USER_CONTEXT} characters)"
  else
    print_info "No additional context provided"
  fi
}

# ============================================================================
# Step 5: Git Branch
# ============================================================================

step_git_branch() {
  print_step "5" "Git Branch"
  
  # Check if we're in a git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_warning "Not in a git repository - skipping branch creation"
    BRANCH_NAME="(not in git repo)"
    return
  fi
  
  local branch_script="${COMMON_SCRIPTS_DIR}/create-branch.sh"
  
  if [[ ! -x "$branch_script" ]]; then
    print_warning "Branch creation script not found: $branch_script"
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    print_info "Current branch: $BRANCH_NAME"
    return
  fi
  
  print_info "Creating/switching to feature branch..."
  
  if BRANCH_NAME=$("$branch_script" --issue "$ISSUE_KEY" 2>&1 | tail -1); then
    print_success "Branch: $BRANCH_NAME"
  else
    print_warning "Failed to create branch"
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    print_info "Staying on current branch: $BRANCH_NAME"
  fi
}

# ============================================================================
# Step 6: AI Implementation Planning
# ============================================================================

step_ai_planning() {
  print_step "6" "AI Implementation Planning"
  
  # Create temp file with context
  local context_file="/tmp/implement-context-${ISSUE_KEY}.txt"
  
  # Format attachment paths
  local formatted_attachments
  if [[ "$ATTACHMENT_PATHS" != "[]" ]]; then
    formatted_attachments=$(echo "$ATTACHMENT_PATHS" | python3 -c '
import json, sys
paths = json.load(sys.stdin)
for p in paths:
    print(f"- {p}")
' 2>/dev/null || echo "None")
  else
    formatted_attachments="None"
  fi
  
  # Extract acceptance criteria from description (common patterns)
  local acceptance_criteria
  acceptance_criteria=$(echo "$DESCRIPTION" | python3 -c '
import sys
import re

text = sys.stdin.read()

# Common patterns for acceptance criteria
patterns = [
    r"(?i)acceptance criteria[:\s]*\n((?:[-*•]\s*.+\n?)+)",
    r"(?i)ac[:\s]*\n((?:[-*•]\s*.+\n?)+)",
    r"(?i)requirements[:\s]*\n((?:[-*•]\s*.+\n?)+)",
    r"(?i)definition of done[:\s]*\n((?:[-*•]\s*.+\n?)+)",
]

for pattern in patterns:
    match = re.search(pattern, text, re.MULTILINE)
    if match:
        print(match.group(1).strip())
        sys.exit(0)

# If no specific section found, look for bullet points after keywords
keywords = ["should", "must", "when", "given", "then", "expect"]
lines = text.split("\n")
criteria = []
for line in lines:
    line_lower = line.lower()
    if any(kw in line_lower for kw in keywords) and (line.strip().startswith("-") or line.strip().startswith("*") or line.strip().startswith("•")):
        criteria.append(line.strip())

if criteria:
    print("\n".join(criteria))
else:
    print("(Not explicitly defined - extract from description)")
' 2>/dev/null || echo "(Not explicitly defined - extract from description)")
  
  # Build context document - KEY DIFFERENCE: Implementation planning prompt vs RCA
  cat > "$context_file" <<EOF
# Implementation Planning Request

## Ticket: $ISSUE_KEY
Summary: $SUMMARY
Type: $ISSUE_TYPE
Branch: $BRANCH_NAME

## Requirements
$DESCRIPTION

## Acceptance Criteria
$acceptance_criteria

## Comments/Discussion
$COMMENTS

## Design/Mockups
$formatted_attachments

## Additional Context
${USER_CONTEXT:-"None provided"}

## Task
Create a detailed implementation plan for this feature. Provide:

1. **Architecture Decisions**
   - High-level approach
   - Design patterns to use
   - Integration points with existing code

2. **Component Breakdown**
   - New components/modules needed
   - Existing components to modify
   - Data models/schemas required

3. **Implementation Steps** (in order)
   - Numbered list of specific tasks
   - Include file paths where applicable
   - Note any dependencies between steps

4. **Testing Strategy**
   - Unit tests needed
   - Integration tests needed
   - Manual testing scenarios

5. **Edge Cases to Handle**
   - Error scenarios
   - Boundary conditions
   - User experience considerations

Please be thorough and specific. Include file paths and code references where applicable.
Reference any attached designs/mockups in your plan.
EOF

  print_success "Context prepared: $context_file"
  echo ""
  
  echo "┌─────────────────────────────────────────────────────────────────────────┐"
  echo "│ AI IMPLEMENTATION PLANNING DELEGATION                                   │"
  echo "├─────────────────────────────────────────────────────────────────────────┤"
  echo "│ Context file created with all ticket information.                       │"
  echo "│                                                                         │"
  echo "│ Please run the following command manually to get AI planning:           │"
  echo "└─────────────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  omo delegate --subagent librarian --prompt \"\$(cat $context_file)\""
  echo ""
  echo "Or copy the context file path and use your preferred AI tool:"
  echo "  $context_file"
  echo ""
  
  echo "────────────────────────────────────────────────────────────────────────────"
  echo ""
  
  read -p "Press Enter once you have the implementation plan ready... " -r
  
  echo ""
  echo "Paste the implementation plan below (Ctrl+D when done):"
  echo ""
  
  IMPLEMENTATION_PLAN=$(read_multiline)
  
  if [[ -z "$IMPLEMENTATION_PLAN" ]]; then
    print_error "No implementation plan provided"
    exit $EXIT_USER_ABORT
  fi
  
  print_success "Implementation plan received (${#IMPLEMENTATION_PLAN} characters)"
}

# ============================================================================
# Step 7: Save Plan
# ============================================================================

step_save_plan() {
  print_step "7" "Save Plan"
  
  local save_script="${COMMON_SCRIPTS_DIR}/save-plan.sh"
  
  if [[ ! -x "$save_script" ]]; then
    print_warning "Save plan script not found: $save_script"
    
    # Fallback: save locally
    mkdir -p "./plans"
    PLAN_PATH="./plans/${ISSUE_KEY}-implement-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$PLAN_PATH" <<EOF
---
issue: $ISSUE_KEY
type: implement
timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
branch: $BRANCH_NAME
---

$IMPLEMENTATION_PLAN
EOF
    
    print_success "Plan saved (fallback): $PLAN_PATH"
    return
  fi
  
  print_info "Saving implementation plan..."
  
  if PLAN_PATH=$(echo "$IMPLEMENTATION_PLAN" | "$save_script" --issue "$ISSUE_KEY" --type implement 2>&1 | tail -1); then
    print_success "Plan saved: $PLAN_PATH"
  else
    print_error "Failed to save plan"
    exit $EXIT_EXECUTION_ERROR
  fi
}

# ============================================================================
# Step 8: Approval Gate
# ============================================================================

step_approval_gate() {
  print_step "8" "Approval Gate"
  
  echo "┌─────────────────────────────────────────────────────────────────────────┐"
  echo "│ IMPLEMENTATION PLAN FOR REVIEW                                          │"
  echo "└─────────────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "$IMPLEMENTATION_PLAN" | head -100
  
  local line_count
  line_count=$(echo "$IMPLEMENTATION_PLAN" | wc -l | tr -d ' ')
  if [[ "$line_count" -gt 100 ]]; then
    echo ""
    echo "... ($((line_count - 100)) more lines - see full plan at: $PLAN_PATH)"
  fi
  echo ""
  echo "────────────────────────────────────────────────────────────────────────────"
  echo ""
  
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    print_info "Auto-approve enabled - proceeding with execution"
    return
  fi
  
  read -p "Execute this implementation plan? [y/N]: " -r approval
  approval="${approval:-N}"
  
  if [[ ! "$approval" =~ ^[Yy]$ ]]; then
    print_info "Plan execution declined"
    echo ""
    echo "Plan saved to: $PLAN_PATH"
    echo "You can review and execute manually later."
    exit $EXIT_SUCCESS
  fi
  
  print_success "Plan approved for execution"
}

# ============================================================================
# Step 9: Step-by-Step Execution
# ============================================================================

step_execute_plan() {
  print_step "9" "Step-by-Step Execution"
  
  # Extract executable steps from plan
  # Look for numbered lists (1. xxx, 2. xxx) or checkboxes (- [ ] xxx)
  local steps
  steps=$(echo "$IMPLEMENTATION_PLAN" | grep -E '^\s*(([0-9]+\.)|(-\s*\[[ x]\]))' | head -50 || true)
  
  if [[ -z "$steps" ]]; then
    print_warning "No executable steps found in plan"
    print_info "The plan may be informational only, or steps are not in numbered format"
    return
  fi
  
  local step_count
  step_count=$(echo "$steps" | wc -l | tr -d ' ')
  print_info "Found $step_count executable step(s)"
  echo ""
  
  local completed=0
  local skipped=0
  local errors=0
  local step_num=0
  
  while IFS= read -r step; do
    ((step_num++))
    
    # Clean up step text
    local step_text
    step_text=$(echo "$step" | sed 's/^\s*[0-9]*\.\s*//' | sed 's/^\s*-\s*\[[ x]\]\s*//')
    
    echo ""
    echo "📌 **Step $step_num:** $step_text"
    echo ""
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
      print_info "Auto-approve: Action Required - $step_text"
      ((completed++))
      continue
    fi
    
    read -p "Execute this step? [Y/n/skip/abort]: " -r response
    response="${response:-Y}"
    
    case "$response" in
      [Yy]|[Yy]es)
        echo ""
        echo "**Action Required:** Please implement: $step_text"
        echo ""
        read -p "Step completed successfully? [y/N/error]: " -r completion
        completion="${completion:-N}"
        
        case "$completion" in
          [Yy]|[Yy]es)
            print_success "Step $step_num completed"
            ((completed++))
            ;;
          error|Error|ERROR)
            echo "Enter error details (Ctrl+D when done):"
            local error_details
            error_details=$(read_multiline)
            
            local error_script="${COMMON_SCRIPTS_DIR}/post-error-to-jira.sh"
            if [[ -x "$error_script" ]]; then
              "$error_script" --issue "$ISSUE_KEY" --step "$step_text" --error "$error_details" || true
            fi
            
            print_error "Step $step_num failed"
            ((errors++))
            ;;
          *)
            print_warning "Step $step_num not completed"
            ((skipped++))
            ;;
        esac
        ;;
      skip|Skip|SKIP|[Ss])
        print_info "Step $step_num skipped"
        ((skipped++))
        ;;
      abort|Abort|ABORT|[Aa])
        print_warning "Execution aborted by user"
        break
        ;;
      *)
        print_info "Step $step_num skipped (unrecognized response)"
        ((skipped++))
        ;;
    esac
  done <<< "$steps"
  
  echo ""
  echo "────────────────────────────────────────────────────────────────────────────"
  echo ""
  echo "Execution Summary:"
  echo "  Completed: $completed"
  echo "  Skipped:   $skipped"
  echo "  Errors:    $errors"
  echo "  Total:     $step_count"
}

# ============================================================================
# Step 10: Completion
# ============================================================================

step_completion() {
  print_step "10" "Completion"
  
  echo "┌─────────────────────────────────────────────────────────────────────────┐"
  echo "│ IMPLEMENTATION WORKFLOW COMPLETE                                        │"
  echo "├─────────────────────────────────────────────────────────────────────────┤"
  printf "│ %-71s │\n" "Issue: $ISSUE_KEY"
  printf "│ %-71s │\n" "Branch: $BRANCH_NAME"
  printf "│ %-71s │\n" "Plan: $PLAN_PATH"
  echo "└─────────────────────────────────────────────────────────────────────────┘"
  echo ""
  
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    print_info "Auto-approve: Skipping Jira comment prompt"
    return
  fi
  
  read -p "Add completion comment to Jira? [Y/n]: " -r add_comment
  add_comment="${add_comment:-Y}"
  
  if [[ "$add_comment" =~ ^[Yy]$ ]]; then
    local comment="✅ **Feature Implementation Completed**

Branch: \`$BRANCH_NAME\`
Plan: \`$PLAN_PATH\`

Feature implementation completed. Plan executed.

_Completed via jira-implement workflow_"
    
    if jira issue comment add "$ISSUE_KEY" "$comment" --no-input 2>/dev/null; then
      print_success "Completion comment added to $ISSUE_KEY"
    else
      print_warning "Failed to add comment to Jira"
    fi
  fi
  
  echo ""
  print_success "Implementation workflow completed for $ISSUE_KEY"
}

# ============================================================================
# Main
# ============================================================================

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit $EXIT_SUCCESS
        ;;
      --auto-approve)
        AUTO_APPROVE=true
        shift
        ;;
      -*)
        print_error "Unknown option: $1"
        usage >&2
        exit $EXIT_INVALID_ARGS
        ;;
      *)
        if [[ -z "$ISSUE_KEY" ]]; then
          ISSUE_KEY="$1"
        else
          print_error "Unexpected argument: $1"
          usage >&2
          exit $EXIT_INVALID_ARGS
        fi
        shift
        ;;
    esac
  done
  
  print_header "Implementation Workflow Orchestrator v${VERSION}"
  
  check_dependencies
  
  # Execute workflow steps
  step_get_ticket
  step_fetch_details
  step_download_attachments
  step_gather_context
  step_git_branch
  step_ai_planning
  step_save_plan
  step_approval_gate
  step_execute_plan
  step_completion
  
  exit $EXIT_SUCCESS
}

# Run main
main "$@"
