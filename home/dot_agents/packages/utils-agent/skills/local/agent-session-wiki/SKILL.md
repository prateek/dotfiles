---
name: agent-session-wiki
description: Operate the cross-machine agent-session archive (prateek/wiki-agent-sessions) — find past sessions from any host, run or troubleshoot the hourly sync and daily wiki-ingest Orca automations, check fleet health, and migrate the ingest role. Use when asked to find a session from another machine, check why session sync is failing or stale, review SKIPPED.md quarantines, wire agentsview to the archive, or ingest archived sessions into the wiki.
---

# Agent Session Wiki

Every machine mirrors its raw agent sessions hourly into
`~/code/github.com/prateek/wiki-agent-sessions` (`sessions/<host>/...`, native
layouts) and pushes; one designated host ingests the archive into `wiki/`
daily. The repo's `AGENTS.md` is the contract: layout, ownership, consumer
matrix, automation definitions, expected hosts. This skill is the operator
playbook; the in-repo `session-sync` skill is the automation's own failure
playbook.

## Find a past session (any host)

- **agentsview (Claude, Codex, cursor `projects/`)**: the dotfiles-managed
  `~/.agentsview/config.toml` carries generated `[[session_sources]]` entries
  for every other host in the clone, labeled by machine. Browse/search in the
  UI or `agentsview session list --format json`; filter by `machine`.
  A brand-new host appears after the next sync run or `chezmoi apply` (both
  regenerate entries and restart the daemon).
- **obsidian-wiki session brain (topic search, per host dir)**:

  ```sh
  obsidian-wiki sessions-build --claude-dir ~/code/github.com/prateek/wiki-agent-sessions/sessions/<host>/claude
  obsidian-wiki sessions-query "that auth bug with the retry loop"
  ```

- **pi sessions** are archive+wiki only (no agentsview parser): grep
  `sessions/<host>/pi/sessions/`, or ingest via `PI_HISTORY_PATH`.
- **cursor `chats/store.db` snapshots** are raw retention only; open with
  `sqlite3` if ever needed.

## Ingest archived sessions into the wiki

The daily automation does this on the designated host. Manually, for one host:

```sh
cd ~/code/github.com/prateek/wiki-agent-sessions
.agents/skills/session-sync/scripts/with-repo-lock zsh -c '
  CLAUDE_HISTORY_PATH=$PWD/sessions/<host>/claude claude -p "/wiki-history-ingest claude"'
```

Commit only `wiki/` paths; include the archive HEAD SHA in the message. The
manifest in `wiki/` dedupes already-ingested sources.

## Fleet health

- Per-host heartbeats: `health/<host>.json` in the repo (updated on sync, at
  least every ~20h). The daily ingest run fails loudly when any expected
  host's heartbeat exceeds 26h — check `orca automations runs` on the ingest
  host.
- Local run state: `${XDG_STATE_HOME:-~/.local/state}/wiki-agent-sessions/latest.json`
  (phase, exit code, next step) + timestamped logs beside it. Read this first.
- Wiki freshness: every sync warns (stdout + `latest.json`) when the newest
  `wiki/` commit is older than 48h — the redundant alarm for a dead ingest
  host.
- Automation status: `orca automations list --json`, run history via
  `orca automations runs --id <id> --json`. Hourly runs skipped by the
  precheck are normal (confirmed-idle hours).

## Troubleshooting

| Symptom | Meaning / action |
|---|---|
| Sync exit 3 | Host alias missing: `chezmoi apply` renders `~/.config/wiki-agent-sessions/config.toml` from machines.toml `wiki_host_alias` |
| Sync exit 4 | Dirty paths outside the host's archive — someone's WIP; never reset, resolve by hand |
| Sync exit 5 | Push failed 3×; next hourly run retries (unpushed-commits precheck clause). Persistent → check SSH/network in the log |
| Sync exit 6 | Rebase conflict — near-impossible with per-host paths; suspect two machines sharing an alias (machines.toml uniqueness test guards this) |
| Exit 75 | Repo lock held by live sync/ingest; wait |
| Hourly runs all "skipped" while sessions pile up | Precheck stamp semantics broke or automation precheck path drifted — run the sync manually and read `latest.json` |
| New host invisible in agentsview | Restart the daemon (`agentsview serve --background --replace`) or wait for the next sync/apply; entries regenerate from the clone glob |
| `SKIPPED.md` grew | Oversize (>90 MB) or quarantined source files; review whether to split/ignore |
| Automations unregistered (fresh machine, orca installed later) | `~/dotfiles/scripts/agent-sessions/register-wiki-sync-automation --enable [--ingest]` — the run_onchange script won't refire on its own |

## Onboard a machine

1. Add `wiki_host_alias = "<alias>"` under its `[machines.host.<hostname>]`
   layer in machines.toml (unique, non-empty; `make test-machines-features`
   enforces both). The machine type must have `agent_session_wiki = true`.
2. `chezmoi apply` on that machine: clones the repo, renders the alias
   config, registers the hourly automation, wires agentsview.
3. After its first successful sync, add the alias to `health/expected-hosts`
   in the wiki repo so the daily audit covers it.

## Migrate the ingest role

1. Move `agent_session_wiki_ingest = true` to the new host's
   `[machines.host.*]` layer in machines.toml (exactly one host, enforced by
   `make test-machines-features`).
2. `chezmoi apply` on both hosts (old one disables its ingest automation, new
   one registers it).
3. Expect some delta re-ingest: the obsidian-wiki manifest keys sources by
   absolute path; identical clone paths and `$HOME` minimize it, and
   manifest-tracked pages dedupe by page identity.

## Boundaries

- Never write to another host's `sessions/<host>/` or `health/<host>.json`.
- Never edit `~/.agentsview/config.toml` repo entries by hand — the modify
  template and sync script own them.
- The wiki plugin (`obsidian-wiki@prateek-local`) ships disabled; repos opt in
  via `.claude/settings.json` / `.codex/config.toml`. Never run global
  `obsidian-wiki setup` — it sprays skills into `~/.claude/skills` and
  `~/.agents/skills`, which the dotfiles plugin architecture forbids.
