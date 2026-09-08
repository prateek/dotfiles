---
status: archived
doc_type: plan
created: 2026-09-07
updated: 2026-09-07
closed: 2026-09-07
current_guidance:
  - ../../agent-marketplace/packages/review/skills/land-changes/SKILL.md
  - ../runbooks/dotfiles-landing.md
related:
  - ../references/agent-marketplace.md
status_detail: "Implemented and locally validated; publication and machine activation remain separate operations."
---

# Portable land-changes

Publish `land-changes` in the review plugin using the existing marketplace
architecture. Keep dotfiles checks and chezmoi deployment in the
[landing runbook](../runbooks/dotfiles-landing.md), reached from `AGENTS.md`.

## Contract

- Discover the destination repository and target branch. Inspect recent target
  history for human review, including review outside PRs. Complete solo history
  permits direct landing; review conventions or unavailable evidence require
  a decision after independent preparation. Server requirements remain binding.
- Prepare one tested commit covering the agreed change. Publish it with a normal
  fast-forward push, verify the remote, then synchronize a clean target checkout.
  Preserve work during conflicts, concurrent changes, and partial failures.
- Accept named review and deployment options in Claude Code and Codex. Save
  defaults only when requested, scoped to destination repository and target in
  XDG configuration. Deployment follows the repository's agreed procedure.
- Keep the workflow concise. Disclose host-specific evidence and preference
  details through focused references; use self-contained behavioral scenarios.

## Validation

Run the preference helper through its CLI in isolated configuration directories.
Run the rewritten scenarios through an agent with expected answers withheld, and
grade observable decisions separately from packaging and parser checks. Validate
native client loading and arguments, marketplace builds/export, and docs links.

Completion requires the portable payload, updated routing, passing checks, and
an export containing the checked source. Remote publication and machine
activation are separate operations.

## Validation receipt

The rewrite reduced the payload from 38 files to 8 and instruction prose from
485 lines to 322. All 35 marketplace tests and two repeat builds passed; the
helper's 12 CLI tests include a reproduced duplicate-control regression.
All 30 decision scenarios (78 expectations) passed with Claude Code Opus at xhigh
through acpx after targeted corrections and reruns. Expected answers were withheld.
These are simulations, separate from the real isolated Git and persistence checks.
Native Claude Code and Codex probes received the named flags and boolean false
correctly. The docs lifecycle suite passed 37 tests and validated 90 docs.
