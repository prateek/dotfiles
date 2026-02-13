---
name: conventions-maintainer
description: Maintain local convention docs in ~/.codex/docs as skill-like operational playbooks (for example Slack/Git/Linear/Google Workspace) and keep ~/.codex/AGENTS.md as a short pointer file to those docs.
---

# Conventions Maintainer

## When to use

Use this skill when asked to add, update, or clean up local convention guidance such as:

- Slack interaction conventions
- Git/GitHub/worktree conventions
- Linear conventions (`linear-conventions.md`)
- Google Workspace conventions (`google-workspace-conventions.md`)
- Browser/CDP conventions (`browser-cdp-conventions.md`)
- Other team workflow conventions stored under `~/.codex/docs`
- `~/.codex/AGENTS.md` cleanup so it points to docs instead of duplicating long instructions

## Design principle connection (required)

Apply the same principles used by `skill-creator`:

- Concise, high-signal wording.
- Workflow-first instructions.
- Progressive disclosure (quick defaults in main doc; detailed references only when needed).
- Operational checklists so users can execute and validate quickly.

Convention docs should read like lightweight skills/playbooks.

## Source of truth

- Conventions live in `~/.codex/docs/*.md`.
- `~/.codex/AGENTS.md` should stay brief and mostly point to those docs.
- Avoid duplicating full guidance in `AGENTS.md`.

## Workflow

### 1) Locate or create the target convention doc

- Prefer one focused file per topic (for example `slack-conventions.md`, `git-conventions.md`, `linear-conventions.md`, `google-workspace-conventions.md`, `browser-cdp-conventions.md`).
- Keep filenames stable and obvious.
- If a topic already has a convention file, update in place instead of creating duplicates.

### 2) Use the skill-like convention structure (required)

Every convention doc should use this core shape:

1. `Purpose`
2. `When to use`
3. `Defaults`
4. `Workflow` (step-based, operational)
5. `Validation checklist`

Optional sections when useful:

- `Security and safety`
- `Channel/command snapshot`
- `Capability snapshot`
- `Evidence basis`

### 3) Write concise, operational guidance

- Optimize for quick scanning and direct execution.
- Include exact text formats when required (for example review request message format).
- Keep language concrete and actionable.
- Prefer copy-pastable command examples.

### 4) Topic-specific rules (Slack)

- Prefer the OpenAI Slack connector for channel discovery and message operations.
- Do not guess channel IDs. Resolve IDs from Slack tools.
- If an ID cannot be resolved, mark it as `UNKNOWN` and add a short verification note.
- Include channel usage guidance ("what it is for" and "when to use it").

### 5) Keep AGENTS pointers aligned

When you add or rename a convention doc, update `~/.codex/AGENTS.md` to reference it.

Expected AGENTS style:

- short
- pointer-oriented
- minimal hardcoded workflow detail

### 6) Validate before finishing

- Confirm all referenced paths exist.
- Check for stale or duplicated guidance between docs and `AGENTS.md`.
- Ensure wording is consistent across related docs.
- Ensure required sections (`Purpose`, `When to use`, `Defaults`, `Workflow`, `Validation checklist`) are present.

## Output expectations

When reporting completion, include:

- files created/updated
- any unresolved items (for example channel IDs still `UNKNOWN`)
- whether `AGENTS.md` pointer updates were applied
