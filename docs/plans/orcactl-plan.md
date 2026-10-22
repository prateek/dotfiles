---
status: active
doc_type: plan
summary: "A kubectl-shaped Go CLI for Orca, built in this repo: phase 1 replaces the shortcut scripts (focus capture, agent identity, fork, reveal, Zen), later phases add worktree fork, handoff, review, resume, pane, and layout flows"
owner: Prateek
created: 2026-05-13
updated: 2026-10-22
status_detail: "Phase 1 (shortcut engine and cutover) in progress; later phases remain draft."
---

# orcactl — kubectl-shaped CLI for working with Orca

## Problem

Daily Orca workflows currently require either:

- Verbose `orca` CLI invocations with `--worktree id:<id>`, `--terminal <handle>`, `--json`, plus `jq` parsing for almost everything readable.
- Composing five-step flows (create worktree, transfer dirty state, fork agent session, set comment, spawn terminal) by hand in shell.

Several specific scenarios come up enough that they deserve first-class commands:

1. **Mid-conversation fork** — branch the current Claude/Codex session into a new worktree while letting the original keep running, preserving the dirty git state so both sides start from the same on-disk content.
2. **Handoff to a fresh session** — open a new worktree, summarize current state, hand off to a fresh agent (possibly different model/provider).
3. **PR review** — clone (if needed), worktree the PR head, seed an agent with PR context.
4. **Exploration / experiments** — fresh worktree off any base ref, optionally bound to an issue.
5. **Resume a just-exited session** — claude/codex print `--resume <uuid>` on exit; copy-pasting that command is friction worth removing.
6. **Read sibling pane output** — last shell command output, last agent reply.
7. **Layout changes** — split↔tab, swap split direction, join tabs into splits.
8. **External triggers** — Raycast / BetterTouchTool keybinds need to know the current Orca state to compose what to invoke.

Plus the daily-driver micros: status, comment, list, jump, dashboard.

## Architectural decisions

- **Orca-required.** Every subcommand calls `orca status --json` first and exits with a clear error if the runtime isn't `ready`. No graceful fallbacks.
- **Orca owns worktree creation.** Skip `w`/worktrunk for orcactl-managed worktrees. We invoke `orca worktree create` and let Orca pick the path under `~/orca-workspaces/<repo>/<name>`. Implication: the centralized `~/code/wt/<owner>-<repo>.<branch>/<repo>` layout from worktrunk doesn't apply to orcactl-managed work.
- **Always-explicit session IDs.** Every fork/handoff invocation captures and passes the source UUID; never relies on `--last`/`--continue` semantics that surprise across processes.
- **Tech: Go single binary.** Cobra/charm. Reasons: kubectl-shaped subcommand tree is unwieldy in zsh; JSON handling; structured testing. The hot path is Unix-socket JSON-RPC that must also run on Linux for the Docker acceptance lanes, where Go builds and cross-compiles with the least friction. Rust would work but buys nothing measurable; Swift's native macOS APIs would fight Foundation on Linux; Zig lacks the libraries.
- **cgo only for macOS APIs.** Accessibility (Zen's sidebars), the frontmost-application check, and the pasteboard call AppKit and ApplicationServices through cgo in a `darwin`-tagged package. Everything else is pure Go, so the Linux test binary builds with `CGO_ENABLED=0` and stubs those calls. SQLite uses the pure-Go `modernc.org/sqlite` for the same reason.
- **Naming: `orcactl` (long), `o` (alias).** kubectl convention. Subcommand shortcodes git-spice-style.
- **Lives in this repo under `src/orcactl/`.** It is its own Go module outside the chezmoi source root, in the directory for authored programs that each carry their own build manifest and tests. The shortcut callers, the Docker acceptance lanes, and the chezmoi install all change in the same commits as the code. A `run_onchange` script builds `~/.local/bin/orcactl` from source, as the Swift CLIs are built.
- **No MCP.** Pair with a thin `orcactl` skill so Claude/Codex know when to invoke which subcommand.

## Validation findings

These shaped the design and are documented here so future-us can re-derive choices.

### Claude Code session storage and cwd binding

- Sessions stored at `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl` (encoded path uses `s,/,-,g`, with symlink resolution).
- `claude --resume <uuid>`, `claude --continue`, and `claude --resume <uuid> --fork-session` are **hard-filtered** to the current cwd's encoded project dir. Resuming from any other directory fails with `No conversation found with session ID: <uuid>`.
- Once lookup succeeds, the resumed agent **binds cleanly to the new cwd** (CLAUDE.md, file tools, all retarget). The JSONL-embedded `cwd` field is not re-validated.
- No `--cwd` flag exists. The Agent SDK (`@anthropic-ai/claude-agent-sdk` v0.1.51+) added `listSessions({dir})` and `getSessionMessages({sessionId, dir})` but both also take a `dir` arg pointing at the same encoded path — they don't solve cross-cwd, just provide a cleaner read surface. No write/migrate API.
- Workaround: copy the JSONL into the destination's encoded project dir before invoking `claude --resume <uuid> --fork-session` from inside the new cwd.

### Codex session storage and cwd binding

- Sessions in SQLite at `~/.codex/state_5.sqlite`, table `threads(id, rollout_path, cwd, ...)` with cwd as a first-class column.
- `codex resume <uuid>` and `codex fork <uuid>` accept `-C/--cd <DIR>` to set the working directory for the new session, and `--all` to disable cwd filtering.
- Cross-directory resume/fork is first-class. No filesystem juggling needed.

### Orca runtime / persistence model

- PTY masters live in a separate **daemon** at `~/Library/Application Support/orca/daemon/daemon-v4.sock` (token auth, NDJSON envelope). Daemon is launched detached and reparented to launchd; survives Orca app quit/restart. This is why terminals come back when you restart Orca.
- Daemon RPC supports tmux-style attach: `createOrAttach(sessionId)` detaches existing clients and attaches a new one without touching the underlying child process.
- Daemon RPC methods: `createOrAttach, write, resize, kill, signal, detach, getCwd, clearScrollback, listSessions, getSnapshot, ping, shutdown`.
- **Public CLI surface does not expose `terminal.move` / `terminal.adopt` / attach/detach.** Renderer holds a 1:1 `sessionId ↔ visual pane` map in its own state.
- Verdict for layout transplant: feasible in principle, blocked by missing CLI surface. See [Stably issue draft](#stably-issue-draft-orca-terminal-move) below.

### Cross-tool landscape (cwd-aware resume)

| Tool | Cross-dir resume | How |
|---|---|---|
| Goose (Block) | yes | SQLite with `working_dir` column, `--fork` + `--name`/`--session-id` |
| Codex (OpenAI) | yes | `-C` + `--all` |
| GitHub Copilot CLI | yes | `--resume <id\|name>` not cwd-filtered |
| Cursor agent CLI | yes | chat-id keyed |
| Amp (Sourcegraph) | yes | Cloud-synced, server-side ID-keyed |
| Gemini CLI | partial | `--resume <id>` after `cd` to project; no `--cwd` |
| OpenCode | no | Project-scoped by git-root commit hash |
| Claude Code | no | Encoded-cwd dir lookup, no override |
| Aider | n/a | Chat history is reference text, not replayable session state |
| Cline / Roo | "too global" | All projects mixed in `globalStorage` |

Claude is the outlier. Anthropic issue tracking the gap: [anthropics/claude-code#58591](https://github.com/anthropics/claude-code/issues/58591).

## Naming and shape

```
orcactl <noun> <verb> [args]    # full form
o <noun> <verb> [args]          # alias
o <nv> [args]                   # combined shortcode (e.g. `o wf` = wt fork)
```

| Noun | Short | Purpose |
|---|---|---|
| `worktree` | `wt` | Create/list/jump/remove/comment, including fork/handoff/review variants |
| `session` | `ses`, `s` | Resume agent sessions, including the scrollback-scrape "resume what I just exited" |
| `terminal` | `term`, `t` | List, tail, grab output, send (non-agent only) |
| `pane` | `pane`, `p` | Layout changes — split, tab, transplant (some blocked on upstream) |
| `snapshot` | `snap` | Inspect/manage `refs/orcactl/snapshots/` from fork operations |
| `context` | `ctx`, `c` | Machine-readable "where am I in Orca" for external triggers |

## Command surface

### `wt` — worktree

| Command | Shortcode | Behavior |
|---|---|---|
| `wt new [name]` | `wn` | New worktree. `--from <ref>`, `--issue <n>`, `--agent claude\|codex\|none`, `--comment "..."`, `--cd` |
| `wt fork [name]` | `wf` | Fork current agent session into new worktree (preserves session). Detects agent via env. `--no-dirty`, `--move`, `--no-agent`, `--agent <override>` |
| `wt handoff [name]` | `wh` | Fresh agent session in new worktree, seeded with handoff summary. `--summary "<text>"`, `--agent <type>` |
| `wt review <pr>` | `wr` | Worktree at PR head, seeded with PR context. `--agent claude\|codex\|none` |
| `wt ls` | — | Pretty `orca worktree ps`, ★ marks current |
| `wt cd [query]` | `wcd` | fzf-pick + cd |
| `wt rm [name]` | — | Refuses dirty without `-f`, refuses if cwd is target |
| `wt comment "..."` | `wcm`, top-level `o cm` | Set active worktree comment (no arg = $EDITOR) |
| `wt show` | `ws` | Describe active worktree (json with `--json`) |
| `wt unfork <name>` | `wu` | Restore source's pre-fork dirty state from snapshot ref |

### `ses` — session

| Command | Shortcode | Behavior |
|---|---|---|
| `ses resume` | `sr` | Default: scrape active terminal scrollback for most recent `claude --resume <uuid>` / `codex resume <uuid>` line; auto-applies fork-context if present |
| `ses resume --pick` | — | fzf picker over claude project dir + codex sqlite |
| `ses resume --terminal <handle>` | — | Scrape from a sibling terminal's scrollback |
| `ses ls` | — | All sessions for current cwd, table form |
| `ses show <id>` | — | Print metadata + last N assistant messages (JSONL parse) |
| `ses reveal` | — | Copy the focused pane's session ID and open AgentsView at it. Bound to ⌥A and Tuna ⌘-tap O e |
| `ses fork` | — | Fork the focused pane's session with the agent's native fork, into a split beside that pane on its host. Bound to ⌥F and Tuna O f. `--dry-run` prints the plan. Cursor has no native fork and refuses |

### `term` — terminal helpers

| Command | Shortcode | Behavior |
|---|---|---|
| `term ls` | `tl` | List terminals in active worktree (or `--worktree all`) |
| `term tail [handle]` | `tt` | Pretty-print scrollback. fzf-pick if no handle. `--follow` polls until idle |
| `term grab [handle]` | `tg` | `--last-cmd` (output between last two prompt markers), `--last-agent` (last assistant message via JSONL). `--copy` to clipboard |
| `term send [handle] "..."` | `ts` | Sends text + Enter to a non-agent terminal. Errors if target is a recognized agent CLI; points at orchestration |
| `term wait [handle]` | `tw` | `terminal wait --for tui-idle/exit` with sane default timeout |

### `pane` — layout

| Command | Shortcode | Status | Behavior |
|---|---|---|---|
| `pane split [--h\|--v] [--cmd "..."]` | `psp` | v1 | `orca terminal split` — sugar over public RPC |
| `pane new` | `pn` | v1 | New tab |
| `pane to-tab [handle]` | `ptt` | **stub (blocked on upstream)** | Transplant pane to new tab |
| `pane to-split [handle] --direction h\|v` | `pts` | **stub (blocked on upstream)** | Transplant tab to split |
| `pane swap-direction` | `psw` | **stub (blocked on upstream)** | Flip sibling-split orientation |
| `pane join <handles...>` | `pj` | **stub (blocked on upstream)** | Multiple tabs → splits, tmux-style |

Stubs print: `pane <op>: blocked on upstream — orca terminal move not yet exposed. See https://github.com/<stably-orca-issue>` until the upstream RPC lands.

### `snap` — snapshot management

| Command | Shortcode | Behavior |
|---|---|---|
| `snap ls` | — | List `refs/orcactl/snapshots/` with metadata (when, src worktree, dest worktree, dirty file count) |
| `snap show <name>` | — | `git show` against the snapshot tree; diff against current source |
| `snap rm <name>` | — | Manual cleanup |
| `snap prune` | — | Auto-prune snapshots older than N days (default 30) |

### `ctx` — context for external tools

```
o ctx                         # human-readable
o ctx --json                  # machine-readable
o ctx --shell                 # eval-able env exports (ORCACTL_* vars)
o ctx --field active.session.id   # jq-style accessor for one-liners
```

JSON shape:

```json
{
  "orca": {"running": true, "runtime_id": "..."},
  "active": {
    "worktree": {"id": "...", "name": "...", "path": "...", "branch": "...", "comment": "...", "repo_slug": "owner/repo"},
    "terminal": {"handle": "...", "title": "...", "command": "claude", "agent": "claude", "session_id": "uuid-or-null", "tui_state": "working|idle|unknown"}
  },
  "worktrees": [...],
  "inbox": {"unread": 3}
}
```

`--shell` exported env vars (ORCACTL_ namespace, mirrors Orca's full naming convention):

```
ORCACTL_WORKTREE_ID            # repoId::path form
ORCACTL_WORKTREE_NAME
ORCACTL_WORKTREE_PATH
ORCACTL_WORKTREE_BRANCH
ORCACTL_WORKTREE_COMMENT
ORCACTL_REPO_ID
ORCACTL_REPO_SLUG              # owner/repo
ORCACTL_TERMINAL_HANDLE
ORCACTL_TERMINAL_TITLE
ORCACTL_TERMINAL_COMMAND
ORCACTL_AGENT                  # claude|codex|none
ORCACTL_AGENT_SESSION_ID
ORCACTL_AGENT_TUI_STATE        # working|idle|unknown
```

Coexists with Orca's own `ORCA_TERMINAL_HANDLE` and `ORCA_WORKTREE_PATH` (Orca-injected in some flows). Two namespaces, no collision; values should always agree (warn on mismatch — itself a useful diagnostic).

Phase 1 ships the `active` object only. `terminal.agent` and `terminal.host` come from Orca's detection and `terminal.session_id` from Orca's pane binding, all without a vault scan, so `ctx` stays a focus-read-sized call; `session_id` is null when Orca has no binding.

### Top-level shortcut commands

| Command | Behavior |
|---|---|
| `zen [--status]` | Toggle Zen: filter Orca to the current project and hide both sidebars, then restore the saved view on the next call. Bound to ⌥Z and Tuna O z |
| `agents` | List agents installed for the active runtime (`preflight.detectAgents`), for the Raycast worktree form's picker |

## Shortcut engine (phase 1)

Phase 1 replaces the scripts behind the Orca shortcuts with orcactl and keeps
their behavior. The reference implementation is
`home/dot_config/raycast/scripts/executable_orca-agent-session.py` and
`home/dot_local/bin/executable_orca-zen-mode` with its accessibility bridge
`home/dot_local/libexec/orca-zen-mode.js`. The [shortcut plan](orca-shortcuts-plan.md)
records why each rule exists; the [validation runbook](../runbooks/orca-shortcut-validation.md)
owns the Docker lanes.

### Behavior to keep

- **Focus is Orca's, captured first.** Pick the route from the active profile's
  saved focused workspace host (read-only SQLite), then `worktree.ps` and
  `session.tabs.list` over the runtime socket, before any child process. Every
  later call uses the captured pane handle. macOS focus matters only for the
  non-JSON frontmost gate.
- **Host checks.** `terminal.show` names the execution host; refuse a
  disconnected terminal, and check `ssh.getState` before probing an SSH pane.
- **Agent identity.** Orca's agent status must report a running agent. The
  foreground process names it (`cursor-agent` → cursor, a version name such as
  `2.1.308` → claude); generic processes fall back to Orca's agent type; a
  binding for a different agent is dropped.
- **Session lookup.** Local panes: the AI vault, filtered by the pane's bound ID
  or transcript, refusing ambiguity. SSH and paired panes: the binding alone,
  refusing when absent.
- **Fork.** Native fork commands only (claude, codex with its account home, pi
  and omp by transcript, droid), split from the captured handle. Cursor refuses.
- **JSON contract.** `ses reveal --json` and `ses fork --json` keep the helper's
  field names (`agent`, `sessionId`, `forkCommand`, `newTerminal`,
  `executionHostId`, `error`, and the rest), so the Docker scenarios switch
  entrypoints without rewriting assertions.
- **Zen.** The toggle state machine, per-profile restore file, lock, and every
  re-check between steps carry over unchanged.

### Command mapping

| Caller today | orcactl |
|---|---|
| `orca-agent-session` (Reveal, HUD) | `orcactl ses reveal` |
| `orca-agent-session --fork` | `orcactl ses fork` |
| `--json` / `--dry-run` / `--copy` | `--json` / `--dry-run` / `--copy` on either `ses` command |
| `--worktree <path>` | `--worktree <path>` on either `ses` command |
| `--json --agent-only` (`claude-queue-draft`) | `orcactl ctx --json`, reading `active.terminal.agent` |
| `--list-agents --json` (worktree form) | `orcactl agents --json` |
| `orca-zen-mode [--status]` | `orcactl zen [--status]` |

`o` and the `ctx` and `agents` shortcodes are out of scope for phase 1.

### Mechanism

```text
src/orcactl/
  cmd/orcactl/        Cobra commands: ses reveal|fork, ctx, agents, zen
  internal/runtime/   socket JSON-RPC client; paired route through Orca's packaged client
  internal/profile/   active profile and saved focused host (read-only SQLite)
  internal/focus/     route, workspace, focused pane, host checks
  internal/agent/     identity rules and native fork commands
  internal/session/   vault and bound-session lookup
  internal/zen/       toggle state machine
  internal/macos/     cgo: frontmost app, accessibility sidebars, pasteboard (darwin); stubs elsewhere
```

Paired servers keep using Orca's packaged runtime client because it carries the
pairing authentication and encryption; re-implementing that protocol is out of
scope. The adapter script moves to `internal/runtime/paired-adapter.cjs`, is
embedded in the binary, written once to the user cache directory, and run with
Orca's Electron in Node mode; the runtime package finds Electron from the Orca
CLI on `PATH`, as the helper did. orcactl reads one table of Orca's own
database, not storage it owns, so the sqlc rule in `home/dot_agents/docs/go.md`
does not apply; the single read-only query lives in `internal/profile`.

Go tests serve hand-written Orca responses, copied from observed runtime replies,
over a real Unix socket from a test server in each package's tests; SQLite
fixtures are built in the test from the same schema the helper's tests use.

Speed check: on the Mac, `hyperfine -N --warmup 3 'orcactl ctx --json'` stays
under 30 ms warm, and the Docker layout lane's in-process PID check passes.

### Prerequisites

Go from the repo's `mise.toml` (pinned 1.26.4), Xcode command-line tools for cgo
on the Mac (a darwin build without cgo fails to compile rather than silently
dropping AppKit), and an ARM64 Docker engine for the lanes.

### Open items

- Each paired-server RPC starts Orca's Electron in Node mode, as the Python
  helper did, so a paired workspace's focus read costs several process starts.
  One adapter run that serves the whole invocation would remove them.

### Deliverables

1. **Focus and context.** Module, Cobra skeleton, root `justfile` recipes
   (`orcactl-build`, `orcactl-test`), runtime client, profile reader, focus
   capture, agent identity, and `ctx --json`. Accept: `just orcactl-test` covers
   per-split focus, route selection from a SQLite fixture, host refusals, and
   the identity rules at the socket boundary; on the live Mac, `ctx --json`'s
   `active.terminal.agent` and `host` equal the helper's `--json` `agent` and
   `executionHostId` for the focused pane, and `session_id` equals Orca's pane
   binding. It is null where Orca has no binding, as on a Mac whose managed
   policy blocks Claude's hooks; Reveal and Fork then rely on the vault lookup.
2. **Reveal and Fork.** Session lookup, fork commands, split, AgentsView opening,
   pasteboard. The Docker runner gains `--entrypoint orcactl`, which builds a
   Linux binary with `CGO_ENABLED=0` and runs the scenarios against it. Accept:
   every guarantee in `tests/python/agents/test_orca_shortcuts.py` has a Go test;
   with `--entrypoint orcactl`, the `local`, `ssh`, and `paired` lanes pass on
   1.4.222 and the `layouts` and `paired` lanes pass on 1.4.224 (its SSH lane
   fails in Orca, per the runbook).
3. **Zen.** Port the toggle and its accessibility calls through cgo. Accept: Go
   tests with a fake accessibility interface cover every case in
   `tests/python/agents/test_orca_zen_mode.py`; on the Mac, `orcactl zen --status`
   matches `orca-zen-mode --status`; with a project selected in Orca, `orcactl zen`
   hides both sidebars and filters to that project, and a second call restores
   the previous sidebars and filter.
4. **Cutover.** A `run_onchange` chezmoi script builds `~/.local/bin/orcactl`
   from a digest of `src/orcactl/`. Every caller moves to orcactl and the reference
   scripts leave the tree:
   - Raycast script commands `executable_orca-agent-session.py` and
     `executable_orca-fork-agent-session.sh` become thin `exec`s of
     `~/.local/bin/orcactl ses reveal|fork`; `orca-agent-rpc.cjs` and
     `home/bin/symlink_orca-agent-session.tmpl` go.
   - Tuna O e, O f, O z; Karabiner ⌥Z; `bin/claude-queue-draft`; the worktree
     form's `orca.mjs`.
   - `home/dot_local/bin/executable_orca-zen-mode` and
     `home/dot_local/libexec/orca-zen-mode.js`, their `.chezmoiignore` gates, and
     the Python tests they own.
   - Config tests that pin these strings (`tests/python/packages/test_config_gates.py`,
     `tests/scenarios/config/karabiner.py`), the shortcut plan, the runbook, and
     `tests/README.md`.
   Accept: all lanes and config tests green with orcactl, `chezmoi apply --dry-run`
   clean, and on the Mac: ⌥F with focus moved to another tab within a second
   forks beside the original pane; ⌥A opens AgentsView at the focused session;
   ⌥Z and Tuna O z toggle Zen; Tuna O f from another app forks the last-focused
   Orca pane.

## Workflow walkthroughs

### 1. Resume a session you just exited

```sh
$ exit                        # claude/codex prints "Resume this session with: <cmd> <uuid>"
$ o sr                        # scrapes the line, re-runs in same terminal
```

Mechanism: read `orca terminal read --terminal <active>` (120-line buffer), regex `/(?:claude|codex)\s+(?:--resume|resume|fork)\s+([0-9a-f-]{36})/i`, last match wins. Fallback if buffer scrolled past: most-recent JSONL by mtime in cwd's project dir. Fixture suite for the regex captures the exact exit-hint text from each agent across versions.

### 2. Fork in-progress session into a new worktree

```sh
# inside claude:
! o wf debug-auth-thing

# from bare shell in worktree (no agent context):
$ o wf debug-auth-thing       # errors: no agent session detected. suggests `o wn` instead
```

Full flow detailed in [Dirty state design](#dirty-state-design) and [Per-agent fork flow](#per-agent-fork-flow).

### 3. Handoff to fresh session (different agent OK)

```sh
! o wh switch-to-codex --agent codex
```

Asks current claude for handoff summary via `claude -p`, creates worktree, spawns fresh codex session with the summary as first prompt. Distinct from fork: no JSONL surgery, no `--fork-session`.

### 4. Review a colleague's PR

```sh
$ o wr https://github.com/foo/bar/pull/4421
$ o wr foo/bar#4421
$ o wr 4421                   # if cwd is in matching repo
```

Parses spec → ensures clone via `ghc` (subshell, capture path) → `gh pr view` for metadata → `git fetch origin pull/<n>/head:review/pr-<n>` → `orca worktree create --branch review/pr-<n>` → writes `<wt>/.orcactl/review-context.md` (title, author, URL, body, `gh pr diff`) → spawns agent with that file as first prompt → comment `review: <title> by @<author>`.

### 5. Start exploration / experiment

```sh
$ o wn try-zstd                       # current repo, off origin/HEAD, no agent
$ o wn --issue 4567                   # title from gh issue
$ o wn try-thing --agent claude       # spawn claude in fresh worktree
$ o wn foo/bar try-it                 # different repo (clones if needed via ghc)
```

### 6. Read what a sibling pane just did

```sh
$ o tg --last-cmd                # fzf-pick a sibling pane, copy last command output to clipboard
$ o tg <handle> --last-agent     # last assistant message from agent terminal (JSONL-based, not TUI scrape)
$ o tt --follow                  # tail-follow until idle
```

`--last-agent` reads the session JSONL directly (path resolved via `orca terminal show <handle>` + cwd → encoded project dir → most recent jsonl). Much more reliable than regexing TUI rendering.

### 7. Layout changes

```sh
$ o psp --v --cmd "pnpm test --watch"   # works today
$ o pn                                   # new tab (works today)
$ o pt                                   # stub: blocked on upstream
$ o ts                                   # stub: blocked on upstream
$ o psw                                  # stub: blocked on upstream
```

### 8. External trigger (launcher shell command)

```sh
orcactl wt fork "$(orcactl ctx --field active.worktree.name)-debug"
```

`orcactl` works the same whether invoked from inside an Orca terminal or from outside — `ctx` always reflects what Orca itself considers the active worktree/terminal.

### 9. Daily drivers

```sh
$ o                              # one-line status: wt name | branch | comment | terms | working agents
$ o cm "fix found, running tests" # comment shortcut
$ o ls                            # wt list
$ o cd                            # fzf-jump
```

## Dirty state design

### Pre-flight refusal matrix

```
REFUSE if:
  - submodule with dirty working tree (no approach handles this safely)
  - sparse-checkout active in source or dest
  - partial-clone (promisor remote configured)
  - dest worktree is locked or detached unexpectedly
  - LFS pointers present without LFS configured equivalently in source/dest

WARN (proceed) if:
  - assume-unchanged / skip-worktree bits in use
  - smudge/clean filters configured (git-crypt, etc.) — same-repo round-trip is safe but worth noting
  - out-of-repo symlinks present (target may not exist)
  - filenames with combining-form Unicode (NFD vs NFC drift across volumes)

PROCEED:
  - everything else
```

### Transfer mechanism (locked)

Empirically validated across 15 scenarios; chose Approach A over stash-create-based and per-file-cp alternatives because A had 0 FAIL across all scenarios while preserving symlinks, exec bits, binary content, non-ASCII filenames, and `.gitignore` semantics.

```sh
# 1. Snapshot source for undo + verification target
SNAP=$(git -C "$SRC" stash create -u)
git update-ref refs/orcactl/snapshots/"$DEST_NAME" "$SNAP"
git update-ref refs/orcactl/snapshots/last "$SNAP"

# 2. Stage to <dest>.partial/ (sibling of the final dest path)
mkdir -p "$DEST.partial"

# 3. Two-pass apply preserves staged/unstaged split
git -C "$SRC" diff --cached HEAD --binary > /tmp/staged.patch
git -C "$SRC" diff             --binary > /tmp/unstaged.patch
git -C "$DEST.partial" apply --index --3way /tmp/staged.patch
git -C "$DEST.partial" apply         --3way /tmp/unstaged.patch

# 4. Untracked files (respects .gitignore by default)
(cd "$SRC" && git ls-files -o --exclude-standard -z) \
  | (cd "$SRC" && tar --null -cf - --files-from=-) \
  | tar -xf - -C "$DEST.partial"

# 5. Allowlisted ignored files (e.g. .env, .envrc — opt-in)
while IFS= read -r pattern; do
  (cd "$SRC" && git ls-files -o --ignored --exclude-standard -z -- "$pattern") \
    | (cd "$SRC" && tar --null -cf - --files-from=-) \
    | tar -xf - -C "$DEST.partial"
done < "$SRC/.orcactl/include.txt" 2>/dev/null
```

### Verification (mandatory, no `--skip-verify`)

The same `git stash create -u` primitive that didn't work as a transfer mechanism is the truth oracle for verification. Source and dest each create an unsaved stash; tree SHAs must match.

```sh
verify() {
  local repo=$1
  git -C "$repo" rev-parse HEAD                              # base SHA
  git -C "$repo" status --porcelain=v1 -z | sha256sum        # dirty path set
  git -C "$repo" -c gc.auto=0 stash create -u 2>/dev/null \
    | xargs -I{} git -C "$repo" rev-parse {}^{tree}          # content tree SHA (Merkle)
}
diff <(verify "$SRC") <(verify "$DEST.partial") || ABORT
```

Cost: ~2s on 10k-file repo with warm index. False-negative rate effectively zero (SHA collision-resistance). False-positive rate: zero for tracked content.

### Atomicity

Stage-then-publish: write to `<dest>.partial/`, verify, then `rename(2)` into final position (POSIX atomic within a filesystem). Snapshot ref persists regardless — the safety net.

WAL-style journal at `<dest>.partial/transfer.json` with `{src_path, src_head_sha, snap_sha, started_at}` for crash resumability and post-mortem inspection.

### Rollback

On verification failure: leave `<dest>.partial/` intact, surface the path in the error, journal the operation. Do **not** auto-wipe (destroys evidence). User runs `orcactl wt fork --discard-partial <name>` to clean up after inspection.

### Snapshot ref scheme

```
refs/orcactl/snapshots/<dest-name>     # named per fork
refs/orcactl/snapshots/last            # most recent
```

Enables:

- `o wu <name>` (`wt unfork`) — restore source's pre-fork dirty state via `git read-tree --reset -u <snap>^{tree}`
- `o snap ls` / `o snap show <name>` — inspect history
- `o snap rm <name>` / `o snap prune` — manual + auto cleanup
- GC-safe (real refs, never garbage-collected until pruned)

### `--move` mode (bidirectional fork)

```sh
o wf <name>            # default: duplicate (both sides dirty, safe)
o wf <name> --move     # transactional move: clear source after dest verifies
```

Move flow: snapshot → apply to dest → verify → if OK, `git -C "$SRC" reset --hard HEAD && git -C "$SRC" clean -fd` (excludes `.orcactl/` via local gitignore). Snapshot ref is the recovery path: `o wu <name>` restores. Refuses if verification fails.

### Materialization-aware policy

Default categorization:

| Category | Default | Override |
|---|---|---|
| Tracked-clean | n/a | — |
| Tracked-dirty | Transfer | `--no-dirty` |
| Untracked-not-ignored | Transfer | `--no-untracked` |
| Untracked-ignored | Skip | `<repo>/.orcactl/include.txt` allowlist |

`<repo>/.orcactl/include.txt` (per-repo) and `~/.config/orcactl/include.txt` (global default) take pathspecs. Lets users opt `.env`, `.envrc`, `.vscode/settings.json` in without surprise `node_modules/` transfers.

## Per-agent fork flow

After the worktree is created and dirty state is transferred and verified, the agent fork step.

### Claude

1. Read source session via Agent SDK (`@anthropic-ai/claude-agent-sdk`):

   ```js
   const sessions = await listSessions({ dir: srcPath });
   const messages = await getSessionMessages({ sessionId, dir: srcPath });
   ```

   Reasons to use the SDK over direct JSONL parse: format-change resilience; smaller diff when Anthropic ships `--cwd` upstream.
2. Write the JSONL into `~/.claude/projects/<encoded-dest-cwd>/<uuid>.jsonl`. Encoded path: `s,/,-,g`, with symlink resolution.
3. Generate `<dest>/.orcactl/fork-context.md` from the template below, with placeholders rendered.
4. Spawn agent in dest's Orca terminal:

   ```sh
   orca terminal create --worktree id:<dest> \
     --command "claude --resume <uuid> --fork-session --append-system-prompt \"\$(cat .orcactl/fork-context.md)\"" \
     --title "fork:<name>"
   orca terminal wait --for tui-idle --timeout-ms 60000
   ```

5. Comment dance: source `→ <new-name>`, dest `← forked from <source-name>`.

### Codex

1. `orca terminal create --worktree id:<dest> --command "codex fork <uuid> -C <dest-path> --all" --title "fork:<name>"`
2. Wait for tui-idle, set comments. Done. No JSONL surgery, no system-prompt seeding (codex handles cwd binding natively).

### `wt fork --no-agent` variant (both agents)

Skip the agent spawn. Print:

```
✓ Worktree forked.
  Source:  <source-path>          (session continues running)
  Dest:    <dest-path>             (you are here)
  Branch:  <dest-branch>           (independent)
  Session: <uuid>                  (copied to ~/.claude/projects/<encoded-dest>/  — claude only)
  Snapshot: refs/orcactl/snapshots/<name>

To resume the forked session here:
  $ o sr                          # auto-applies fork context
  # — or manually —
  $ <agent-resume-cmd>            # exact command per agent
```

`o sr` (`ses resume`) auto-detects `.orcactl/fork-context.md` in cwd and passes it as `--append-system-prompt` to claude (or as a first prompt seed for codex).

### Fork-context template

`<dest>/.orcactl/fork-context.md`:

```markdown
# Forked Claude session — path remap

This Claude Code conversation was forked from another git worktree by `orcactl wt fork`.
The conversation history above this point references files at the **original** worktree's
path. Those files exist at the equivalent paths under the **current** worktree.

| | Path |
|---|---|
| Original worktree | `{{ .source.path }}` |
| Current worktree  | `{{ .dest.path }}` (you are here) |

Treat any absolute path beginning with `{{ .source.path }}/` as if it were
`{{ .dest.path }}/` — same content, different location. Use the current
worktree's path for all subsequent file operations.

## Git state at fork

- Base SHA: `{{ .base_sha }}`
- Branch: `{{ .dest.branch }}` (new, independent of `{{ .source.branch }}`)
- Uncommitted changes from the original worktree were transferred and verified
  byte-for-byte. ({{ .verify.tracked_files }} tracked + {{ .verify.untracked_files }} untracked)

The original session continues running in `{{ .source.path }}`. Changes you make
here will not affect it.

## Continue

Pick up from where the conversation left off, but anchor any file work in the
current worktree.
```

Rendered output is what gets passed as `--append-system-prompt` (system addendum, not a user turn).

## Anthropic issue

Filed: [anthropics/claude-code#58591](https://github.com/anthropics/claude-code/issues/58591). Tracks the request for `claude --resume <uuid> --cwd <dir>` (or SDK `migrateSession({sessionId, fromDir, toDir})`) so we can drop the JSONL-copy workaround.

Watch upstream: anthropics/claude-code #36937, #28745, #41021, #5768, #49954.

## Stably issue draft (orca terminal move)

Filing under whatever Stably's public issue tracker is. Title: `terminal move: expose tmux-style pane/tab transplant via public CLI`.

> ## Summary
>
> Orca's daemon already supports tmux-style attach/detach: `TerminalHost.createOrAttach(sessionId)` in `daemon-entry.js` will detach existing clients and attach a new one without touching the underlying child process. This is exactly the primitive needed to reparent a running terminal (claude, codex, vim, REPL) from one pane/tab/window to another.
>
> The public CLI surface does not expose this. The renderer holds a 1:1 `sessionId ↔ visual pane` map and there is no `terminal.move` / `terminal.adopt` / `terminal.attach` in the public RPC.
>
> ## Use cases
>
> - Convert a vertical split into a horizontal split without restarting the running process
> - Pull a terminal from a tab into a split of the current pane (or the inverse)
> - Combine multiple tabs into splits of a single tab, tmux-style
> - Reparent a terminal across windows
>
> All of these are common in tmux-based workflows; for users coming from tmux, the absence is felt immediately.
>
> ## Proposed API
>
> ```
> orca terminal move --terminal <handle> \
>     --target tab \
>     [--worktree <selector>] \
>     [--title <text>] \
>     [--json]
>
> orca terminal move --terminal <handle> \
>     --target split \
>     --direction <horizontal|vertical> \
>     [--relative-to <handle>] \
>     [--json]
>
> orca terminal move --terminal <handle> \
>     --target window \
>     [--json]
> ```
>
> Implementation sketch (renderer-side): tear down source pane's stream, create destination pane, have new pane call `createOrAttach(sessionId)` against the daemon. The daemon will detach the old client and stream to the new one with no process restart. Same RPC the renderer already uses on app reattach.
>
> ## Why CLI-first instead of just UI affordances
>
> Coming from `tmux move-pane`, the muscle memory is keyboard-and-CLI driven. Exposing this on the CLI also unblocks third-party tooling (e.g. orcactl) from building layout commands that the user can bind to global hotkeys or compose into multi-step scripts.
>
> ## Security
>
> Same surface as existing `orca terminal *` commands — public socket with the existing auth model.
>
> ## Context
>
> Building [`orcactl`](https://github.com/.../orcactl), a kubectl-shaped CLI for Orca. Layout-transplant commands (`pane to-tab`, `pane to-split`, `pane swap-direction`, `pane join`) are stubbed out today with a "blocked on upstream" message because the daemon clearly supports the operation but the public CLI doesn't surface it. Happy to contribute a PR if there's interest in the API shape above.
>
> ## Files referenced
>
> - `out/main/daemon-entry.js` — `TerminalHost.createOrAttach`, `Session.attachClient/detachAllClients`
> - `out/cli/handlers/terminal.js` — current public terminal commands
> - `~/Library/Application Support/orca/daemon/daemon-v4.sock` — daemon socket

## Open questions / future work

1. **Two-pass apply default**: lock to two-pass (preserves staged/unstaged split exactly, costs nothing meaningful). Confirmed.
2. **Snapshot prune horizon**: default 30 days. Configurable via `~/.config/orcactl/config.toml`.
3. **`include.txt` defaults**: ship a sane global default (`.env`, `.envrc`, `.vscode/settings.json`, `.idea/workspace.xml`)? Or empty default and require explicit opt-in per repo? Default: empty global, document common patterns in README.
4. **Symlink behavior across volumes**: warn on out-of-repo symlinks at fork time. Don't try to resolve.
5. **Claude SDK availability**: confirm `@anthropic-ai/claude-agent-sdk` v0.1.51+ is reachable from a Go binary. Likely path: shell out to a tiny node wrapper (`orcactl-claude-sdk-helper`) that chezmoi installs beside the binary. Avoid full Node embedding.
6. **Codex resume-hint exact wording**: capture during fixture work. Build a small `internal/scrape/fixtures/*.txt` directory with one fixture per (agent × known-version) pair, regex tests against all of them.
7. **`o ctx` performance**: phase 1 holds `ctx --json` under 30 ms warm (see [Shortcut engine](#shortcut-engine-phase-1)); the full `ctx` adds worktree and inbox reads, so cache them for one invocation if it grows past that.
8. **Skill complement**: thin `orcactl` skill for Claude/Codex teaching when to invoke which subcommand. Phase 8.
9. **PR review default agent**: claude or codex? Default claude for now. Configurable.

## Implementation order

Phased so each phase is self-contained and dogfoodable:

**Phase 1 — shortcut engine and cutover**

The four deliverables in [Shortcut engine](#shortcut-engine-phase-1), in order.
Deliverable 1 also bootstraps the module, the Cobra skeleton, and the root
`justfile` recipes that build and test it.

**Phase 2 — read-only surface**

- `orcactl status` — wraps `orca status --json`, friendly output
- `o` (bare) — one-line status
- `ctx` — the rest of the machine-readable and shell-export forms
- `wt ls` — pretty `worktree ps` table
- `wt show` — describe active worktree
- `term ls` — list terminals

**Phase 3 — worktree lifecycle**

- `wt new` — basic create + comment + agent spawn
- `wt cd` — fzf jump
- `wt rm` — safe delete
- `wt comment` — quick set
- `snap ls` (degenerate, since no forks yet)

**Phase 4 — load-bearing fork**

- Pre-flight refusal matrix
- Snapshot ref creation
- Two-pass diff+apply transfer
- Untracked + allowlisted-ignored tar passes
- Verification (stash-create tree SHA equivalence)
- Stage-then-publish atomicity
- WAL journal
- `wt fork` (--no-agent variant first; --agent variants after)
- Codex agent fork (simpler — `codex fork -C`)
- Claude agent fork (JSONL copy via SDK helper, fork-context.md generation, --append-system-prompt)
- `wt unfork`

**Phase 5 — handoff and review**

- `wt handoff` (asks current agent for summary via `claude -p` / `codex exec`)
- `wt review <pr>` (gh integration, ghc clone, PR context file, agent spawn)

**Phase 6 — session and terminal helpers**

- `ses resume` (scrollback scrape, fixture suite for exit-hint regex)
- `ses ls`, `ses show`
- `term tail`, `term grab` (--last-cmd, --last-agent)
- `term send` (with agent-detection guard)
- `term wait`

**Phase 7 — pane (what's possible today)**

- `pane split`, `pane new` (existing public RPC)
- Stub the others with the upstream-blocked message + Stably issue link

**Phase 8 — polish and distribution**

- Skill complement (thin `orcactl` skill)
- Snapshot auto-prune
- `o ctx` caching
- Shell completions (zsh, fish)
- Own repo and Homebrew tap, when something outside these dotfiles needs to install it

**Out of band**

- File Anthropic issue
- File Stably issue

## References

- Orca CLI skill: `utils-agent:orca-cli`, which loads the guide from `orca skills get orca-cli`
- Orca orchestration skill: `utils-agent:orca-stration`
- Worktrees doc: `home/dot_agents/docs/worktrees.md` (worktrunk-based, predates Orca)
- Anthropic issue (filed): https://github.com/anthropics/claude-code/issues/58591
- Document lifecycle: `../document-lifecycle.md`

## Progress

- 2026-10-22: Prateek chose Go, with cgo for the macOS APIs, and building in this repo instead of a separate one; this replaces the earlier separate-repo and Homebrew decisions. He approved phase 1 replacing the shortcut scripts wholesale. The Python helper landed its focus-capture and native-Claude fixes in `980f04b3` as the reference behavior.
