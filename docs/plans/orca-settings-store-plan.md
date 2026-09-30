---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-30
updated: 2026-09-30
related:
  - ../adr/0042-orca-profile-state-reconcile.md
  - agent-clis-consolidation-plan.md
  - ../adr/0012-config-gating-convention.md
status_detail: "Desired template, writer, apply hook, guard integration, audit re-point, and tests implemented in source 2026-09-30; the live write on work-mbp (quit Orca, apply, relaunch) is pending."
---

# Orca settings through the profile-state store

Push the tracked Orca settings into the store Orca actually reads, derive the
agent and editor entries from the machine's `agent_clis` and casks, and retire
the `orca-data.json` modify that has been writing a dead file since July.

## Findings (2026-09-30, Orca 1.4.217)

- Orca persists settings in
  `~/Library/Application Support/orca/profiles/<profile>/profile-state.db`
  (SQLite, `node:sqlite`, WAL): table `profile_state_documents` keyed by
  `domain`, with the `settings` row holding the settings JSON;
  `profile_state_meta` holds `profile_id`, a global `revision`, and a
  `legacy_json_acceptance` marker. `content_hash` is the lowercase sha256 of the
  exact payload bytes; `updated_at` is epoch milliseconds.
- The chezmoi-managed `userData/orca-data.json` is inert: Orca only imports a
  legacy JSON when no database exists, and the profile-local
  `profiles/<id>/orca-data.json` it would compare against does not exist here.
  Chezmoi reported the file in sync while the live `settings` row differed on
  `terminalShortcutPolicy`, `terminalDividerColorDark`, `terminalQuickCommands`,
  and `disabledTuiAgents`.
- Writing the store while an Orca participant lease is alive is unsafe: every
  app write is fenced on `revision`; an external bump makes the next app write
  fail and the app silently stops persisting until restart. There is no watcher.
- Upstream's own offline writer (`orca agent hooks on|off`) is the reference:
  exclusive maintenance lease, assert app stopped, one snapshot read of
  revision and payload, merge, revision-fenced write of the `settings` row.
- `terminalScrollbackBytes` is a retired key Orca strips on load.
- Orca's picker shows detected agents (`which claude|codex|cursor-agent|omp|pi|gemini`)
  minus `disabledTuiAgents`; `defaultTuiAgent` must be in that set or Orca picks
  down its own order. `agentDefaultArgs` on work is Orca's YOLO preset applied
  by its migration, not a user choice; Vertex reaches Claude in panes through
  `~/.zprofile.local`.
- `just audit-orca-settings` fails: the asar extractor looks for helper names
  that no longer exist, and the committed snapshot is from 1.4.104.
- Retargeting the modify to `profiles/<id>/orca-data.json` would create a
  JSON/DB pair whose hash does not match the acceptance marker; Orca then blocks
  startup with a recovery dialog whose JSON branch quarantines the database.

## Decisions (agreed 2026-09-30)

- Write path: a reconcile script copying upstream's offline writer; Orca must
  be stopped. Apply integrates with the plist guard: at a terminal it offers to
  quit Orca before the write and relaunches it afterwards; non-interactive
  applies refuse, as they do for other running apps.
- Derivation from the [agent_clis catalogue](agent-clis-consolidation-plan.md):
  `disabledTuiAgents` = catalogue Orca ids minus the machine's `agent_clis`
  (plus a per-type `disabled_extra`, today homelab's `claude-agent-teams`);
  `defaultTuiAgent` = first selected agent in `codex, claude, cursor, omp`;
  `openInApplications` and the Cursor/VS Code quick commands follow
  `package-cask-enabled` for `cursor` and `visual-studio-code`.
- Cursor is shown on work (it follows the derivation; the live hide is dropped).
- Values adopted from live use: the Cursor quick command is
  `cursor --classic . && exit`; `terminalDividerColorDark` is `#c20000`.
- `terminalScrollbackBytes` is dropped, not replaced.

Resulting per-type agent entries:

| | personal | homelab | work |
| --- | --- | --- | --- |
| `defaultTuiAgent` | codex | codex | claude |
| `disabledTuiAgents` | cursor | cursor, claude-agent-teams | codex, omp, gemini |
| open-in / quick commands | Finder, Cursor, VS Code | Finder | Finder, Cursor, VS Code |

## Design

**Desired state.** `home/.chezmoitemplates/orca-settings.desired.json.tmpl`
replaces the base template: flat preferences stay literal; the agent and
editor keys are computed from the catalogue selection, `package-cask-enabled`,
and `home/.chezmoidata/orca.toml` (`default_agent_order`, per-type
`disabled_extra`, the open-in rows with their cask, label, command, and quick
command). One template is the single source of desired state for the hook,
the audit, and the tests.

**Writer.** `scripts/orca/settings-reconcile`, a PEP 723 script on the
standard library (`sqlite3`, `json`, `hashlib`), sibling of
`scripts/macos/plist-merge`, with `check` (drift report, exit 1 on drift) and
`apply`. Contract:

1. Resolve `$ORCA_USER_DATA_PATH` or `~/Library/Application Support/orca`,
   then the active profile from `orca-profile-index.json` (`.bak` fallback,
   `profiles[0]` when `activeProfileId` is missing, `local-default` last).
2. Skip with a log line when the profile has no database (fresh profile or
   JSON-only state); never create one.
3. Refuse unless `PRAGMA user_version` is 3, `journal_mode` is `wal`, and
   `quick_check` returns `ok`.
4. Refuse while any `.profile-state-access/participants/*` owner names a live
   pid or a `maintenance/` lease exists. Take the maintenance lease with a
   well-formed owner file (`candidates/<uuid>` renamed to `maintenance`),
   released on every exit path.
5. In one `BEGIN IMMEDIATE` transaction: read `revision` N and the `settings`
   payload, merge only the desired keys, stop without writing when nothing
   changes, otherwise update the row (`payload`, `domain_version = 1`,
   `revision = N+1`, `updated_at = now_ms`, `content_hash = sha256(payload)`)
   and set `profile_state_meta.revision = N+1`, then commit.
6. Never touch `orca-data.json` or `legacy_json_acceptance`.

**Hook and guard.** `run_after_47-orca-settings.sh.tmpl`, gated on
`run_install_scripts` and the Orca cask like the other app hooks, passes the
rendered desired JSON to the writer in the `plist-merge` shape (base64
argument) and runs `check` first so it is silent when in sync.
`scripts/chezmoi-hooks/plist-hooks.sh pre` adds Orca to its quit list when the
writer reports drift and Orca is running, using the same prompt, Apple Event
quit, and `post` relaunch it uses for plist apps. A `just orca-settings
<check|apply>` recipe covers the manual path.

**Retire the JSON modify.** Delete
`home/Library/Application Support/private_orca/modify_orca-data.json.tmpl` and
its `.chezmoiignore` line; leave the root `orca-data.json` alone (Orca's file,
no `remove_`). `~/.orca/keybindings.json` stays managed as it is.

**Audit.** `just audit-orca-settings` becomes `settings-reconcile check`. The
asar extractor and the 1.4.104 snapshot are deleted. Comparing tracked values
against Orca's defaults is a follow-up: fetch
`src/shared/default-global-settings.ts` at the installed tag through `gh api`
rather than the minified bundle.

## Tests

Rewrite `tests/python/config/test_orca.py`:

- Render the desired template for personal, homelab, and work and assert the
  table above plus the absence of retired keys.
- Drive `settings-reconcile` against a fixture database the test builds from
  the upstream schema (`user_version 3`, WAL, meta rows, a `settings` row and
  an unrelated sibling row): revision, hash, and `updated_at` after `apply`;
  the sibling row untouched; a no-op leaves the revision alone; refusal on a
  participant owner file carrying the test's own pid, on a `maintenance/`
  lease, and on a foreign `user_version`; index `.bak` fallback; the missing
  database case logs and exits 0.
- `tests/bats/hooks/plist-hooks.bats` gains the Orca quit/relaunch case with
  the app commands substituted, as the plist cases do.

`just test-chezmoi-apply` covers the hook rendering on every machine type;
`gate_examples.py` loses the `orca-data.json` rows.

## Increments

1. Data and desired template with render tests (needs the catalogue from
   increment 1 of the agent_clis plan).
2. Writer with database tests.
3. Hook, guard integration, JSON modify retirement, audit re-point, docs, ADR
   0042 to accepted.
4. Live acceptance on work-mbp: quit Orca, `chezmoi apply`, relaunch, confirm
   the four keys in the UI, then confirm Orca still saves a settings change
   afterwards. Run the first pass from Terminal.app rather than an Orca pane.
   personal and homelab pick it up on their next apply.

## Risks and open items

- Orca schema changes: the writer fails closed on an unknown `user_version`
  and on `quick_check` failures; an Orca upgrade that changes the store shape
  turns into a loud skip, not a corrupt profile.
- A leftover maintenance lease from an interrupted run is reclaimed by Orca
  when its pid is dead; a malformed owner file is not, so the lease file is
  written whole and removed on every exit path.
- The `orcad` headless runtime uses a different userData root (`~/.orca` or
  XDG) and is not covered; devbox's Orca is out of scope.
- Quitting Orca from an apply that runs inside an Orca pane relies on the PTY
  daemon keeping the pane's process alive; the first live run happens from a
  non-Orca terminal.
- The runtime `settings.update` RPC could later push `defaultTuiAgent` and
  `disabledTuiAgents` without a quit; the terminal keys are outside its
  allowlist, so it cannot replace the store write.
