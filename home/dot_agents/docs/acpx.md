# acpx Conventions

## Purpose

Run another coding agent from inside a session via `acpx`, a headless ACP
(Agent Client Protocol) CLI: a second opinion from a different model, a
delegated one-shot task, or a scripted multi-agent step. The spawned
agent is a separate process with its own context — not a way to switch
your own model. The full command surface lives in the vendored `acpx`
skill (utils-agent); this doc covers local conventions only.

## Canonical invocations

Default — watchable run. Write the prompt to a file and pick the launch
shape for your harness — see Watching a run. The redirected shape shown
here is Claude Code's:

```bash
slug=review-auth   # short task label
cat > "/tmp/acpx-$slug.prompt.md" <<'EOF'
<the prompt>
EOF
log=$(mktemp "/tmp/acpx-$slug.XXXXXX")   # mktemp: concurrent runs get unique logs
echo "log: $log"   # echo BEFORE launching: the relay needs the path mid-run
acpx --format text --suppress-reads --no-terminal \
  --non-interactive-permissions deny --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md" > "$log" 2>&1
```

The shortcut (`agpt` here) selects the model — never pass `--model`; the
shortcut's config entry pins it. Keep `--format text` explicit (a project
`.acpxrc.json` could otherwise change it) and `--prompt-retries` for
transient adapter errors.

The run is finished when the log ends with `[done] <stopReason>`; the
final answer is the assistant text just before it. Branch on the marker:
`[done] end_turn` is a natural finish; `[done] cancelled` means cancelled
or killed (acpx sends ACP `session/cancel` on SIGTERM). An `[error]` line
is terminal only when the log ends with it (e.g. `RUNTIME: Authentication
required` at startup); mid-stream `[error]` lines are recoverable adapter
noise — narrate them and keep polling. A log that freezes with no marker
at all (SIGKILL, crash) ends only via the harness completion
notification. The log is also the forensic trail — a quiet `exec` leaves
none.

Fall back to a quiet foreground run only for quick, low-stakes prompts
where nobody needs progress (distinct from the direct-shape foreground
runs in Watching a run). Keep the safety flags; foreground runs race the
harness's own command timeout, often 2 minutes:

```bash
acpx --format quiet --no-terminal --non-interactive-permissions deny \
  --timeout 300 agpt exec 'quick question'
# machine-readable for scripts:
acpx --format json --json-strict --no-terminal \
  --non-interactive-permissions deny --timeout 300 agpt exec -f prompt.md
```

Rules that trip agents up:

- Shortcut names (`agpt`, `aopus`, ...) are acpx agent names, not
  binaries. Always `acpx <name>`; `which agpt` finds nothing.
- Global flags go before `<name>`; only `-f/--file` goes after `exec`
  (`-f -` reads stdin, e.g. a heredoc).
- Pair acpx `--timeout` with the harness's own command timeout. The
  default 2-minute tool-shell timeout kills acpx mid-run; background
  long runs instead.
- The permission flags above fail closed in tool shells: writes are
  denied instead of prompting. For a hard read-only guarantee use
  `--permission-policy` (skill: Permission modes). `--approve-all` is
  for trusted automation only.

## Model shortcuts

Defined in `~/.acpx/config.json` (`agents` map). Each pins a model + reasoning
tier. The `agpt*`/`aopus*`/`agemini` shortcuts run through `cursor-agent` as
the ACP adapter, with the reasoning tier encoded in the model id itself; where
`cursor-agent` is absent, `agpt*` fall back to the Codex adapter (`codex-acp`,
GPT model from `~/.codex/config.toml`). The `afable*` shortcuts run Claude Code
through `claude-agent-acp`, with the model and effort pinned via
`ANTHROPIC_MODEL` and `CLAUDE_CODE_EFFORT_LEVEL` env vars in the entry (the
adapter takes no model/effort CLI args).

| Shortcut  | Model                                 | Use for                            |
| --------- | ------------------------------------- | ---------------------------------- |
| `agpt`    | `gpt-5.6-sol-high-fast`               | Best general GPT, high reasoning   |
| `agptx`   | `gpt-5.6-sol-xhigh-fast`              | GPT for the hardest problems       |
| `aopus`   | `claude-opus-5-thinking-xhigh-fast`   | Best Claude, xhigh thinking, 1M ctx |
| `aopusx`  | `claude-opus-5-thinking-max-fast`     | Claude at max thinking, 1M ctx     |
| `afable`  | `fable` at `xhigh` effort             | Claude Code on Fable, xhigh effort |
| `afablex` | `fable` at `max` effort               | Claude Code on Fable, max effort   |
| `agemini` | `gemini-3.1-pro`                      | Best Gemini                        |

The `cursor-agent` ids pin the current latest of each family and go stale
as the catalog moves; the bare aliases (`opus`, `gpt`, ...) resolve to
*older* generations, so they are no escape hatch. The drift audit
(`scripts/audit/acpx-model-drift.sh` in the dotfiles repo) flags dropped
or superseded pins; refresh `home/dot_acpx/config.json.tmpl` and this
table together.

The config is templated per machine (machines.toml `agent_clis`), so the
rendered shortcut set varies by box; run `acpx config show` to see what
this machine actually has.

## Watching a run

`--format text` already streams: assistant text as it arrives plus
`[thinking]` and `[tool]`/`[plan]` status lines. Thinking is truncated in
text mode; use `--format json` when full reasoning matters.

Two launch shapes, chosen by which surface needs the stream: Claude Code
redirects to `$log` and relays from it; Codex, cursor-agent, and pi drop
the `log=`, `echo`, and redirect lines — the prompt file plus the acpx
command is their whole launch — because their native surfaces are the
feed, and with the redirect they would watch a silent command.
Direct-shape runs leave no log file; when the forensic trail matters,
redirect and tail.

| Who runs it        | Launch with                   | Follow progress via                 |
| ------------------ | ----------------------------- | ----------------------------------- |
| Claude Code        | `run_in_background`, redirect | blocking-poll relay (below)         |
| Codex              | direct foreground, no redirect | auto-backgrounded terminal (below) |
| cursor-agent       | background job, no redirect   | jobs pager + `Await` (below)        |
| pi                 | direct foreground, no redirect | native live tail (below)           |
| Human (spectating) | —                             | `tail -f` `$log` (redirected shape) |

For the redirected shape outside Claude Code, use `nohup … &` (bare `&`
is reaped by cursor-agent's tool shell). The invoking agent relays
progress by default; spectating is opt-in.

### Claude Code: blocking-poll relay

Turn each wait into one blocking call with `~/.agents/bin/poll-stream`
(source: `home/dot_agents/bin/` in the dotfiles repo):

```bash
~/.agents/bin/poll-stream "$log" "$log.offset" 240 8192 > /tmp/chunk  # blocks; exit 4 = quiet window
```

```bash
tail -c 64 "$log"   # separate call: ends with "[done] <stopReason>" once over
```

1. Launch with the canonical backgrounded block above, then read the
   `log:` line from the background task's output before the first poll.
2. Poll in the foreground with the tool timeout above max-wait-s — 270s
   over the default 240s (the helper holds max-wait-s plus up to 1s of
   clock-tick granularity). Each call blocks until the log grows, prints
   the new bytes (8 KB cap), and advances the offset; exit 4 is a quiet
   window — just call again.
3. Redirect the chunk to a file (as in the block above), never through a
   pipe: an early-exiting reader like `head` yields a silent exit 141 at
   best, and a partial reader can exit 0 with bytes dropped and the
   offset advanced. The file capture is load-bearing.
4. Narrate each chunk. Run the `tail` check as its own call, not chained
   after the poll (chaining masks exit 4 and re-prints consumed bytes).
5. Stop only when the final log line starts with `[done] ` AND a
   short-wait drain (`poll-stream "$log" "$log.offset" 5`) returns
   empty. Both halves matter: the 8 KB cap can split the marker across
   chunks, quoted marker text can appear mid-stream, and the tail can
   show a marker whose preceding bytes you have not consumed yet.
6. The harness completion notification is the backstop for a dead,
   markerless, or forgotten run: when it arrives, drain with short waits
   and report whatever the tail shows.
7. Cancelling: stop the background task, or kill scoped to this run only
   (`pkill -f "acpx-$slug"`) — never a broad pattern (see the
   worker-server warning in Prerequisites). A cancelled run ends
   `[done] cancelled`. `exec` one-shots cannot be steered mid-flight;
   when follow-ups are likely, use a named session instead.

A four-minute silence costs one round trip and stays inside the
five-minute prompt-cache window; polls scale with output, not elapsed
time.

On first-party API machines, prefer the native Monitor tool when present
(per-line event wakeups); it is provider-gated off Bedrock/Vertex/Foundry,
so probe ToolSearch for `Monitor`. This loop is the fallback.

### Codex: auto-backgrounded terminal

Run acpx directly as a plain foreground command. Unified exec yields
after at most ~30s and converts the run into a background terminal
instead of killing it. Hold liveness with long empty `write_stdin` polls
— they block up to `background_terminal_max_timeout` (default 300s) and
early-return on output or exit. The human follows via the footer terminal
counter and `/ps` (command plus last 3 output lines); mirror acpx phases
into `update_plan` for a visible task row. Nothing wakes the model
between calls, so keep a poll outstanding until `[done]`.

### cursor-agent: background job + Await

Run acpx as a background shell command (or let the timeout
auto-background it). The human gets the Tasks pager (`/jobs` slash
entry): a live log view per job and `k` to abort. The agent is woken with
a new turn when the job completes, and the `Await` tool's `regex`
argument blocks on stream milestones such as `\[done\]` or `\[error\]`;
output-notification patterns give mid-run wakeups without polling.

### pi: native live tail

pi's bash tool already streams live — a rolling tail with an elapsed
counter, expandable in the TUI, no default timeout, and full output saved
to a temp file on truncation — so a plain foreground run is watchable
as-is. A custom extension tool with `onUpdate` streaming is the richer
lane if pi becomes a daily acpx driver.

The Codex, cursor-agent, and pi lanes are built from version-pinned
capability research (see the validation checklist) but have not yet been
driven end to end; the redirected `nohup` shape is the proven fallback in
all three.

Persistent sessions (not `exec`) also append the raw ACP wire log to
`~/.acpx/sessions/<recordId>.stream.ndjson` regardless of `--format`, so
you can spectate a session another process started. Find the record id
with `acpx <agent> sessions show` (or `sessions list --local`), then:

```bash
tail -f ~/.acpx/sessions/<recordId>.stream.ndjson | jq -j '
  select(.method=="session/update") | .params.update |
  if .sessionUpdate=="agent_thought_chunk" then "\u001b[2m"+(.content.text//empty)+"\u001b[0m"
  elif .sessionUpdate=="agent_message_chunk" then (.content.text//empty)
  elif .sessionUpdate=="tool_call" then "\n[tool] "+(.title//"")+"\n"
  else empty end'
```

Wire logs keep full prompts, reasoning, and tool output — treat them as
sensitive; `sessions close` then `sessions prune --include-history`
removes them. `exec` one-shots write no wire log; their log file is the
only feed.

## Sessions, compare, flows

`exec` covers most of our use. Reach further only with a reason:

- Named session (`-s <name>`, bootstrapped with `sessions ensure`) when
  follow-up prompts need the subagent to keep context. A `NO_SESSION`
  error means no session exists yet — `sessions ensure` (or the CLI's
  suggested `sessions new`) creates it.
- `acpx compare <agent-a> <agent-b> ... '<prompt>'` for same-prompt
  cross-model bake-offs.
- Flows for durable multi-step orchestration.

Mechanics for all three live in the skill (sections Sessions, Compare,
and Flows).

## Prerequisites

- `acpx` itself: mise-managed (`npm:acpx`).

Backing CLIs per shortcut family, each on PATH and logged in once:

- `agpt*`/`aopus*`/`agemini` → `cursor-agent` (`cursor-agent login`);
  `agpt*` fall back to `codex-acp` where cursor-agent is absent
  (personal/homelab). Never kill cursor-agent's background
  `worker-server` process: it is a persistent auth broker, and killing
  it fails every later run with `RUNTIME: Authentication required` until
  a fresh login, while `cursor-agent status` still claims logged in.
  Scope cleanup kills to the acpx process, e.g. by the run's prompt-file
  slug.
- `afable*` → `claude-agent-acp`, authenticated via the `claude` CLI.
- State lives under `~/.acpx/` (sessions, queues, flows); acpx has no
  XDG relocation env var.

## Validation checklist

- The canonical invocation returns a reply, and `acpx config show`
  matches machines.toml `agent_clis` for this box (every rendered
  shortcut's backing CLI on PATH).
- The model pins pass the drift audit; `afable*` uses the `fable` alias,
  which tracks the latest release on its own.
- Spot-check that a run landed on the pinned model (ask it, or check
  session metadata).
- No write action was taken by a spawned agent without an appropriate
  permission mode.
- `~/.agents/bin/poll-stream` materializes from `home/dot_agents/bin/`
  (source covered by `make test-acpx-poll-stream`; materialization by the
  CI chezmoi dry-run smoke).
- Version-verified claims: acpx 0.13.1 (mise installs `npm:acpx` at
  `latest`), codex rust-v0.149.1, cursor-agent 2026.07.01, pi 0.80.3.
  Re-verify the matching sections when any of these move.
