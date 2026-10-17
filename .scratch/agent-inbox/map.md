# Map: Worktree inbox

Label: wayfinder:map
Tracker: local markdown. Tickets live in `issues/NN-<slug>.md`; see `CONTEXT.md` for vocabulary.

## Destination

An implementation-ready spec plus ADRs, in this dotfiles repo, for a **worktree inbox**: items addressed to a worktree (and optionally a target session) for a human, an agent, or both. Items never auto-deliver in v1. Open items that involve the human block Orca worktree removal. It works across Prateek's hosts (personal-mbp, m4mini, work-mbp).

## Notes

- Domain: multi-machine, Orca-driven agent workflow (Claude Code and Codex). Vocabulary is in `CONTEXT.md`. Keep it current with the `domain-modeling` skill.
- Skills every session should consult:
  - `grilling` and `domain-modeling` for grilling tickets.
  - `research` for research tickets.
  - `orca-cli` before running any Orca command.
  - `ask` for source.
- Conventions: `~/.agents/docs/engineering.md`, `worktrees.md`, `agentsview.md`, `git.md`.
- Standing preferences:
  - Build our own layer, with no dependency on a tool's internals. Orca's **public** CLI and hooks may be reused where that makes the implementation easier.
  - Never read minified or bundled app code. Read upstream source with `ask src github:stablyai/orca@main`, and likewise `github:raine/aven@main`. If the ask cache looks stale, delete that one cache dir and re-fetch.
  - Work and personal data must stay separate. Work-mbp has TLS inspection, and Cortex XDR kills some binaries.
  - Plan, don't do: produce decisions. Execution stays outside this map.
- Prior research (session 2026-09-29, summarized here; details in the ticket bodies):
  - **Claude Code cross-session messaging**
    - Delivered through a per-session Unix socket on one machine. Reaching other machines needs Remote Control with claude.ai auth.
    - Claude-only. Receiver states are accept, hold, or refuse.
  - **Orca orchestration mailbox**
    - SQLite `orchestration.db`, addressed to live terminal handles, not stored per worktree.
    - Auto-types a pointer into idle terminals.
    - Relays across machines only for federated dispatches, and has no UI.
    - Rejected as the store.
  - **Orca diff comments**: human-authored, batch-sent to a chosen agent, with a `sentAt` field and resolvable. The closest UX analogue, but they have no CLI.
  - **Orca agent hooks**: one-way. They always print `{}`, so they can't block Stop.
  - **Orca plugin system**: v0 and experimental. Offers a right-sidebar panel, `terminal:send`, storage, and an `agent.status.changed` event.
  - **Agent environment**: agents get `ORCA_WORKTREE_ID`, `ORCA_TERMINAL_HANDLE` and `ORCA_PANE_KEY`.
  - **Orca archive hook**
    - `scripts.archive`, from `orca.yaml` or a per-repo local setting in `orca-data.json`. A non-zero exit blocks removal, and the UI offers an override (`src/main/worktree-archive-hook-gate.ts`).
    - The CLI `worktree rm` skips it unless `--run-hooks` is passed. There is no global all-repo hook.

### Settled while charting (2026-09-29, with Prateek)

- **Destination**: spec + ADRs, not a build.
- **Participants**: every agent Orca launches, not only Claude.
- **Base**: our own layer, not Claude-native messaging and not the Orca mailbox. Orca's public tech may be reused.
- **Scope**: start with items that never auto-deliver. Auto-delivery is later work (see fog).
- **Addressing**: items address a worktree on a host. The target session is optional, asked for when it can't be inferred (for example, several agents in one worktree).
- **Writers**: humans, an agent writing to itself, and agents in other worktrees or on other hosts, all through one CLI. Raycast and UIs wrap that CLI.
- **Done check v1**: the Orca archive hook fails removal while items addressed to you, or to both, are open, and lists them.
- **Resolution**: an agent may resolve items addressed only to agents. Items addressed to you, or to both, resolve only after you confirm in the session. The agent may propose a resolution.
- **Cross-host**: an inbox lives on its worktree's host. Nothing syncs between work and personal hosts. The mechanism is open (tickets 01 and 04).
- **Archived worktrees**: keep resolved items as a record. The mechanism is fog.
- **Outbox**: a view of sent items and their status, not a separate store. The only outbox that physically exists is the sender-side queue of items waiting for an unreachable recipient host. That queue is where you see and control pending items.
- **Session start**: an agent sees one line with the count of open items at session start. It is never interrupted mid-turn.
- **v1 UI**: CLI, plus a count in the Orca worktree card comment. An Orca plugin panel is fog.
- **Storage candidate**: evaluate [raine/aven](https://github.com/raine/aven) first (Prateek's suggestion). It is local-first SQLite with an agent-first CLI, a TUI, a self-hosted sync server, and workspaces.

## Decisions so far

<!-- one line per closed ticket: - [<title>](issues/NN-slug.md): <gist> -->
- [Can aven be the item store?](issues/01-aven-as-item-store.md): adopt with conventions behind our own `inbox` CLI; worktree/recipient/session/author/proposed as `inbox.*` metadata; personal hosts sync hub-and-spoke via m4mini, work-mbp gets a separate local-only DB; XDR smoke test pending, fallback is per-host SQLite.
- [Orca archive hook contract](issues/02-orca-archive-hook-contract.md): blocks removal with visible output and a re-run "Delete Anyway", but it's skipped by CLI rm without `--run-hooks`, UI Forget, a declined trust prompt, and CLI rm on SSH worktrees; it gets only paths, not ids; chezmoi can't install it (no writable settings surface), so install is a detected one-time Settings step with policy `run-both` or a committed `orca.yaml`; the `worktree.removed` plugin event is the post-removal archive trigger.

## Not yet specified

- **Auto-delivery**: draining approved items into a live session. Candidates are `orca terminal send --wait-submit` after `tui-idle`, native Claude `SendMessage` for Claude sessions, or a Stop/idle hook. Approval stays mandatory.
- **Stop-hook nudge**: a Claude/Codex Stop hook that reminds the agent of open items before it claims done. Orca's own hooks can't block, so it would sit next to them.
- **Harder done gates**: blocking the Orca card from moving to `completed`, or blocking landing a PR, while items are open.
- **UI**: an Orca plugin panel in the right sidebar, a Raycast list, or aven's TUI if aven wins. A view that aggregates every host.
- **Archive record**: where resolved items go when a worktree is removed (a file next to the wiki-agent-sessions archive, the PR body, aven history).
- **Worktree moves**: what happens to an inbox when work moves hosts through a `ho`/`hop` handoff, or when a worktree is recreated.
- **Installation**: rolling the archive hook out to every Orca repo via chezmoi (`modify_orca-data.json.tmpl`) without clobbering committed `orca.yaml` hooks.

## Out of scope

- General multi-agent orchestration (task DAGs, coordinators, gates). The `orca-stration` skill covers it.
- Replacing agentsview or the session archive. This effort only reads from them, if at all.
