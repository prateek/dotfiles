# Linear Conventions (Skill-like)

## Purpose

Use this as the default playbook for Linear interactions on this machine.

## When to use

- Any Linear issue/project workflow.
- Any automation that reads/writes Linear data.

## Defaults

- Prefer `linear` CLI for Linear work.
- Pin workspace with `-w <workspace>` when ambiguous.
- Use `--no-interactive` and `--no-pager` for automation.
- Prefer read-first flow before writes.
- Prefer machine-readable output: `--json` for scripted/reviewable output.
- Prefer explicit IDs over names when available.

## Workflow

1. Verify context:
   - `linear --version`
2. Read path first:
   - `linear issue list --all-states --team <TEAM> --no-pager`
   - `linear issue view <ISSUE> --json`
   - `linear team list`
   - `linear project view <PROJECT_ID>`
3. Then write:
   - `linear issue create --team <TEAM> --title "<title>" --description "<markdown>" --no-interactive`
   - `linear issue update <ISSUE> --description "<markdown>"`
   - `linear issue comment add <ISSUE> --body "<markdown>"`
   - `linear issue attach <ISSUE> <filepath> -t "<title>" -c "<comment>"`

## Validation checklist

- Correct workspace selected.
- Read path completed before writes.
- Non-interactive flags used in automation.
- JSON output used for scripted/handoff flows.

## Capability snapshot

- Issues, teams, projects, milestones, initiatives, labels, documents.
- Issue comments and file attachments.

## Local evidence basis

Verified using:

- CLI help output (`linear 1.9.1`)
- `~/.codex/sessions` command patterns
- `~/.zhistory` command patterns
