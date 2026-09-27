# Edit durable docs

`AGENTS.md`, `CLAUDE.md`, `README`, `SKILL.md`, and long-lived guides describe the steady state. Treat the whole document as the editing boundary: compare it with the live tree or behavior, then reread it after the edit. Remove completed migration notes, collapse repeated lists, and keep each rule in one authoritative section.

Keep recurring conventions in agent guidance and one-off incident facts in the task report.

## Workspace provenance

Check `git rev-parse --is-inside-work-tree` when Git ownership is uncertain, especially under a docs root such as `~/Documents`.

- **Git-tracked:** Make small doc updates coupled to the requested change directly. Give the user a heads-up before a larger structural rewrite.
- **Outside Git:** Make a requested non-structural edit, such as a rename, directly. For structural edits, including requested cleanup, list the proposed changes and ask before applying them. Provenance and rollback are weaker here.

Finish when direct edits are complete, structural changes have been presented for a user decision, and the whole document has been checked against the live system within the agreed scope.
