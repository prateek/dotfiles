---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-28
updated: 2026-09-28
related:
  - 0031-discovered-landing-workflows.md
current_guidance: ../../agent-marketplace/packages/review/skills/land-changes/references/preferences.md
---

# ADR 0037: Store landing preferences in the repository

## Decision

Saved land-changes choices live in the tracked file `.agents/land-changes.json`
at the destination checkout's top level, not under `$XDG_CONFIG_HOME`. One file
holds an entry per canonical destination identity and exact target. The helper
edits the working tree and takes its lock under the Git directory; committing
the edit is a separate, separately authorized step.

The committed file is the user's standing authorization for that destination. It
is the one repository file that can grant a bypass or follow-up. A choice that
only the candidate change adds or broadens stays unconfirmed until the user
approves it.

This supersedes the storage location and the v1 migration path in
[ADR 0031](0031-discovered-landing-workflows.md). Only the old XDG location held
v1 records, so the helper no longer reads or migrates them.

## Reasons and consequences

Preferences now follow the repository across machines and get reviewed like the
rest of the repository. The trade-off: anyone who can land to the target can
also change the preferences that govern landing, so edits to the file deserve
the same review as a policy change. Worktrees share a choice only after it is
committed. Forks carry the file, but its entries stay keyed to the original
destination.
