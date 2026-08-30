---
status: active
doc_type: plan
owner: Prateek
created: 2026-08-28
updated: 2026-08-28
related:
  - ../../home/dot_agents/docs/acpx.md
  - ../adr/0016-vendor-into-skill-references.md
status_detail: "PoC executed 2026-08-28: helper landed and review-hardened, five scenarios evidenced end to end (steering mechanism validated, live demo pending), go recommended."
---

# acpx Claude Code Streaming PoC Plan

Make an acpx run watchable from inside a Claude Code session. Today the
canonical invocation ([acpx conventions](../../home/dot_agents/docs/acpx.md))
launches acpx as a background shell with stdout redirected to a `/tmp` log:
the human sees a silent `/tasks` row and learns nothing until the agent
volunteers a summary. This PoC proves a blocking-poll relay loop that puts
live progress in the conversation itself, with no new harness features and no
shell commands for the human.

## Background

Investigated 2026-08-28 on the work machine (Claude Code 2.1.251, Vertex):

- Claude Code ships a purpose-built **Monitor tool** (each stdout line wakes
  the agent as an event). It is present in the 2.1.251 binary but its
  `isEnabled()` gate fails on third-party providers; this machine routes via
  Vertex (`CLAUDE_CODE_USE_VERTEX`), and probes confirmed Monitor is filtered
  from fresh sessions while control tools pass through. Plugin-declared
  monitors inherit the same gate. Docs show no Vertex roadmap for it.
- No other Claude Code surface is live, event-driven, and user-visible on
  Vertex. Background tasks give exactly one push: the completion
  notification. Foreground Bash output renders to the model, not reliably to
  the user. MCP progress notifications are not rendered.
- Codex CLI achieves a workable UX with none of that: its unified exec
  backgrounds long commands into PTY sessions and the model holds liveness
  with long blocking polls (`write_stdin` with empty input) that early-return
  when output arrives or the process exits. The pattern is reproducible in
  Claude Code with a small helper script, and Claude Code adds two things
  codex lacks: a completion push notification, and progress narration landing
  in the conversation transcript instead of a 3-line `/ps` tail.

## Goal

A human watching the Claude Code conversation can follow an acpx run end to
end — launch, mid-run progress, final answer, and failures — without running
shell commands or prompting the agent for status.

Non-goals for the PoC run itself: the Monitor-first convention for
first-party machines, per-harness conventions for cursor-agent/codex/pi, an
`acpx-runner` subagent flavor, and the helper's durable install location.
Several have since been delivered; "Follow-ups on go" below tracks their
current status.

## Design

### `poll-stream` helper

The one new artifact: `home/dot_agents/bin/executable_poll-stream` (chezmoi
target `~/.agents/bin/poll-stream`), a small shell script that turns "wait
for log growth" into a single blocking tool call.

```text
poll-stream <log> <state-file> [max-wait-s] [max-bytes]
```

- Reads a byte offset from `<state-file>` (0 if absent). Blocks until
  `<log>` grows past it, then prints the new bytes (capped at `max-bytes`,
  default 8192), writes the new offset, and exits 0.
- Exits 4 with empty stdout when `max-wait-s` (default 240) elapses without
  growth.
- Checks size once per second. No writer-liveness tracking: detecting a dead
  acpx is the harness's job via the background-task completion notification,
  which keeps the helper dumb and reusable for any append-only stream.
- macOS `/bin/bash`-compatible, shellcheck-clean (CI discovers shellcheck
  targets by shebang since master's #12 fix; the helper's bash shebang
  enrolls it automatically).

The 240s default keeps each poll under the Bash tool timeout and inside the
5-minute prompt-cache window, so a poll that returns near its deadline still
rides warm cache.

### Loop protocol

The acpx conventions doc carries the maintained version of this recipe;
this section records the PoC protocol.

The launch is unchanged from the current conventions (prompt file,
`--format text --suppress-reads --no-terminal --non-interactive-permissions
deny --timeout 600 --prompt-retries 2`, stdout redirected to `$log`), still
run as a background shell. The new part is what the agent does next:

```text
acpx (bg):   |--chunk----chunk----------chunk----[done]--|
                 v          v               v        v
agent loop:  poll-stream  poll-stream   poll-stream  poll-stream
             (returns on growth; narrates chunk; repeats)
human:       reads the narration in the conversation as it lands
```

1. Call `poll-stream "$log" "$log.offset" 240` in the foreground with the
   Bash tool timeout set to 270s (must exceed `max-wait-s`).
2. Narrate each returned chunk: summarize `[thinking]`/`[tool]` lines, quote
   assistant text.
3. Repeat until the log tail shows the `[done] <stopReason>` marker (the
   8 KB cap can split it across chunks, so check the tail rather than the
   chunk), the completion notification arrives (then drain with a short
   max-wait until a poll returns empty — the writer is gone), or acpx's
   own `--timeout` budget is spent.
4. Steering: the human can interject mid-loop. Enter steers the running
   turn, and plain Ctrl+X Enter also delivers mid-turn; only a queued
   slash command such as `/q` holds to true turn end (live-tested on
   2.1.251). "Cancel it" means stopping the background task — `exec`
   one-shots are temporary sessions, so `acpx cancel` does not apply.

Properties inherited from the codex pattern and its Claude Code deltas:

- Zero busy-polling: the wait happens inside the tool call, and a silent
  4-minute stretch costs exactly one round trip.
- Early return on output makes relay latency roughly the 1s check interval
  plus one model round trip.
- The completion notification is a backstop wakeup even if the agent stops
  polling — codex has no equivalent.
- Known cost, accepted for the PoC: the loop holds the main agent's turn
  open for the duration of the run. The subagent flavor that frees the turn
  is follow-up work, not PoC scope.

## Validation scenarios

All on this machine, using the `agpt` shortcut with read-only prompts.

| # | Scenario | Pass criteria |
| --- | --- | --- |
| 1 | Happy path: multi-minute prompt that emits several chunks | Every chunk narrated; relay lag ≤ ~10s beyond chunk arrival; `[done]` detected; final answer relayed verbatim |
| 2 | Quiet stream: long thinking gap | One outstanding poll per silent window; no empty-chatter narration |
| 3 | Completion race: stop polling, let the run finish | Notification wakes the agent; final drain loses no output |
| 4 | Failure: kill the acpx process mid-run | Abnormal end surfaced within one poll window |
| 5 | Steering: ask to cancel mid-run | Background task stopped within one round trip; state reported |
| 6 | Cost: ~5-minute run accounting | Poll round trips roughly proportional to chunk count (not elapsed time); transcript stays readable |

## Results (2026-08-28)

Executed the same day via a 9-agent workflow (implement, three-lens
adversarial review with 7 confirmed findings fixed, suite plus an independent
edge harness plus one live run) and in-session demos in the authoring Claude
Code conversation, all validations under a real PTY (`script -q /dev/null`).

Helper: all 8 independent edge probes pass plain and under a PTY — immediate
return under 0.1s, wakeup within ~1.1s of growth, byte-identical reassembly
at 40KB and 1MB (`cmp`), CR-heavy PTY streams intact, killed-writer timeout
clean. `make test-acpx-poll-stream` passed 3x identical plus a PTY run;
shellcheck clean; wired into the Makefile, `tests/README.md`, and CI (the
suite runs in the macOS job; shellcheck enrolls via shebang discovery).

| # | Scenario | Evidence |
| --- | --- | --- |
| 1 | Happy path | Workflow agpt run: 7 polls / 7 chunks, median relay lag 0.589s (max 0.928s), relay byte-identical to the log, `[done]` detected. In-session agpt run: 4 polls / 4 chunks, in order, final answer relayed. |
| 2 | Quiet stream | Real 18s composition gap on an afable run cost one blocked poll, zero churn. A full 240s silent poll returned rc=4, empty, in one round trip at 247s elapsed inside a 270s tool timeout — the timeout-interplay risk is retired. (247s was measured pre-hardening; the helper now holds a wall-clock deadline within +1s of clock-tick granularity.) |
| 3 | Completion race | Unwatched completions pushed a notification within ~2s, including one that arrived mid-blocked-poll. A never-polled run drained losslessly in a single call, `[done]` included. |
| 4 | Kill mid-run | SIGTERM mid-composition froze the log with a graceful `[done] cancelled` marker (acpx sends ACP session/cancel on SIGTERM), distinguishable from `[done] end_turn`. Startup failures surface as `[error] RUNTIME: ...` plus a failed-task notification. No claude-agent-acp orphans. |
| 5 | Steering | Mechanism validated, live demo pending: cancel means stopping the background task, and the `[done] cancelled` marker gives the loop its state report. Needs one interactive run with a human steering mid-stream. |
| 6 | Cost | Polls tracked chunk count, not elapsed time (7/7, 4/4, 6/6 across runs); a 4-minute silence cost exactly one round trip; chunks cap at 8KB with `--suppress-reads` keeping payloads small. |

Operational findings for the conventions rewrite:

- Terminal markers the relay loop must branch on: `[done] end_turn`
  (natural), `[done] cancelled` (killed or cancelled), `[error] RUNTIME: ...`
  (startup failure).
- Never kill cursor-agent's `worker-server` process: it is a persistent auth
  broker, and killing it breaks every subsequent cursor-agent run with
  `RUNTIME: Authentication required` until an interactive `cursor-agent
  login`. This cost the agpt shortcuts mid-PoC; afable demos were unaffected.
- The original `dd bs=1` read path drained 1MB in ~8s; a post-review
  cleanup replaced it with `tail -c +N | head -c` — same contract,
  byte-identical drains, roughly 100x faster on large residues.

Post-review hardening (2026-08-28): a no-context adversarial review of the
full diff (gpt-5.6-sol-xhigh via `acpx agptx`, relayed live through the
helper itself) returned 2 high / 5 medium / 3 low findings. Fixed: stat
failures on an existing log no longer masquerade as size 0; the wait is a
wall-clock deadline instead of iteration counting; the offset advances by
bytes actually read, not the earlier stat; CI now runs the regression suite
(it previously only shellchecked the helper); a hard-I/O test case landed;
the relay recipe detects completion from the log tail (the 8 KB cap can
split a `[done]` marker across chunks) and captures chunks to a file.
(The later `tail|head` read path changed broken-pipe behavior: a gone
reader yields a silent exit 141, and a partial reader can exit 0 with
bytes dropped — the capture-to-a-file rule is the guard, not a nicety.) Accepted, not fixed: no cross-caller
locking (one caller per state file, now documented in the header) and no
atomicity test for the tmp+mv state write.

Go/no-go: **go**. Proceed with the follow-ups below.

## Deliverables

All delivered 2026-08-28 — see Results:

- The `poll-stream` helper plus a focused test under `tests/` (background
  writer process appending to a file; assert chunk delivery, offset
  advancement, timeout exit code, and `max-bytes` capping). Follow
  [tests/README.md](../../tests/README.md) conventions.
- A results section appended to this plan: scenario outcomes, measured relay
  lag, and poll/token cost for the happy path.
- Go/no-go recommendation for productizing.

## Follow-ups on go

- Repackage the conventions as a trigger-owning local skill with the
  upstream acpx skill vendored into its `references/` — design in
  [ADR 0016](../adr/0016-vendor-into-skill-references.md) (proposed,
  awaiting review). On acceptance, `home/dot_agents/docs/acpx.md` is
  deleted in favor of the rendered skill.

- Done 2026-08-28: "Watching a run" in the
  [acpx conventions](../../home/dot_agents/docs/acpx.md) now has per-harness
  lanes — Claude Code relay loop with a Monitor-first note for first-party
  machines, codex unified exec, cursor-agent background jobs + `Await`, pi
  native tail. The `pi-acp` registry claim lives in the upstream acpx skill
  (openclaw/acpx), so the community-adapter correction (`svkozak/pi-acp`)
  belongs upstream, not in the vendored copy.
- Done 2026-08-28: the helper's durable install location (see Design).
- Optional flavors: `acpx-runner` subagent for turn-free long runs,
  TodoWrite phase mirroring.

## Risks

- **Timeout interplay.** If the Bash tool timeout is set at or below
  `max-wait-s`, the harness kills the poll mid-block. Harmless (re-poll
  resumes from the saved offset) but noisy; the recipe pins 270s over 240s.
- **Model discipline.** The loop is convention, not code — the agent can
  wander mid-loop or over-narrate. Mitigated by a tight recipe in the
  conventions doc; if PoC shows drift, that argues for the subagent flavor.
- **Context growth on chatty runs.** Bounded by `--suppress-reads`, the
  `max-bytes` cap, and the summarize-don't-quote narration rule; scenario 6
  measures it.
- **Portability.** `stat -f%z` is macOS-only. Fine for this repo; note the
  Linux variant if the helper ever leaves darwin.
