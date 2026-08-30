---
status: active
doc_type: plan
owner: Prateek
created: 2026-08-30
updated: 2026-08-30
status_detail: "Accepted; implementation landing on the av-history branch. See ADR 0017."
related:
  - ../adr/0017-agent-session-archive.md
---

# Agent session wiki: Obsidian vault, raw archive, and cross-machine sync

## Goal

The private `prateek/wiki-agent-sessions` repository will hold a searchable history of coding-agent sessions from every configured personal, homelab, and work machine, including the work laptop. The repository already exists, is cloned locally, and is registered with Orca on the current machine.

The repository combines three services:

- [obsidian-wiki](https://github.com/ar9av/obsidian-wiki), a Python package whose CLI and agent skills ingest session histories into an Obsidian Markdown vault, query sessions, lint pages, and maintain the wiki.
- [agentsview](https://github.com/kenn-io/agentsview), a local daemon and interface that indexes supported agents' native session directories. Its `[[session_sources]]` configuration exposes archived sessions from other hosts with machine labels.
- A raw, per-host Git archive containing Claude Code, pi, Codex, and cursor-agent session files.

Orca automations are scheduled agent prompts with prechecks, run history, and configurable workspaces. Orca will run raw synchronization hourly on every participating machine and wiki ingestion daily on one designated host.

The dotfiles repository will install the required CLIs, bootstrap the clone, configure agentsview, and reconcile the Orca automations. Chezmoi maps source files under `home/` to paths in `$HOME`; numbered templates under `home/.chezmoiscripts/` run idempotently during `chezmoi apply`. Machine-specific settings come from `home/.chezmoidata/machines.toml`.

The ownership boundaries are:

- Repository scripts move native session files, commit them, and push them.
- agentsview parses supported native layouts and provides cross-host browsing.
- obsidian-wiki builds and maintains the Markdown vault.
- Git provides transport and history integrity.
- Orca schedules work and records runs.
- Chezmoi installs and reconciles the local configuration.

One synchronization script and two small helpers form the data path. Configuration, automation registration, documentation, and focused tests complete the implementation.

## Target architecture

Every participating host owns a unique directory under `sessions/` and runs `wiki-sessions-sync` hourly. The precheck avoids starting an agent when local files, Git refs, and the remote are already converged.

```text
Host A native sessions ─┐
Host B native sessions ─┼─ hourly sync ─> sessions/<host>/ ─> Git remote
Host C native sessions ─┘                          │
                                                  ├─> agentsview on every host
                                                  │   via [[session_sources]]
                                                  │
                                                  └─> daily wiki ingestion
                                                      on one designated host
                                                               │
                                                               v
                                                             wiki/
```

A single ingest host writes generated pages under `wiki/`. This avoids concurrent edits to obsidian-wiki output. Moving the ingest role requires one `machines.toml` change.

The system will:

- Backfill all existing session history.
- Preserve raw sessions in Git.
- Synchronize every participating host hourly.
- Expose other hosts' supported archives through agentsview.
- Ingest Claude archives into the wiki daily on the designated host.
- Keep obsidian-wiki's built-in cron synchronization disabled. Repository scripts and Orca own commits and pushes.
- Keep global obsidian-wiki setup disabled.

## Verified constraints

### obsidian-wiki

- obsidian-wiki is distributed as a pip package.
- Its configuration path is `~/.config/obsidian-wiki/config`.
- Its ingest manifest lives inside the vault.
- `CLAUDE_HISTORY_PATH` redirects Claude history ingestion to any directory shaped like `~/.claude`.
- `PI_HISTORY_PATH` selects the corresponding pi history source.
- `obsidian-wiki setup` installs all 39 upstream skills globally in locations such as `~/.claude/skills` and `~/.agents/skills`.
- The dotfiles plugin architecture requires `~/.agents/skills` to remain an empty compatibility stub, so global setup must never run.
- The CLI provides `sessions-build`, `sessions-query`, `lint`, and `sync`. This design uses neither global setup nor built-in cron synchronization.

### agentsview

Install agentsview v0.41.1 or later. The following facts were verified against v0.41.1; installation tracks the latest release.

`[[session_sources]]` tables, added in 0.40.0, describe the required topology. `docs/filesystem-sync.md` documents native agent layouts transported through Git, rsync, file-copy jobs, or shared filesystems and scanned as labeled roots. Each entry has `agent`, `dir`, and `machine` fields. Entries extend agentsview's local defaults, and `machine` becomes a session-filter label.

Per-agent directory settings replace their defaults. Repository roots therefore belong in additive `[[session_sources]]` entries. The existing dotfiles-managed `codex_sessions_dirs` setting remains responsible for local Orca `CODEX_HOME` directories.

Duplicate roots cannot create duplicate session rows. A Claude session ID is the filename UUID (`internal/parser/claude.go:87`), and `sessions.id` is the TEXT PRIMARY KEY written through `UpsertSession` (`internal/db/sessions.go:1475`). Generated repository sources will still exclude the current host to avoid parsing each local session twice.

Configuration changes require a daemon restart:

```sh
agentsview serve --background --replace
```

The restarted daemon performs an initial sync. An explicit `agentsview sync` immediately afterward would traverse every root a second time and must be omitted.

Freshness is agentsview's job, not the sync script's: a filesystem watcher picks up transported files, and a full periodic sync runs every 15 minutes as the backstop (`docs/filesystem-sync.md`). Steady-state operation therefore issues no manual `agentsview sync` at all; the daemon restart exists solely for configuration changes (a new host's `[[session_sources]]` entry).

Two more documented behaviors shape the design:

- A session keeps the `machine` label it received at first ingestion; relabeling existing sessions is not supported. Host aliases must be correct before a root is ever wired in.
- Deleting a transported source file never erases the archived session — each machine's SQLite archive is itself persistent. Future repository pruning cannot lose sessions that machines have already ingested.

### Current session inventory

The current machine has:

- 951 MB of Claude session data.
- 127 Claude project directories.
- 235 top-level `<uuid>.jsonl` files.
- 1,513 `<uuid>/subagents/agent-*.jsonl` files.
- 1.9 GB of cursor-agent transcripts: 1,403 JSONL files under `~/.cursor/projects/<flattened-cwd>/agent-transcripts/<uuid>/<uuid>.jsonl`, spread across 367 project directories. This is the layout read by agentsview's cursor parser.
- One 48 KB cursor-agent SQLite store at `~/.cursor/chats/<hash>/<uuid>/store.db`.
- No session file larger than 45 MB in any store.

The Cursor IDE state under `~/Library/Application Support/Cursor` is 11 GB. It contains IDE workspace storage rather than CLI session transcripts and remains out of scope.

Archive filters must recurse into subdirectories to retain subagent logs.

### Platform and repository

- macOS provides the `flock(2)` syscall but omits the util-linux `flock(1)` command. `command -v flock` returns nothing, so repository locking must use portable atomic `mkdir`.
- The new chezmoi script is number 38, after agent-related scripts 35 through 37.
- The agentsview source directory is `home/private_dot_agentsview/`, renamed in commit `e7dc3d5`.
- `tests/agentsview-config-modify.zsh:16` still uses the previous path and must be corrected.
- CI discovers shellcheck targets from their shebangs.

## Archive contents

`sync-sessions` will define its sources as a table of `<harness> -> <source directory> -> <archive subdirectory>`. Supporting another harness should require one source-map entry.

| Harness | Source | Handling |
|---|---|---|
| Claude Code | `~/.claude/projects/` and `~/.claude/history.jsonl` | Mirror JSONL recursively, including memories |
| pi | `~/.pi/agent/sessions/` | Mirror recursively |
| Codex | `~/.codex/sessions/`, `~/.codex/archived_sessions/`, and Orca's private `CODEX_HOME` sessions directory | Auto-detect when present; none exist on the current machine |
| cursor-agent | `~/.cursor/projects/*/agent-transcripts/` and `~/.cursor/chats/<hash>/<uuid>/store.db` | Mirror only `agent-transcripts/**` (`.jsonl` and `.txt` — the parser accepts both layouts); snapshot SQLite stores with `sqlite3`. **Never mirror the wider `projects/` tree**: it holds `mcp-auth.json` MCP OAuth files (177 here), `worker.log`, and `canvases/`. `agent-tools/` and `terminals/` output logs stay out until a consumer reads them |
| Gemini CLI | `~/.gemini/` | Deferred; no transcripts exist here, and the directory contains `oauth_creds.json`. Never mirror it wholesale |
| Copilot CLI | `~/.copilot/session-state/` | Deferred; the current machine contains 28 KB. Add it when needed |

The wiki repository's `AGENTS.md` will record deferred harnesses and this consumer matrix:

| Harness | Raw archive | agentsview across hosts | Wiki |
|---|---|---|---|
| Claude Code | Yes | Yes, through `[[session_sources]]` | Yes |
| pi | Yes | No pi parser in v0.41.1 | Yes, through `PI_HISTORY_PATH` |
| Codex | When present | Yes, through `[[session_sources]]`; `codex_sessions_dirs` covers local Orca `CODEX_HOME` directories | Yes |
| cursor-agent `chats/store.db` | Yes, as a consistent snapshot | No; v0.41.1 reads only `<project>/agent-transcripts/*.{txt,jsonl}` (`internal/parser/cursor_provider.go:166`) | No |
| cursor-agent `projects/` | Yes | Yes, through `[[session_sources]]` | No |

Cursor chat databases remain in the archive even though agentsview and obsidian-wiki do not read them.

## Wiki repository

Build the following layout in `prateek/wiki-agent-sessions`:

```text
├── README.md
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── .gitignore
├── wiki/
├── sessions/<host>/
│   ├── claude/
│   │   ├── projects/...
│   │   └── history.jsonl
│   ├── pi/
│   │   └── sessions/...
│   ├── codex/...
│   ├── cursor/
│   │   ├── chats/...
│   │   └── projects/...
│   └── SKIPPED.md
├── health/<host>.json
├── .agents/
│   └── skills/
│       └── session-sync/
│           ├── SKILL.md
│           └── scripts/
│               ├── sync-sessions
│               ├── sync-precheck
│               └── with-repo-lock
├── .codex/
│   └── config.toml
└── .claude/
    ├── settings.json
    └── skills -> ../.agents/skills
```

`CLAUDE.md` links to `AGENTS.md`, and `.claude/skills` links to `.agents/skills`. This follows the dotfiles convention that `.agents/` is the repository-local agent configuration surface and Claude-specific paths link into it.

The synchronization executables live inside the `session-sync` skill. Every caller, including Orca prechecks, automation prompts, and manual invocations, uses:

```text
.agents/skills/session-sync/scripts/<name>
```

`README.md` and `AGENTS.md` will define archive scope, directory ownership, synchronization rules, consumer support, and automation definitions. `.gitignore` will exclude `.DS_Store` and Obsidian workspace and cache files.

Each `sessions/<host>/` directory contains:

- `claude/projects/...`, mirroring `~/.claude/projects`, including `<uuid>/subagents/` and per-project `memory/*.md`. obsidian-wiki mines memories alongside conversations.
- `claude/history.jsonl`, which lets obsidian-wiki recover prompt history from pruned sessions.
- `pi/sessions/...`, mirroring `~/.pi/agent/sessions`.
- Codex session directories when present.
- `cursor/projects/<project>/agent-transcripts/...` transcripts and consistent `cursor/chats/...` database snapshots.
- `SKIPPED.md`, a committed ledger of oversized or quarantined files.

The directory name comes from `wiki_host_alias` in `machines.toml`, rendered into machine configuration by chezmoi. Every participating host requires an alias. `sync-sessions` must fail closed with a clear message and named exit code when the alias is absent.

The script must not fall back to `hostname -s`; two machines named `macbook-pro` could write to the same archive directory. `tests/machines-features.zsh` will enforce alias uniqueness. `$WIKI_SESSIONS_HOST` remains an undocumented test seam.

## Vault and plugin integration

### Vault creation

Inspect obsidian-wiki's source for project-scoped setup. If it exists, use it only to create the vault. Otherwise create this structure directly:

```text
wiki/
├── <category directories>
├── index.md
├── log.md
├── _raw/
└── .obsidian/
```

Never run global `obsidian-wiki setup`.

### Dotfiles plugin package

Package the upstream skills as a dotfiles plugin installed on every machine and disabled by default. Repositories opt in through the per-project override mechanism from ADR 0007.

Create:

```text
home/dot_agents/packages/obsidian-wiki/
├── package.toml
├── apm.yml
├── apm.lock.yaml
└── skills/
    └── vendor/
        └── <skill>/
            └── SOURCE.md
```

`package.toml` must have a display name, `default_loaded = false`, and `[render]` entries for Claude and Codex plugins.

Vendor the complete skill sets from:

- `ar9av/obsidian-wiki`: all skills, about 39 in total. These include `wiki-history-ingest`, the per-harness history ingesters, `wiki-query`, `wiki-capture`, `session-brain`, `session-search`, `wiki-lint`, `wiki-status`, and the maintenance skills.
- `kepano/obsidian-skills`: `obsidian-markdown`, `obsidian-bases`, `json-canvas`, `obsidian-cli`, and `defuddle`.

Keep `apm.yml` unpinned. `apm.lock.yaml` records the reviewed commits.

The renderer installs `obsidian-wiki@prateek-local` on every machine with the plugin disabled:

```json
"enabledPlugins": {
  "obsidian-wiki@prateek-local": false
}
```

The wiki repository enables it for each supported agent. `.claude/settings.json` contains:

```json
"enabledPlugins": {
  "obsidian-wiki@prateek-local": true
}
```

`.codex/config.toml` contains:

```toml
[plugins."obsidian-wiki@prateek-local"]
enabled = true
```

Codex deep-merges project-root configuration. The user must trust the project on first use. Other repositories may opt in through the same files.

The repository-local skill lives at:

```text
.agents/skills/session-sync/SKILL.md
```

It invokes its bundled `scripts/sync-sessions` and contains the automation agent's failure playbook.

Cross-host query and ingest recipes belong in one machine-wide operator skill in dotfiles. Those recipes cover agentsview configuration, `CLAUDE_HISTORY_PATH`, `PI_HISTORY_PATH`, and `session-brain --claude-dir`. `AGENTS.md` will contain repository invariants rather than duplicate operating procedures.

### CLI installation

Install obsidian-wiki through mise:

```toml
"pipx:obsidian-wiki" = "latest"
```

Install the Obsidian CLI required by kepano's `obsidian-cli` skill. During implementation, read that skill to confirm the binary name and installation source. Use mise when an `npm:`, `go:`, or `pipx:` target exists; otherwise add the CLI to the Brewfile.

## Repository locking

`.agents/skills/session-sync/scripts/with-repo-lock` will implement a shared atomic-`mkdir` lock with stale-PID cleanup.

Both raw synchronization and wiki ingestion must run through this wrapper. It serializes operations within a clone without depending on the unavailable `flock(1)` command.

## Raw-session synchronization

The sync layer copies files without parsing session content. agentsview and obsidian-wiki remain the only parsers.

`sync-sessions` will be a Python script with this shebang:

```python
#!/usr/bin/env -S uv run --script
```

Its PEP 723 metadata will declare `tomlkit`. The dotfiles already install uv, so the script can run without a separate environment.

`sync-precheck` and `with-repo-lock` remain small, shellcheck-clean Bash scripts. They perform stat-level checks on the hot path. All repository operations run under `with-repo-lock`.

### Preflight and recovery

Before mirroring, `sync-sessions` must:

- Fail closed with a named exit code and instructions when the host alias is absent.
- Remove a stale lock whose recorded PID is dead.
- Abort an unfinished rebase from a killed run with `git rebase --abort`.
- Fail loudly if paths outside `sessions/<host>/` and `health/` are dirty.
- Preserve all user and repository changes; it must never auto-reset them.

Every later phase must be safe to repeat after termination.

### JSONL mirroring

Mirror supported JSONL sources into `sessions/<host>/...` with:

```sh
rsync -a \
  --include='*/' \
  --include='*.jsonl' \
  --include='memory/*.md' \
  --exclude='*' \
  --prune-empty-dirs \
  --max-size=90m
```

This filter excludes unmatched content such as Claude's `tool-results/` caches. Each harness gets its own include list rooted at its archive-relevant subtree; the cursor mirror is rooted at `agent-transcripts/` and adds `--include='*.txt'` there, so credential-bearing neighbors like `mcp-auth.json` are structurally unreachable rather than merely filtered.

Do not use `--delete`. The repository is an archive, so files removed or pruned from live sources must remain in Git.

Append oversized paths to `sessions/<host>/SKIPPED.md`. A skipped file must appear in committed state rather than only in logs.

Staging never parses rsync output. After mirroring, `git status` over this host's owned paths is the ground truth for what to stage — it is newline-safe and crash-safe (files mirrored by a run that died before committing are picked up by the next run).

### cursor-agent SQLite snapshots

The JSONL mirror must never copy SQLite databases directly.

Walk every `store.db` under the cursor source roots. Treat a newer database or `-wal` sibling as evidence of a possible update. For each candidate:

1. Run `sqlite3 <src> ".backup <dest.tmp>"`.
2. Hash the completed snapshot.
3. Retain it only if its content hash differs from the archived copy.
4. Move the snapshot into place atomically.

SQLite's backup API creates a consistent copy while cursor-agent writes. Inspecting the WAL avoids missed changes. Hash comparison prevents a busy but unchanged database from creating a new binary Git object each hour.

### Archive feedback prevention

Skip source project directories matching:

```text
*wiki-agent-sessions*
```

Orca can flatten one repository workspace into several directory names, so the exclusion must be a pattern rather than one literal path.

### Commit, rebase, and push

Stage everything dirty under this host's owned paths (its archive directory, `SKIPPED.md`, and its heartbeat):

```sh
git add -A -- "sessions/<host>" health
```

When staged files exist, use this commit format:

```text
sync(<host>): <UTC date>, N files
```

Then run:

```sh
git pull --rebase
git push
```

Retry this pull-and-push sequence no more than three times. Separate per-host paths prevent ordinary cross-host rebase conflicts.

If a pull changes `.agents/skills/session-sync/scripts/`, re-execute the newly pulled script once. An environment flag must prevent a re-exec loop.

After a successful synchronization, write `health/<host>.json` with:

- Last successful synchronization time.
- Script commit.
- File count.
- Byte count.

Commit the heartbeat with the host's synchronization changes. Any machine, including the daily ingest host, can use these files to detect a silent host.

If SSH or another network error prevents a push, log the failure and exit nonzero. Keep the local commit so the next hourly precheck finds and retries it.

### Local run state

Every successful or failed run must atomically write:

```text
$XDG_STATE_HOME/wiki-agent-sessions/latest.json
```

The file records:

- Phase reached.
- Exit code.
- HEAD SHA.
- Counts.
- Duration.
- Exact command to run after a failure.

Store timestamped, size-bounded logs beside it. The state directory must have mode `0700`. Operator status recipes read `latest.json` first.

Each run also records the age of the newest commit touching `wiki/`. It warns in both run output and `latest.json` when that age exceeds 48 hours. The daily fleet audit runs on the ingest host, so a dead ingest host would silence its own alarm. This warning lets every other host detect stale wiki output.

### Discovering archived hosts

When a pull introduces a new `sessions/<host>` directory, `sync-sessions` must reconcile `~/.agentsview/config.toml` immediately.

The Python script will use `tomlkit` in process and generate the same repository `[[session_sources]]` entries as the chezmoi agentsview modify template. A shared fixture test must prove that both implementations produce identical entries.

Restart agentsview only when configuration changes:

```sh
agentsview serve --background --replace
```

Guard the restart with `command -v`. Do not follow it with `agentsview sync`.

## Synchronization precheck

`.agents/skills/session-sync/scripts/sync-precheck` exits zero when any condition requires a real run:

1. Local session files are new or changed.
2. The clone has unpushed commits.
3. The remote branch is ahead of the local branch.

Compare `git ls-remote` with the local ref to detect a remote-ahead branch. An otherwise idle machine must still pull archives uploaded elsewhere.

Exit nonzero only after confirming that the repository is idle. DNS, SSH, authentication, timeout, and repository-probe failures must exit zero so `sync-sessions` runs and reports the actual error. A failed probe must never appear as an idle hour.

Keep the precheck stat-only: file counts, modification times, and Git refs. It must not hash session contents or run a repository-wide `git status`. Current measurements are about 0.5 seconds for an rsync dry traversal and 0.6 seconds for `ls-remote`.

## agentsview configuration

Update:

```text
home/private_dot_agentsview/modify_private_config.toml.tmpl
```

Manage a dotfiles-owned set of `[[session_sources]]` entries. Generate one entry for every supported other-host root found by this sorted runtime glob:

```text
~/code/github.com/prateek/wiki-agent-sessions/sessions/*/{claude/projects,cursor/projects,codex/*}
```

Exclude the current host. A Claude entry has this form:

```toml
[[session_sources]]
agent = "claude"
dir = "/Users/prungta/code/github.com/prateek/wiki-agent-sessions/sessions/<host>/claude/projects"
machine = "<host>"
```

Local defaults remain active because `session_sources` entries are additive. Leave the existing `codex_sessions_dirs` setting for local Orca `CODEX_HOME` directories unchanged.

Reconcile only generated entries whose `dir` is under the wiki clone. Preserve hand-written `session_sources`, unrelated settings, and secrets. Continue using `tomlkit` so all preserved content round-trips unchanged.

Resolve globs in the Python script at runtime. Go-template rendering must never access the filesystem. Emit no repository entries when the clone is absent.

### agentsview tests

Update:

```text
tests/agentsview-config-modify.zsh
```

Correct the stale pre-rename path at line 16. Add an environment override that redirects runtime globbing to fixtures, then assert:

- Every other-host root produces an entry with the correct `agent` and `machine`.
- Entries are sorted, and the current host is absent.
- Hand-written `session_sources` entries survive unchanged.
- The existing `codex_sessions_dirs` setting survives unchanged.

CI does not currently run this test. Add `make test-agentsview-config` to `.github/workflows/install-smoke.yml`.

## Orca automations

Orca creates scheduled prompts through this interface:

```text
orca automations create \
  --name <name> \
  --trigger hourly|<cron> \
  --prompt <text> \
  --provider claude \
  --workspace <selector> \
  --workspace-mode existing \
  --precheck <command> \
  --missed-run-grace-minutes <minutes> \
  --json
```

A nonzero precheck exit skips the run before Orca starts an agent. The reconciliation helper will also use `list`, `show`, `edit`, `run`, `runs`, and `remove`.

Record both desired definitions in the wiki repository's `AGENTS.md`.

### `wiki-sessions-sync`

Register this automation on every participating machine:

```text
--trigger hourly
--provider claude
--workspace <owner clone>
--workspace-mode existing
--precheck .agents/skills/session-sync/scripts/sync-precheck
--missed-run-grace-minutes 55
```

Its prompt instructs the agent to run the `session-sync` skill and report the result. The skill delegates all writes to the committed synchronization script.

### `wiki-sessions-ingest`

Register this automation only on the designated ingest host, initially the current machine:

```text
--trigger daily
--time 06:00
```

Its prompt performs these steps under `with-repo-lock`:

1. Pull the repository.
2. Run the committed `audit-heartbeats` script, which reads the machine-readable `health/expected-hosts` roster.
3. Fail loudly with the audit's output when any heartbeat is missing, malformed, or older than 26 hours. Orca run history plus `latest.json` carry the alarm (an Orca run row can close before the agent finishes, so the deterministic audit is the trustworthy signal).
4. Run `/wiki-history-ingest` on the delta for every `sessions/<host>/claude` directory. Set `CLAUDE_HISTORY_PATH` for each host and process the newest sessions first.
5. Enforce a bounded page budget. The manifest records coverage; raw search remains available while backfill ingestion catches up.
6. Commit only paths under `wiki/`. Include the ingested archive HEAD SHA in the commit message.
7. Push the result.

obsidian-wiki keys source data in its manifest by absolute path. Clone locations and `$HOME` should remain consistent when the ingest role moves, but migration may still re-ingest deltas. Manifest-tracked pages deduplicate by page identity. Document this migration cost in the operator skill.

## Dotfiles changes

### Machine settings

Update:

```text
home/.chezmoidata/machines.toml
```

Add these flat scalar settings:

```toml
agent_session_wiki = false
agent_session_wiki_ingest = false
```

Set `agent_session_wiki = true` for personal, homelab, and work machines. Keep it false for CI.

Set `agent_session_wiki_ingest = true` only under the designated host:

```toml
[machines.host.<this-host>]
```

Every host with `agent_session_wiki = true` must define `wiki_host_alias`.

Update `tests/machines-features.zsh` to check the flags, required aliases, and alias uniqueness.

### Chezmoi bootstrap

Add:

```text
home/.chezmoiscripts/run_onchange_after_38-agent-session-wiki.sh.tmpl
```

The template must:

- Source `script_lib.sh`.
- Include sha256 comments covering `machines.toml`, the automation helper, and the agentsview modify template.
- Avoid template-time filesystem access so CI dry-run rendering remains safe.
- Use this gate:

```gotemplate
{{ if and $f.run_install_scripts $f.agent_session_wiki }}
```

When disabled, the `{{ else }}` branch calls the automation helper in disable mode if `orca` exists. Both automations become `--disabled` without losing run history. Setting `agent_session_wiki = false` is the kill switch.

When enabled, the script must:

1. Ensure the repository exists at:

   ```text
   ~/code/github.com/prateek/wiki-agent-sessions
   ```

2. Use its SSH remote.
3. Probe access with `git ls-remote`.
4. Warn and exit zero when credentials are unavailable.
5. Call `die` only if an existing clone has the wrong remote.
6. Run the automation reconciliation helper.
7. Restart agentsview if its configuration changed.

Optional CLIs are recoverable:

```sh
have orca || warn
```

Absence of Orca or another optional CLI must warn rather than call `die`.

### Automation reconciliation helper

Add:

```text
scripts/agent-sessions/register-wiki-sync-automation
```

It must be a standalone, idempotent Bash script:

```bash
#!/usr/bin/env bash
```

The shebang enrolls it in CI shellcheck.

For each automation, the helper must:

1. Read the existing definition with `show --json`.
2. Compare its name, trigger, prompt, and precheck with the desired definition.
3. Use `edit` when the definition has drifted.
4. Use `create` when no definition exists.
5. Reconcile sync and ingest according to the machine flags.
6. Support a disable mode that marks both definitions `--disabled` without deleting run history.

If Orca has not registered the repository, inspect `orca --help` during implementation. Use its repository-registration command when available. Otherwise warn and print the required manual `ohc` command.

The helper must remain manually runnable. Chezmoi records a warning `run_onchange` script as successful and will not automatically retry when credentials or optional tools appear later. The helper is the recovery command, and script 90 must report incomplete registration.

### CLI configuration

Update:

```text
home/dot_config/mise/conf.d/clis.toml
```

Add:

```toml
"pipx:obsidian-wiki" = "latest"
```

Add the CLI required by kepano's `obsidian-cli` skill after confirming its binary and installation source. Keep entries alphabetized and include the customary inline comments.

### obsidian-wiki configuration

Add:

```text
home/dot_config/obsidian-wiki/config
```

It must set:

```text
OBSIDIAN_VAULT_PATH=~/code/github.com/prateek/wiki-agent-sessions/wiki
```

Verify the file's exact format against obsidian-wiki's source during implementation.

Gate the file in:

```text
home/.chezmoiignore
```

Use `agent_session_wiki` and follow the existing mcporter/granola pattern.

### Plugin package validation

Create the package under:

```text
home/dot_agents/packages/obsidian-wiki/
```

Use the repository scripts at their actual paths because they are not on `PATH`:

```text
.agents/skills/agent-skill-management/scripts/vendor-agent-package
.agents/skills/agent-skill-management/scripts/validate-agent-packages
```

The package changes generated Claude, Codex, and pi projections. Update expectations in:

```text
tests/agent-skill-packages.zsh
tests/claude-settings-modify.zsh
tests/codex-config-modify.zsh
```

Run:

```sh
make test-agent-skill-packages test-claude-settings test-codex-config test-pi-settings
```

### Operator skill

Add:

```text
home/dot_agents/packages/utils-agent/skills/local/agent-session-wiki/SKILL.md
```

Document:

- Repository location and layout.
- Raw synchronization and designated-host ingestion.
- Cross-host agentsview and obsidian-wiki queries.
- Skipped Orca runs.
- Push races and retries.
- agentsview daemon restarts.
- Ingest-host migration.
- Review of `SKIPPED.md`.

Do not change `package.toml`; the package tree hash triggers plugin rendering.

Validate with:

```sh
.agents/skills/agent-skill-management/scripts/validate-agent-packages
```

### Apply verification notes

Update:

```text
run_onchange_after_90-verify.sh.tmpl
```

Add non-failing status notes that report whether the clone exists and whether both automations are registered with their desired definitions. Follow the existing Tartelet-block precedent.

### Repository documentation

Add:

```text
docs/plans/agent-session-wiki-plan.md
```

Add the next numbered ADR. It must record the decisions to keep raw sessions in Git, use designated-writer ingestion, and schedule through Orca. Cross-link the plan and ADR, then update `docs/index.md`.

Update:

```text
home/dot_agents/docs/agentsview.md
```

Use `home/private_dot_agentsview/` as the managed source path. Document the generated `[[session_sources]]` entries alongside the existing local Codex directory configuration.

Run:

```sh
make test-docs-lifecycle
```

## Rollout

1. Build the wiki repository files and scripts in:

   ```text
   ~/code/worktrees/wiki-agent-sessions/wiki-agent-sessions
   ```

   Push the structure and synchronization scripts. Protect the default branch against force pushes and deletion through a repository ruleset or classic branch protection via `gh api`. Archive integrity depends on preserving Git history.

2. Run a full backfill on the current machine. Execute `sync-sessions`, then measure the packed repository with a bundle:

   ```sh
   git bundle create /tmp/backfill.bundle HEAD && ls -lh /tmp/backfill.bundle
   ```

   `git count-objects -v` measures loose objects and does not estimate the delta-compressed push accurately.

   The current machine contributes about 2.9 GB of raw input: 951 MB of Claude data, 1.9 GB of cursor data, and pi data. The Claude portion alone compresses with gzip to about 300 MB; cursor transcripts use the same JSONL shape. GitHub's push cap is about 2 GB.

   Use the bundle measurement to divide the backfill into commits and pushes grouped by harness and batches of project directories. Verify the archive layout and prove that an immediate second synchronization is a no-op before pushing.

   Add `sessions/*` roots to agentsview only after the backfill push completes, so agentsview does not index a moving target.

3. Implement the dotfiles work in the `av-history` worktree. A plain `chezmoi apply` reads the canonical `~/dotfiles` source and would apply the previous master state during the pilot. Use either:

   ```sh
   chezmoi -S <worktree>/home apply ...
   ```

   or land the branch through the normal `land-changes` flow before applying. Confirm afterward that chezmoi's configured default source is still the canonical checkout.

4. Run both automations once:

   ```sh
   orca automations run <id> --json
   ```

   Inspect `orca automations runs` and the resulting Git commits.

5. Apply the dotfiles changes on the remaining machines. Their next `chezmoi apply` will clone the repository, reconcile the relevant automations, and update agentsview.

## Verification

### Synchronization scripts

Run shellcheck on `sync-precheck` and `with-repo-lock`; CI discovers both through their shebangs. Cover the Python `sync-sessions` script with behavior tests and the shared agentsview-source fixture test.

Test `sync-precheck` under each condition:

- New or changed local files: exit zero.
- Unpushed commits: exit zero.
- Remote-ahead branch: exit zero.
- Fully converged repository: exit nonzero.
- Unreachable remote: exit zero so the real run reports the failure.
- Wedged repository probe: exit zero for the same reason.

Run `sync-sessions` twice and confirm that the second run changes nothing.

Kill synchronization during a rebase and confirm that the next run aborts the stale rebase and recovers.

Run:

```sh
make test-chezmoi-script-status
make test-machines-features
```

Ensure script 38 is enrolled in the script-status test.

Perform one retrieval test for each supported consumer:

- Find a known Claude session in agentsview.
- Find a known pi session with `obsidian-wiki sessions-query`.
- Check that `AGENTS.md` describes every harness's support accurately.

### Concurrency

Create two temporary clones with distinct `$WIKI_SESSIONS_HOST` values. Start both synchronizations concurrently and verify that:

- Both pushes succeed.
- No cross-host conflict occurs.
- Both clones converge after pulling.

Start synchronization while ingestion holds the repository lock. Confirm that `with-repo-lock` serializes the two operations.

### Chezmoi and agentsview

Render CI, personal, and work configurations:

```sh
chezmoi apply --dry-run --verbose --exclude=scripts
```

All three machine types must render without errors or template-time filesystem access.

Run:

```sh
tests/agentsview-config-modify.zsh
```

Verify separately that agentsview accepts the generated `[[session_sources]]` entries:

```sh
agentsview sync
```

This command is a configuration acceptance test. Runtime configuration changes still use `agentsview serve --background --replace` without a following explicit sync.

Simulate a fresh host with a temporary `HOME`. Run script 38 without Git credentials and confirm that it warns and exits zero.

Run the plugin and configuration checks:

```sh
make test-agent-skill-packages test-claude-settings test-codex-config test-pi-settings
make test-agentsview-config
```

### Wiki ingestion

Run `/wiki-history-ingest` against:

```text
sessions/<this-host>/claude
```

Confirm that it creates files only under `wiki/`.

Run:

```sh
obsidian-wiki sessions-build --claude-dir <repo-host-claude-dir>
```

Confirm that it builds from the archived host directory rather than live `~/.claude`.

Run both Orca automations manually. Inspect their run histories, resulting commits, heartbeat audit, and archive-HEAD marker.

### Final checks

Run:

```sh
make test-docs-lifecycle
git diff --check
```

## Accepted risks and alternatives

- Raw sessions remain in Git because this keeps the archive inspectable and matches the synchronization model. Restic or object storage can replace it if measured repository growth becomes operationally expensive.
- Every configured work machine participates because omitting the work laptop would leave the cross-machine archive incomplete.
- Orca owns scheduling because its precheck avoids agent use during idle hours while retaining run history and agent-driven failure handling. `launchd` would not provide that operating model.
- A concurrent append can leave a torn final JSONL line in one hourly copy. Readers skip incomplete final lines, and the next synchronization recopies the file.
- agentsview runs on every participating machine so sessions are browsable from any host. Each machine pays a one-time indexing cost when it discovers new roots.
- agentsview watches the live clone while `git pull --rebase` rewrites files in place. Upstream recommends staged publication (pull into a staging checkout, atomically switch) to avoid transient parse errors on partially written files. Accepted: the watcher retries changed files and the 15-minute periodic sync re-reads them, so torn reads self-heal. Adopt a published-worktree flip only if transient errors prove noisy in practice.
- Unique aliases in the central `machines.toml` registry identify hosts. The uniqueness test supplies the collision guarantee needed for this single-operator fleet, so machine UUIDs are unnecessary.
- The archive has no protocol version or canary rollout. Re-executing newly pulled scripts limits version skew, and the fleet has one operator.
- Cross-host search uses agentsview and the machine-wide operator skill. No global MCP search tool is included.
- agentsview reads raw Git mirrors through `[[session_sources]]`, its documented configuration for native layouts transported out of band. `agentsview sync --target` produces normalized, content-addressed artifacts with incremental cursors and machine identity, shipped in 0.40.0 on 2026-08-02, but its folder transport is unsafe for this Git multi-writer topology. It uses one global `head.json` and globally sequenced `event-<seq>.json` records (`internal/artifact/transport_folder_journal.go:16,40`), so publishers can collide between pulls. It also omits raw provider files. Reconsider it if upstream adopts per-origin journals.
- The measured backfill pilot is the acceptance gate for the wiki layer. There is no separate staging gate.
- Failure procedures have two homes: the machine-wide operator skill for fleet operation and the repository-local synchronization skill for automation recovery.

## Deferred work

- **Delta secret scanning:** Run `gitleaks` on files added or changed before each commit. Quarantine findings in `SKIPPED.md` so they are neither pushed nor allowed to wedge synchronization. Delta-scoped staging provides the insertion point.
- **Gemini CLI and Copilot CLI:** Add each source through one source-map entry when transcript volume warrants support. Never mirror Gemini's credential-bearing directory wholesale.
- **Growth policy:** Review capacity after one year or when the packed repository exceeds about 3 GB. Use measured accretion and the initial bundle baseline to decide whether older data should move into yearly Git archive repositories. Pruning the repository never loses sessions that machines already ingested — each agentsview SQLite archive persists them independently.
- **Poisoned-file containment:** Add a committed denylist that prevents quarantined live files from being imported again. Document sensitive-data removal through history rewriting and fleet recloning. Until then, record affected paths in `SKIPPED.md` and use forward deletion.
- **agentsview artifact-folder transport:** Pilot `agentsview sync --target <clone>/av-artifacts` if upstream replaces the global journal with per-origin journals. If it proves safe, it can replace the generated view-plane `[[session_sources]]` entries. The raw archive remains because artifact folders contain normalized data rather than provider files.
- **Active notifications:** Add a channel such as ntfy if Orca run history proves too passive after repeated ingest failures or stale hosts.
- **Wiki maintenance cadence:** Set `LINT_SCHEDULE=weekly` when page volume warrants scheduled linting.
