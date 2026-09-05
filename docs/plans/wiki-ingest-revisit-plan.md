---
status: draft
doc_type: plan
owner: Prateek
created: 2026-09-05
updated: 2026-09-05
status_detail: "TODO; scheduled wiki ingest is disabled pending a later decision."
related:
  - agent-session-wiki-plan.md
---

# Revisit wiki ingestion

Scheduled wiki ingestion is disabled on m4mini. Raw session archiving continues
hourly through launchd; AgentsView can still read the existing archive.

- [ ] Decide whether generated wiki pages are useful enough to maintain.
- [ ] Choose manual or scheduled ingestion and a bounded page, time, and storage budget.
- [ ] Validate one ingest run before assigning an ingest host or restoring a schedule.

The switch is `machines.host.m4mini.agent_session_wiki_ingest` in
[machines.toml](../../home/.chezmoidata/machines.toml). Keep it false until
this TODO is revisited.
