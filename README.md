# Jira Skills

Agent skills for working with Jira issues, epics, sprints, implementation tasks, and RCA workflows.

## Install

macOS/Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/p8n-ai/jira-skills/main/install.sh | bash
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/p8n-ai/jira-skills/main/install.ps1 | iex"
```

The installer will:

- Install the Jira skills.
- Help install the `jira` CLI if needed.
- Offer to run `jira init`.
- Ask for an optional Jira API token for attachment downloads.

After installation, open a new terminal before using the skills.

## Requirements

- Node.js/npm with `npx` available.
- A Jira account.
- A Jira API token if you want attachment downloads.

The installer can help with the `jira` CLI setup.

## Jira API token

For attachment downloads, the installer may ask for an optional Jira API token:

```bash
JIRA_API_TOKEN="your-api-token"
```

## Included skills

- `jira-issues` — create, view, edit, assign, comment on, link, and search Jira issues.
- `jira-epics` — create epics and manage epic membership.
- `jira-sprints` — list sprint issues and add issues to sprints.
- `jira-workflow` — common Jira workflows such as standups, triage, and bulk operations.
- `jira-implement` — implementation workflow for Jira stories and tasks.
- `jira-rca` — root cause analysis workflow for bugs and incidents.
- `jira-common` — shared helpers used by the Jira skills.

## Example prompts

```text
Use Jira issues to show PROJ-123 and summarize the ticket.
```

```text
Use jira-rca to investigate BUG-456 and create a supervised RCA plan.
```

```text
Use jira-implement to plan implementation for STORY-789.
```
