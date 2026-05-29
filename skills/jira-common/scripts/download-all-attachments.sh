#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  download-all-attachments.sh --issue <issue-key> [--out <output-path>]

Required:
  --issue     Jira issue key (e.g., PROJ-123)

Optional:
  --out       Output directory (default: a new temporary directory)

Returns:
  JSON array of downloaded file paths on stdout
  Progress messages on stderr

Exit codes:
  0 = success
  1 = invalid arguments
  2 = Jira CLI error
  3 = download failures (some attachments failed)

Env vars:
  JIRA_API_TOKEN must be set
  JIRA_BASE_URL must be set for attachment downloads
  JIRA_EMAIL must be set for attachment downloads

Examples:
  # Download all attachments to default directory
  download-all-attachments.sh --issue PROJ-123

  # Download to specific directory
  download-all-attachments.sh --issue PROJ-123 --out /tmp/attachments

  # Parse output
  files=$(download-all-attachments.sh --issue PROJ-123 | jq -r '.[]')
EOF
}

issue_key=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_key="$2"
      shift 2
      ;;
    --out)
      output_dir="$2"
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

if [[ -z "$issue_key" ]]; then
  echo "Missing required --issue argument." >&2
  usage >&2
  exit 1
fi

if [[ -z "${JIRA_API_TOKEN:-}" ]]; then
  echo "Missing JIRA_API_TOKEN env var." >&2
  exit 1
fi

# Determine output directory with priority
if [[ -n "$output_dir" ]]; then
  target_dir="$output_dir"
else
  target_dir="$(mktemp -d "${TMPDIR:-/tmp}/jira-skills-attachments.XXXXXX")"
fi

# Create output directory
mkdir -p "$target_dir"

# Get the directory where this script is located (for finding download-attachment.sh)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
download_script="${script_dir}/download-attachment.sh"

# Handle the usual skills layout: <skills-root>/jira-common/scripts and <skills-root>/jira-issues/scripts.
if [[ ! -f "$download_script" ]]; then
  skills_root="$(cd "${script_dir}/../.." && pwd)"
  download_script="${skills_root}/jira-issues/scripts/download-attachment.sh"
fi

if [[ ! -f "$download_script" ]]; then
  echo "Error: Could not find download-attachment.sh script" >&2
  exit 2
fi

# Fetch issue metadata with attachments
jira_output=$(jira issue view "$issue_key" --raw 2>&1 || true)

if [[ ! "$jira_output" =~ "key" ]]; then
  echo "Error: Failed to fetch issue $issue_key" >&2
  exit 2
fi

# Parse attachments from JSON
attachments_json=$(echo "$jira_output" | python3 -c 'import json,sys
try:
  data = json.load(sys.stdin)
  attachments = data.get("fields", {}).get("attachment", [])
  json.dump(attachments, sys.stdout)
except Exception as e:
  print("[]", file=sys.stderr)
  sys.exit(1)
' 2>/dev/null || echo "[]")

# Convert to array in bash
mapfile -t attachment_ids < <(echo "$attachments_json" | python3 -c 'import json,sys
try:
  attachments = json.load(sys.stdin)
  for att in attachments:
    print(att.get("id", ""))
except:
  pass
' 2>/dev/null || true)

mapfile -t attachment_filenames < <(echo "$attachments_json" | python3 -c 'import json,sys
try:
  attachments = json.load(sys.stdin)
  for att in attachments:
    print(att.get("filename", ""))
except:
  pass
' 2>/dev/null || true)

total_attachments=${#attachment_ids[@]}

if [[ $total_attachments -eq 0 ]]; then
  echo "[]"
  exit 0
fi

echo "Found $total_attachments attachment(s) for $issue_key" >&2

downloaded_paths=()
failed_count=0

for i in "${!attachment_ids[@]}"; do
  current=$((i + 1))
  attachment_id="${attachment_ids[$i]}"
  filename="${attachment_filenames[$i]}"

  if [[ -z "$attachment_id" ]]; then
    continue
  fi

  echo "Downloading $current/$total_attachments: $filename..." >&2

  # Call the existing download-attachment.sh script
  if output_file=$("$download_script" \
    --id "$attachment_id" \
    --issue "$issue_key" \
    --out "$target_dir" 2>&1); then
    downloaded_paths+=("$output_file")
    echo "✓ Downloaded: $filename" >&2
  else
    ((failed_count++))
    echo "✗ Failed to download: $filename" >&2
  fi
done

# Output results as JSON array
printf '%s\n' "$(printf '%s\n' "${downloaded_paths[@]}" | python3 -c 'import json,sys; paths=[line.strip() for line in sys.stdin if line.strip()]; json.dump(paths, sys.stdout)')"

if [[ $failed_count -gt 0 ]]; then
  echo "$failed_count attachment(s) failed to download" >&2
  exit 3
fi

exit 0
