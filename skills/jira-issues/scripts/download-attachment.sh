#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  download-attachment.sh --id <attachment-id> --issue <issue-key> [--out <output-path-or-dir>] [--base-url <jira-base-url>] [--email <jira-email>]

Required:
  --id        Jira attachment ID (numeric)
  --issue     Jira issue key (e.g., PROJ-123)

Optional:
  --base-url  Jira base URL (default: read from jira CLI config)
  --email     Jira account email for basic auth (default: read from jira CLI config)

Env vars:
  JIRA_API_TOKEN must be set
  JIRA_CONFIG_FILE may point to a custom jira CLI config file
EOF
}

read_jira_config_value() {
  local key="$1"
  local config_file="${JIRA_CONFIG_FILE:-${HOME}/.config/.jira/.config.yml}"

  [[ -f "$config_file" ]] || return 1

  awk -F': *' -v key="$key" '
    $1 == key {
      value = $0
      sub("^[^:]+:[[:space:]]*", "", value)
      gsub(/^\"|\"$/, "", value)
      gsub(/^'"'"'|'"'"'$/, "", value)
      print value
      exit
    }
  ' "$config_file"
}

attachment_id=""
issue_key=""
output_target=""
base_url="${JIRA_BASE_URL:-}"
email="${JIRA_EMAIL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      attachment_id="$2"
      shift 2
      ;;
    --issue)
      issue_key="$2"
      shift 2
      ;;
    --out)
      output_target="$2"
      shift 2
      ;;
    --base-url)
      base_url="$2"
      shift 2
      ;;
    --email)
      email="$2"
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

if [[ -z "$attachment_id" || -z "$issue_key" ]]; then
  echo "Missing required arguments." >&2
  usage >&2
  exit 1
fi

if [[ -z "${JIRA_API_TOKEN:-}" ]]; then
  echo "Missing JIRA_API_TOKEN env var." >&2
  exit 1
fi

if [[ -z "$base_url" ]]; then
  base_url="$(read_jira_config_value server || true)"
fi

if [[ -z "$email" ]]; then
  email="$(read_jira_config_value login || true)"
fi

if [[ -z "$base_url" ]]; then
  echo "Missing Jira base URL. Run 'jira init' or pass --base-url." >&2
  exit 1
fi

if [[ -z "$email" ]]; then
  echo "Missing Jira email. Run 'jira init' or pass --email." >&2
  exit 1
fi

basic_token=$(printf '%s:%s' "$email" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
auth_header="Authorization: Basic ${basic_token}"

attachment_meta_url="${base_url%/}/rest/api/3/attachment/${attachment_id}"
attachment_url="${base_url%/}/rest/api/3/attachment/content/${attachment_id}"

attachment_filename=$(curl -sS --fail -H "$auth_header" "$attachment_meta_url" \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); filename=data.get("filename");
if not filename:
    raise SystemExit("Missing filename in attachment metadata")
print(filename)')

output_target="${output_target:-.}"
if [[ -d "$output_target" || "$output_target" == */ ]]; then
  output_dir="$output_target"
  output_file="$attachment_filename"
else
  output_dir="$(dirname "$output_target")"
  output_file="$(basename "$output_target")"
fi

if [[ "$output_file" != *"$issue_key"* ]]; then
  output_file="${issue_key}-${output_file}"
fi

mkdir -p "$output_dir"
output_path="${output_dir%/}/${output_file}"

curl -L --fail --show-error -H "$auth_header" -o "$output_path" "$attachment_url"
echo "$output_path"
