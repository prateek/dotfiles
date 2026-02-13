# Codex agent notes (local)

This file is intentionally short. Use the docs below as the source of truth.

## Git and repo conventions

For Git/GitHub/worktree/openai-monorepo conventions, follow:

- `~/.codex/docs/git-conventions.md`

## Slack conventions

For any Slack task (read/search/send), follow:

- `~/.codex/docs/slack-conventions.md`

Requirements:

- Prefer the OpenAI Slack connector for Slack interactions.
- Use documented channel IDs + channel-purpose guidance.
- Use the exact review-request format: `r? <link> - <desc>` then `cc ...`.

## Linear conventions

For Linear tasks, follow:

- `~/.codex/docs/linear-conventions.md`

Requirements:

- Prefer `linear` CLI for Linear interactions.

## Google Workspace conventions

For Google Workspace tasks, follow:

- `~/.codex/docs/google-workspace-conventions.md`

Scope includes:

- Google Drive, Docs, Sheets, Slides, Calendar
- Gmail, Chat, Contacts, Tasks, People
- Groups, Classroom, Keep

Requirements:

- Prefer `gog` CLI for Google Workspace interactions.

## Browser CDP conventions

For browser-control/CDP tasks, follow:

- `~/.codex/docs/browser-cdp-conventions.md`

Requirements:

- Prefer credentials/profile specified by `CDP_PROFILE_PATH`.
- If `CDP_PROFILE_PATH` is unavailable or invalid, prompt the user for which profile path to use.

## Observability provider environment

For Chronosphere, Datadog, and Grafana tasks, use pre-exposed environment variables instead of hardcoding credentials.

Available variable names (no values):

- `CHRONOSPHERE_ORG_NAME`
- `CHRONOSPHERE_API_TOKEN`
- `DATADOG_API_KEY`
- `DATADOG_APP_KEY`
- `GRAFANA_TOKEN`
- `API_REPO_PATH`

Requirements:

- Never print or log secret values.
- Use these environment variables as the default auth/config path.
- If a required variable is missing, prompt the user before proceeding.
