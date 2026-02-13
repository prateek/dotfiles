# Google Workspace Conventions (Skill-like)

## Purpose

Use this as the default playbook for Google Workspace interactions on this machine.

## When to use

- Any Google Workspace workflow across:
  - Google Drive, Docs, Sheets, Slides, Calendar
  - Gmail, Chat, Contacts, Tasks, People
  - Groups, Classroom, Keep
- Any automation that reads/writes Google Workspace data.

## Defaults

- Prefer `gog` CLI for Google Workspace work.
- Pin account with `--account <email>` when ambiguous.
- Use `--no-input` for automation.
- Prefer read-first flow before writes.
- Prefer machine-readable output: `--json` for scripted/reviewable output.
- Prefer explicit IDs over names when available.

## Workflow

1. Verify context:
   - `gog --version`
   - `gog auth status`
2. Pick the product surface:
   - `gog drive --help`
   - `gog docs --help`
   - `gog sheets --help`
   - `gog calendar --help`
   - `gog gmail --help`
   - `gog chat --help`
3. Run read path first:
   - `gog drive search "<query>" --max <N> --json`
   - `gog drive get <FILE_ID> --json`
   - `gog docs info <DOC_ID>`
   - `gog docs cat <DOC_ID>`
   - `gog docs export <DOC_ID> --format=txt --out <file>`
   - `gog sheets metadata <SHEET_ID>`
   - `gog sheets get <SHEET_ID> "<TAB!A1:Z100>" --json`
   - `gog calendar events --today --json`
4. Then write:
   - `gog sheets update <SHEET_ID> "<RANGE>" --values-json '<2d-array-json>'`
   - `gog sheets append <SHEET_ID> "<RANGE>" --values-json '<2d-array-json>'`
   - `gog sheets clear <SHEET_ID> "<RANGE>"`
   - `gog sheets copy <SHEET_ID> "<NEW_TITLE>"`
   - `gog drive move <FILE_ID> --parent <FOLDER_ID>`

## Security and safety

- Avoid token export unless required for debugging.
- If tokens are exported, write to temp files and delete immediately.

## Validation checklist

- Correct Google account selected.
- Correct product surface selected before running commands.
- Read path completed before writes.
- Non-interactive flags used in automation.
- JSON output used for scripted/handoff flows.

## Capability snapshot

- `gog` top-level supports Google Workspace surfaces including:
  - Drive, Docs, Slides, Sheets, Calendar, Gmail, Chat, Contacts, Tasks, People
  - Groups, Classroom, Keep

## Local evidence basis

Verified using:

- CLI help output (`gog v0.9.0`)
- `~/.codex/sessions` command patterns
- `~/.zhistory` command patterns
