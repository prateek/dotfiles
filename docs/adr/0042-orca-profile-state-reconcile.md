---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-30
updated: 2026-09-30
related:
  - ../plans/orca-settings-store-plan.md
  - ../plans/agent-clis-consolidation-plan.md
  - 0041-agent-clis-single-declaration.md
---

# ADR 0042 — Reconcile Orca settings through its profile-state store

## Decision

Tracked Orca settings are written into the `settings` row of Orca's
profile-state SQLite database by an apply hook, using the same contract as
Orca's own offline settings writer: exclusive maintenance lease, application
stopped, one snapshot read, merge of only the tracked keys, revision-fenced
write with a sha256 content hash. The hook joins the plist guard, which offers
to quit Orca before the write and relaunches it after apply, and refuses in
non-interactive applies.

The agent entries (`defaultTuiAgent`, `disabledTuiAgents`) and the editor
entries (`openInApplications`, quick commands) are derived from the machine's
`agent_clis` selection and cask gates ([ADR 0041](0041-agent-clis-single-declaration.md)),
not hand-written per machine type. The `orca-data.json` modify is retired.

## Rationale

Orca moved user settings from `orca-data.json` into a per-profile SQLite store.
The modify kept the JSON matching the desired fragment, so chezmoi reported
Orca in sync while the live store disagreed on every key that had ever been
changed in the app. The store is the only place Orca reads settings from.

The write has to happen with Orca stopped. Orca fences every write on a
profile revision it only advances itself; an outside write while a process
holds a participant lease makes the app's next save fail and stops persistence
until restart, without any error the user would see. The plist guard already
solves "a running app will overwrite or defeat our write" with an interactive
quit and relaunch, so Orca joins that path rather than growing a second one.

## Alternatives rejected

- Keep or retarget the JSON modify. The root file is dead. A profile-local
  JSON next to the database must hash-match Orca's acceptance marker, or
  startup blocks with a recovery dialog whose JSON branch replaces the whole
  database and quarantines the old one.
- `orca profile state rollback --current-json`. It imports a JSON, but by
  quarantining the database, its backups, and its exports; it is a divergence
  recovery tool, not configuration management.
- The runtime `settings.update` RPC. Its parameter schema is a strict allowlist
  that includes the agent keys but none of the terminal keys, and it needs the
  app running.
- Writing while Orca runs. See the rationale; the failure is silent and
  persists until the app restarts.

## Consequences

- Settings drift is reconciled on apply only when Orca is closed or the user
  accepts the quit; otherwise the hook reports the drifted keys and the
  `just orca-settings apply` path.
- The writer fails closed on an unknown store version or a failed integrity
  check; an Orca upgrade that changes the store becomes a loud skip.
- The defaults-comparison half of the old audit is gone until it is rebuilt
  from upstream source at the installed tag.
