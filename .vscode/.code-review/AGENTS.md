# Local Code Review — Comment Store

This directory is owned by the **Local Code Review** VS Code extension.

## Files

- `threads/*.json`: one file per thread.
- `index.json`: lightweight index for listing threads quickly.

## Thread schema (`threads/<threadId>.json`)

- `target.workspaceRelativePath`: workspace-folder-relative path
- `target.range`: VS Code 0-based `{ startLine, startCharacter, endLine, endCharacter }` or `null`
- `status`: `open` | `resolved`
- `comments[]`: append-only comment list

## How LLMs should interact

- To **reply**: append a new entry to `comments[]`, set `updatedAt` to now, and keep existing history intact.
- To **resolve**: set `status` to `resolved` and bump `updatedAt`.
- To **reopen**: set `status` to `open` and bump `updatedAt`.
- To **delete a thread**: delete the `threads/<threadId>.json` file and remove it from `index.json`.

## Guardrails

- Do not modify source code files unless explicitly requested by the user.
- Prefer small, local edits; avoid renaming thread IDs.
