---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-05
updated: 2026-09-07
status_detail: "Daily ingest is live and validated on m4mini with Claude Sonnet 5 at high effort."
related:
  - agent-session-wiki-plan.md
---

# Restore wiki ingestion

The always-on m4mini owns the daily wiki ingest role. Orca starts Claude at
06:00 in the full archive clone. The bootstrap writes a repo-local Claude
setting for `claude-sonnet-5` at `high` effort, so the automation does not
inherit the machine's default model.

- [x] Keep scheduled ingestion with a limit of about 15 pages total per run.
- [x] Use m4mini as the single ingest host.
- [x] Use Claude Sonnet 5 at high effort.
- [x] Validate one complete ingest run before closing this plan.

The switch is `machines.host.m4mini.agent_session_wiki_ingest` in
[machines.toml](../../home/.chezmoidata/machines.toml). The apply-time helper
also registers the archive clone with Orca when needed and writes
`.claude/settings.local.json` without discarding other local settings.
