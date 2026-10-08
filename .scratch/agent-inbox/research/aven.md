# Research: can aven be the worktree-inbox item store?

Ticket: [01 — Can aven be the item store?](../issues/01-aven-as-item-store.md)
Date: 2026-09-29
Source: `raine/aven@main` via the `ask` cache at `~/.cache/ask/github/github.com/raine/aven/main` (fetched 2026-09-29; `Cargo.toml:27` = v0.1.44, the latest release). Paths below are relative to that checkout. Maturity data from `gh api repos/raine/aven`. Live checks used the locally installed `aven 0.1.39` (Homebrew) against a throwaway `AVEN_CONFIG_DIR`/`AVEN_DB`, deleted afterwards.

## Recommendation

**Adopt with conventions**, for storage and for personal-fleet sync, behind our own thin `inbox` CLI that calls only aven's public CLI. Work hosts get a physically separate aven database that never points at the personal server (local-only on work-mbp in v1). Aven's sync replaces a custom cross-host protocol for the personal hosts; it does not give a per-item "pending queue", and the host-owns-its-inbox rule becomes a metadata convention rather than a storage fact.

**Fallback:** SQLite per host with our own schema and CLI, exposed to other hosts over Tailscale. Choose it if aven's churn (bus factor 1, three months old, one forced lockstep sync upgrade already) bites, or if Cortex XDR kills `aven` on work-mbp. Keeping every caller on our `inbox` wrapper makes that swap a backend change, not a caller change. Files-in-the-worktree and git-backed stores are worse here: removing a worktree deletes the files, and git adds merge noise for no gain over SQLite.

## 1. Model fit

**Worktree scoping needs metadata.** Aven infers the project from the git root, and for a linked worktree it deliberately resolves `commondir` back to the *main* checkout (`src/projects.rs:181-205`). Every Orca worktree of `dotfiles` therefore lands in project `dotfiles`. That is the right grouping for humans, but a worktree has to be expressed another way. Per-worktree projects would fight this inference and pollute project prefixes.

**Custom metadata covers the rest.** Tasks carry workspace-scoped `key=value` string metadata (`docs/src/content/docs/task-metadata.md:6-31`): keys up to 64 bytes, reserved `aven.` prefix, values up to 4 KiB, 128 values per task. `list` and `search` filter by exact value, present, or missing, and the filters repeat and combine (`task-metadata.md:67-84`). Metadata syncs, merges concurrent key creation, and records conflicts (`task-metadata.md:154-156`).

| Inbox concept | aven primitive | Convention needed? |
| --- | --- | --- |
| Owning inbox (worktree on a host) | metadata `inbox.worktree=<ORCA_WORKTREE_ID>` + `inbox.host=<LocalHostName>`; project = repo (automatic) | Yes |
| Recipient human/agent/both | metadata `inbox.recipient`; optionally mirrored as a label so the TUI can filter it (the TUI filters by label and priority, not metadata: `tui.md:83-91`) | Yes |
| Target session | metadata `inbox.session=<ORCA_TERMINAL_HANDLE or agent session id>` | Yes |
| Author | metadata `inbox.author=human\|agent:<worktree>/<session>` | Yes. Notes have no author column (`crates/aven-core/migrations/20260618000000_initial.sql:44-50`); task `source` is only `cli/tui/api/ios/...` (`ARCHITECTURE.md:191`) |
| Open / resolved | status: open = `inbox/backlog/todo/active`, resolved = `done/canceled` (`concepts.md:25-36`) | Map only |
| Proposed resolution | metadata `inbox.resolution=proposed` plus a note. The status enum is closed (`ARCHITECTURE.md:189`), so there is no native "proposed" | Yes |
| Resolution notes | append-only notes (`concepts.md:40-44`) | No |
| Delivered | a row exists in the recipient host's replica | No |

Verified live: an item created with four `inbox.*` keys, filtered with two repeated `--metadata` predicates, then read back through `show --full --json`, which returns a `metadata` object and a `notes` array.

**Human-only resolution is not enforced.** Any caller can set `--status done`, and aven has no actor or permission model. "Items involving the human resolve only after confirmation" must be enforced by our wrapper and the agent conventions, and audited by `inbox.resolved_by` metadata.

## 2. Agent surface

- **Scriptable.** `--json` on `list`, `show`, `search`, `context`, `prime`, `metadata`, `conflict`, `doctor`, `sync status` and others (`docs/src/content/docs/command-reference.md:54-56`). `add`, `edit` and `note` print a stable `key=value` line instead (`created DTF-MX02 ref=MX02 project=... status=...`, `src/commands/tasks.rs:346-348`), which is easy to parse but not JSON.
- **Compact list rows omit metadata** (`task-metadata.md:95`). Verified: `list --json` has no `metadata` key. Listing "open items with their recipient and target session" costs one `show --full --json` per item, or one filtered `list` per recipient value. This is fine at inbox volumes.
- **Stable IDs.** 16-char Crockford Base32 from 80 random bits, generated offline (`ARCHITECTURE.md:192`). Display refs such as `DTF-MX02` can lengthen and change prefix when a task moves projects (`src/skill.md:26-30`), so our wrapper should store and print the full `id`.
- **Non-interactive.** Every command takes flags or stdin (`--description-stdin`, `note --stdin`). `--db`, `AVEN_DB`, `AVEN_CONFIG_DIR` and `--workspace` make routing explicit (`command-reference.md:8-21`, `configuration.md:12,136,417-420`).
- **Concurrent writers are safe.** Mutations run in `BEGIN IMMEDIATE` transactions (`crates/aven-core/src/db.rs:276-279`, `crates/aven-core/src/mutation.rs:30`) on a WAL pool with a 5 s busy timeout (`db.rs:160-169`). Sync takes an exclusive kernel lock on a sidecar file (`ARCHITECTURE.md:168`). Verified: 20 parallel `aven add` processes on one DB, zero errors, all rows present.
- **The shipped skill** (`skills/aven/SKILL.md` shells out to `aven skill`, i.e. `src/skill.md`) assumes aven is a *task manager for the current repo*. It says "Do not create tasks unless the user asks" (`src/skill.md:6-7`), infers project from cwd (`:11-12`), and tells agents to set tasks `active`/`done` themselves (`:67`). That last line conflicts with our human-confirmation rule. `aven prime` dumps project-wide open tasks with the full skill (`docs/src/content/docs/agents.md:190-229`) and cannot filter by metadata. **Do not install aven's skill or `aven prime` hook for inbox use.** Ship our own `inbox` skill and a session-start one-liner built on `list --metadata ... --json`.

## 3. Human surface

- **"Open items for this worktree"** works in the CLI: `aven list --open --metadata inbox.worktree=<id>`. The TUI cannot filter by metadata. It filters by label and priority (`tui.md:83-91`, `command-reference.md` `aven tui` flags) and its `/` search matches metadata text (`tui.md:81`). A per-worktree TUI view needs either a label per worktree (label churn) or search.
- **"Items waiting on me across worktrees"** works if `recipient` is mirrored into a label (`for-human`): `aven tui --label for-human` or `aven list --open --label for-human`. With a shared personal server, that view covers every personal host's worktrees for free.
- The queue view (`concepts.md:110-127`) ranks by priority, status and staleness. Using `priority=high` for human-bound items would surface them under "Focus". Sync conflicts land in "Needs action".
- Resolved items stay queryable after the worktree is gone (soft delete, done/canceled history), which partly answers the "archive record" fog item.

## 4. Sync

- **Topology** is hub-and-spoke. Each client writes to its local SQLite and appends to a `changes` op log; `aven sync` pushes unsynced rows and pulls everything after its cursor from one self-hosted server (`docs/src/content/docs/sync.md:6-8`, `ARCHITECTURE.md:165-176`). `aven server --bind <addr> --data <file>` runs on macOS or Linux (release assets include darwin and linux, amd64 and arm64). m4mini fits, run as a LaunchAgent after Tailscale is up (`sync.md:96-103`).
- **Transport and auth.** Plain HTTP with one shared bearer token (`src/sync/server.rs:374-388`). A private bind requires a token (`server.rs:84-92`). Tailscale's `100.64.0.0/10` is classified as private (`server.rs:66-73`, tested at `:456-464`), so `--bind <m4mini tailscale IP>:3746` plus a token works without `--unsafe-public-bind`. Anyone holding the token reads and writes everything, and the token check is a plain `==`. Tailscale ACLs are the real boundary.
- **Conflict model.** Field-level: a version mismatch records a conflict instead of overwriting (`concepts.md:133-137`, `ARCHITECTURE.md:175`), and the conflict is resolved explicitly (`sync.md:230-244`). Verified: `done` on one replica and `canceled` on the other produced `conflict field=status`. For the inbox, a conflict on `status` is exactly the case where the human should decide, which suits us.
- **Offline.** Local writes never need the server. Unsynced rows have `server_seq IS NULL` (`ARCHITECTURE.md:167`). The daemon (`aven daemon install` as a LaunchAgent) wakes on local mutations, syncs periodically and backs off on failure (`sync.md:189-215`). Verified two replicas converging through a loopback server.
- **Pending queue: only partly free.** Offline capture gives durable store-and-forward: an item written for another host waits locally and lands when the server is reachable. But the only visibility is an aggregate count (`aven sync status --json` → `pending.changes`, `sync.md:162-173`). There is no per-task "not yet synced" flag in task JSON, and the queue waits on *the server*, not on the recipient host. So "items waiting for an unreachable recipient" cannot be listed per item without our own bookkeeping (e.g., `inbox.sent_at` compared with the last sync success time).
- **Every personal replica holds every personal item.** Pull is `SELECT ... FROM changes WHERE server_seq > ?` with no workspace or host filter (`crates/aven-core/src/sync/persistence/server.rs:188-196`), and selective sync is explicitly out of scope (`SYNC_PROTOCOL.md:242-243`). "An inbox lives on its host" is then a metadata fact, not a storage fact. That is good for a cross-host "waiting on me" view and harmless within the personal fleet.
- **Server pinning.** A DB pins the first server it syncs with, and a different server needs a fresh DB (`sync.md:185-187`). Moving the hub off m4mini later is a re-seed, not a config change.

## 5. Work/personal separation

- **Workspaces are not a security boundary.** They share one database (`README.md`, `concepts.md:10-12`), and sync ships every workspace's changes to every client of the server (see the pull query above). One shared server cannot keep work items off personal hosts.
- **Therefore:** work-mbp gets its own DB and config, and never gets the personal server URL or token. In v1 it stays local-only: a single work host needs no sync, and local-only DBs are fully functional at the baseline protocol (`sync.md:28-34`, `SYNC_PROTOCOL.md:126-129`). If a second work host appears, run a separate work server reachable only from work hosts. Enforce this in chezmoi: render `sync:` config only on personal machine types.
- **Personal repos on work-mbp** (e.g., dotfiles checked out there) still use work-mbp's local DB. That matches the map's rule that nothing syncs between work and personal hosts.
- **Running on work-mbp:**
  - Single static Rust binary via Homebrew tap `raine/aven` or release tarball.
  - TLS inspection matters only for update checks and self-update to GitHub, since sync to a loopback or Tailscale server is plain HTTP. reqwest is built with `rustls` plus `rustls-platform-verifier` (`Cargo.toml:43`, `Cargo.lock:2964-2990`), which consults the macOS trust store, so the MDM-installed corp CA should be honored. This is unlike webpki-only tools such as `ask`. Not verified on work-mbp. Disable checks anyway: `AVEN_NO_UPDATE_CHECK=1` / `update.automatic_checks: false` (`configuration.md:240-247`), and upgrade via brew.
  - Cortex XDR: the proven kill was a BIOC on the `omp` process name ("SOC - AI Apps"). Nothing suggests `aven` matches, but it is unverified. Smoke-test `aven add`/`list` and `aven daemon` on work-mbp before committing. Avoid `aven add --natural`, which spawns a configured agent command.

## 6. Maturity

- **Age and cadence:** repo created 2026-06-21; v0.1.0 on 2026-07-02; 45 releases through v0.1.44 on 2026-09-26, often several a week. 100 commits in the last 30 days. Actively maintained, still pre-1.0.
- **Bus factor 1:** contributors `raine` 1501 commits, `seungjuchoi` 5, `xe6` 1. 157 stars, 13 forks, 7 open issues. Issue #30 ("move tasks between workspaces") is open.
- **License:** MIT (`Cargo.toml:33`).
- **Schema:** 35 SQLx migrations since 2026-06-18 (`crates/aven-core/migrations/`). Migrations run forward automatically; downgrades are unsafe (`sync.md:48-51`, `SYNC_PROTOCOL.md:240-241`).
- **Sync protocol:** protocol 18 is the active version and the maintained baseline (`SYNC_PROTOCOL.md:54-59`). v0.1.37 (2026-09-07) forced a lockstep server+client upgrade (`CHANGELOG.md` v0.1.37). v0.1.41 added asymmetric compatibility: newer clients keep working with older servers, and unsupported clients pause sync while keeping local work (`CHANGELOG.md` v0.1.41, `SYNC_PROTOCOL.md:28-37`). The contract is now written down, but future server cutovers remain deliberate events (`sync.md:36-42`).
- **Architecture quality:** unusually thorough invariants and docs (`ARCHITECTURE.md`, `SYNC_PROTOCOL.md`, a frozen protocol-18 replay oracle at `SYNC_PROTOCOL.md:208-215`). Much of it is written as agent-facing guidance.

## Conventions if adopted

1. **Own wrapper.** Callers (agents, the Orca archive hook, Raycast, the card-comment count) use an `inbox` CLI we own. It shells out to aven's public CLI only, never reads aven's SQLite, and stores the full 16-char task `id`.
2. **Metadata keys** under an `inbox.` prefix: `worktree`, `host`, `recipient` (`human|agent|both`), `session` (optional), `author`, `resolution` (`proposed`), `resolved_by`, `sent_at`. Mark inbox items with an `inbox` label so aven's normal task use doesn't mix with them. Mirror `recipient` involving the human into a `for-human` label for TUI filtering.
3. **Project** = aven's automatic repo project (`src/projects.rs:181-205`). Never create per-worktree projects.
4. **Status mapping:** new items `todo` (or `inbox`); resolved `done`; dropped `canceled`. Human-bound items move to `done` only through the wrapper's confirm path.
5. **Separate databases per trust zone:** personal hosts share a server on m4mini bound to its Tailscale IP with a token. Work-mbp uses a local-only DB and never receives personal sync config. Enforce both in chezmoi templates.
6. **Versions:** pin via brew, disable auto-update checks, and upgrade clients before the m4mini server per `sync.md:36-42`.
7. **Skip aven's shipped skill and `aven prime`** for inbox sessions. Ship our own session-start count line.
8. **Pending-queue view:** derive it in the wrapper (locally authored items with `inbox.sent_at` later than the last sync success in `aven sync status --json`), since aven exposes only an aggregate count.

## Implications for other tickets

- **03 (item model):** the model maps onto aven tasks plus `inbox.*` metadata. There is no native "proposed" state and no note author, so both are metadata. Human-only resolution is wrapper policy, not storage policy. Refs are unstable, so use the id.
- **04 (topology):** hub-and-spoke on m4mini over Tailscale, not host-owned inboxes talking peer to peer. Every personal replica holds every personal item. Work-mbp stays an island. No custom wire protocol is needed; per-item pending tracking is ours to add.
