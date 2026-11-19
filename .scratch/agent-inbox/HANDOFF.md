# Handoff: worktree inbox wayfinder map

Written 2026-09-29 for the next agent on branch `prateek/agent-inbox` (worktree `~/code/worktrees/dotfiles/agent-inbox`).

## Where things stand

- The map, glossary and tickets live in this directory. Start with [map.md](map.md) and [CONTEXT.md](CONTEXT.md). Don't re-litigate anything under the map's "Settled while charting" or "Decisions so far".
- The research tickets are resolved, and each ticket's `## Answer` summarizes its findings:
  - [01 aven as item store](issues/01-aven-as-item-store.md): adopt aven with conventions. Findings are in [research/aven.md](research/aven.md).
  - [02 Orca archive hook contract](issues/02-orca-archive-hook-contract.md): usable but leaky as the done check, and chezmoi can't install it. Findings are in [research/orca-archive-hook.md](research/orca-archive-hook.md).
- Tickets 03–06 are still open, and all of them are HITL.
  - 03 (item model and lifecycle) and 04 (cross-host topology) are unblocked now.
  - 05 waits on 03. 06 waits on 03.

## Next action

Run `/mattpocock:wayfinder` in **work through the map** mode, one non-research ticket per session, starting with [03 item model and lifecycle](issues/03-item-model-and-lifecycle.md).

- Grill Prateek. Never answer his side yourself.
- Map the answers onto aven's model using the conventions in 01's Answer: `inbox.*` metadata, a wrapper-enforced human confirmation step, full 16-char ids, and `show --full --json`.
- The open question 03 must settle is the durable target-session identity. `ORCA_TERMINAL_HANDLE` goes stale after an Orca restart. The candidates are `ORCA_PANE_KEY` and the provider session id.
- When the ticket closes, set `Status: resolved`, add `## Answer`, add a line to the map's "Decisions so far", and update `CONTEXT.md` as terms settle.

## Open threads that aren't tickets yet

- **Cortex XDR smoke test:** check whether it kills `aven` on work-mbp. This is unverified, and 01's fallback depends on it. It belongs in 04's grilling.
- **Dead Orca settings file:** the chezmoi Orca settings template (`orca-settings.base.json.tmpl`, rendered via `modify_orca-data.json.tmpl`) writes `orca-data.json`, which current Orca never reads. The live settings are in `profiles/local-default/profile-state.db`. This is outside this effort's scope, so surface it to Prateek and don't fix it here.
- **Scratch files in the branch:** `.scratch/agent-inbox/` is committed to this branch. Before the branch merges, the final spec and ADRs should move under `docs/plans/` and `docs/adr/`, following the repo's `AGENTS.md`.

## Sources

- Orca `main`: `~/.cache/ask/github/github.com/stablyai/orca/main`. Refresh it with `ask src github:stablyai/orca@main`.
- aven: `~/.cache/ask/github/github.com/raine/aven/main`. Refresh it with `ask src github:raine/aven@main`.
- Never read minified or bundled Orca app code.

## Suggested skills

- `mattpocock:wayfinder`: drives the map.
- `mattpocock:grilling` and `mattpocock:domain-modeling`: load both for tickets 03, 04 and 06.
- `mattpocock:prototype`: ticket 05.
- `utils-agent:orca-cli`: run `orca skills get orca-cli` before any Orca command.
- `utils-agent:ask`: upstream source.
- `core:writing-for-humans`: replies and prose artifacts.
