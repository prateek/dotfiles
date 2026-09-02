---
status: accepted
doc_type: adr
created: 2026-09-01
owner: Prateek
related:
  - 0017-agent-session-archive.md
  - ../plans/agent-session-wiki-plan.md
---

# ADR 0018: Work machines keep a sparse, blobless archive clone

## Context

ADR 0017 made every participating machine a full mirror of
`prateek/wiki-agent-sessions`. Two days in, the managed work laptop held
13 GB of personal-machine transcripts in its working tree plus a 2.2 GB pack,
next to 1.3 GB of its own sessions. Personal transcripts do not belong on an
employer-managed disk, and the full mirror was the only reason they were
there: the laptop writes only its own `sessions/<alias>/`, and its cross-host
reads went through agentsview, which had already copied them into its own
database.

ADR 0017 listed sparse checkout as a future lever. Sparse checkout alone
would have kept every host's blobs inside `.git`, so the lever is sparse
checkout plus a blobless partial clone.

## Decision

1. `agent_session_wiki_sparse` in `machines.toml` selects the clone shape;
   the `work` type sets it. A sparse host gets a blobless partial clone
   (`--filter=blob:none`) with a cone-mode sparse checkout of its own
   `sessions/<alias>/` plus `health/` and the agent config dirs. Nothing from
   other hosts reaches the disk: not their raw transcripts (not even as git
   objects) and not the distilled `wiki/`, which the ingest host derives from
   every host's sessions. Personal and homelab machines stay full.
2. `scripts/agent-sessions/reconcile-wiki-clone` owns the shape and is
   idempotent. A fresh clone gets the right flags, an existing full clone is
   narrowed in place (only when nothing outside the cone is dirty, with a
   warning that its old blobs stay until it is recreated), and a sparse
   clone widens back to full when the flag flips. It refuses remotes that do
   not advertise partial-clone support rather than leave a full clone
   behind, and takes the wiki repo's lock before mutating an existing clone.
   The chezmoi bootstrap calls it when that script refires (a change to
   `machines.toml`, the helper, the plist, or the agentsview template), and
   the verify step reports drift through its read-only `--check`; between
   refires, drift is repaired by running the helper by hand.
3. The ingest host must be a full clone. The bootstrap script refuses a host
   that resolves both `agent_session_wiki_sparse` and
   `agent_session_wiki_ingest`, and the wiki repo's `audit-heartbeats` fails
   when an expected host is not checked out. The ingest role moves from the
   work laptop to `m4mini`.
4. `sync-sessions` grows the cone to cover its own paths before mirroring,
   because git refuses to stage files outside the cone. The sync still pushes
   this host's sessions in full; only the local checkout is narrowed.

## Consequences

- A work machine sees only its own `sessions/`, and agentsview generates no
  cross-host `[[session_sources]]` there. Cross-host lookups happen on a
  full-clone host, not from a work machine. The obsidian-wiki vault config
  is not rendered on sparse hosts, since there is no `wiki/` to point it at.
- agentsview's local database keeps whatever it already indexed; narrowing
  the clone does not purge it, and `agentsview prune` has no per-machine
  filter. The work laptop's personal-mbp rows were removed with the daemon
  stopped by `DELETE FROM sessions WHERE machine = '<alias>'` (plus
  `project_identity_observations` and `worktree_project_mappings`) under
  `PRAGMA foreign_keys=ON`, so the cascades and FTS triggers clean the
  dependent tables, followed by `VACUUM`.
- Partial clones fetch lazily. A command that walks other hosts' blobs
  (`git grep`, `git log -p` across `sessions/`) pulls them on demand; the
  sync's own git calls were checked and stay tree-only.
- Narrowing in place stops the growth but not the history, so the work
  laptop's clone was recreated rather than converted.
