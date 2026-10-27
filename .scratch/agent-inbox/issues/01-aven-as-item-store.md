# Can aven be the item store?

Type: research
Status: resolved
Blocked by: none

## Question

Can [raine/aven](https://github.com/raine/aven) store worktree-inbox items well enough to be v1's storage, and if so, can its sync replace a custom cross-host protocol?

Read the source and docs (`ask src github:raine/aven@main`; see `ARCHITECTURE.md`, `SYNC_PROTOCOL.md`, `docs/`, `skills/`) and answer:

1. **Model fit.**
   - Aven maps repos to projects. Can items be scoped to a *worktree* rather than a repo (tags, custom fields, per-worktree projects)?
   - Can it represent: recipient (human/agent/both), target session, author, open/proposed/resolved, and resolution notes?
   - Which of these need conventions layered on top?
2. **Agent surface.** Is the CLI scriptable (JSON output, stable ids, non-interactive), and is it safe for concurrent writers? What do its shipped agent skills assume?
3. **Human surface.** Can the TUI or queue view show "open items for this worktree" and "items waiting on me across worktrees"?
4. **Sync.**
   - What is the topology: a self-hosted server, and where would it run (m4mini)?
   - Conflict model, offline behavior, auth, and transport (does it work over Tailscale)?
   - Does offline capture give us the pending queue for free?
5. **Work/personal separation.** Workspaces share one database. Is that acceptable, or do work hosts need a separate database or server? Check that it can run on work-mbp (single binary? Cortex XDR risk? behind TLS inspection).
6. **Maturity.** Release cadence, schema stability and migrations, license, and bus factor.

Deliver a recommendation: adopt, adopt with conventions (list them), or reject, plus the fallback (SQLite per host, files in the worktree, or git-backed). Capture findings in `research/aven.md` in this effort directory, linked from here.

## Answer

Findings: [research/aven.md](../research/aven.md).

**Adopt with conventions.** aven stores items and syncs the personal hosts, behind a thin `inbox` CLI we own that calls only aven's public CLI. Work-mbp gets a physically separate database that never points at the personal server (local-only in v1).

Conventions:
- Worktree scoping lives in metadata (`inbox.worktree`, `inbox.host`), because aven folds every linked worktree into the main checkout's project.
- Recipient, target session, author and "proposed" are `inbox.*` metadata. The status enum is closed and notes have no author. Mirror human-bound recipients into a `for-human` label so the TUI can filter them.
- The wrapper enforces "human confirms before a human-involved item resolves". aven doesn't enforce it.
- Store the full 16-char id, not short refs. Read items with `show --full --json` because `list --json` omits metadata.
- Ship our own skill and session-start line. aven's skill tells agents to close tasks, and `aven prime` can't filter on metadata.

Consequences for 04: hub-and-spoke on m4mini over Tailscale with one shared token. Every personal host holds every personal item, so "the inbox lives on its host" is metadata, not data placement. Workspaces don't separate data: the server sends the whole change log. Offline writes queue durably, but only as a total count, so the per-item pending view needs our own tracking.

Open: smoke-test `aven` against Cortex XDR on work-mbp. Fallback if that or aven's churn bites: our own SQLite per host over Tailscale.
