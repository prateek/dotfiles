---
status: accepted
doc_type: adr
created: 2026-08-30
owner: Prateek
related:
  - ../plans/agent-session-wiki-plan.md
---

# ADR 0017: Cross-machine agent-session archive in git with a designated wiki writer

## Context

Agent session transcripts (Claude Code, cursor-agent, pi, Codex) accumulate
per machine and are searchable only locally. We want every machine's sessions
browsable from any machine, raw retention that outlives local pruning, and a
distilled obsidian-wiki knowledge layer — operated by one person with near-zero
babysitting.

## Decision

1. **Raw sessions live in a private git repo** (`prateek/wiki-agent-sessions`),
   mirrored in each harness's native on-disk layout under `sessions/<host>/`.
   Git is the transport; agentsview's `[[session_sources]]` is the documented
   consumer topology for exactly this shape (native layouts moved out of band,
   scanned as machine-labeled roots). No parser or sync protocol is built:
   the sync layer moves bytes only.
2. **Single writer per path.** Each host writes only `sessions/<host>/` and
   `health/<host>.json`; exactly one designated host (machines.toml
   `agent_session_wiki_ingest`) writes `wiki/`. Cross-host rebase conflicts
   are structurally impossible, so `pull --rebase` + retry is the entire
   concurrency story.
3. **Orca automations own scheduling**, not launchd: an hourly sync per
   machine gated by a stat-only precheck (skipped runs spawn no agent), and a
   daily wiki ingest on the designated host. Orca gives run history and
   agent-driven recovery bounded by the in-repo `session-sync` skill playbook.
4. **Host identity is an explicit unique alias** (`wiki_host_alias` in
   machines.toml); the sync fails closed without one. No hostname fallback:
   two machines named `macbook-pro` must not share an archive directory.

## Consequences

- ~1 GB packed backfill per machine today; growth is monitored via the bundle
  baseline, with sparse-checkout/rollover as future levers. agentsview's own
  SQLite archives persist ingested sessions independently of the repo.
- Work-machine transcripts land in a personal private repo — an explicit,
  accepted policy call; branch protection denies force-push/deletion.
- agentsview's `sync --target` artifact exchange was evaluated and rejected
  for now: its folder journal (global `head.json`, globally-sequenced events)
  is not git-multi-writer-safe at v0.41.1, and it carries no raw files.
- The obsidian-wiki skill set ships as a `default_loaded = false` plugin
  (ADR 0007); repos opt in per project. Global `obsidian-wiki setup` is
  forbidden — it writes into `~/.claude/skills` and `~/.agents/skills`,
  which the renderer owns.
