# acpx Conventions

## Purpose

Use this playbook to run another coding agent from inside a session via
`acpx`, a headless ACP (Agent Client Protocol) CLI. Reach for it for a
second opinion from a different model, a delegated one-shot task (review,
rewrite, draft), or a scripted multi-agent step. The spawned agent is a
separate process with its own context; this is not a way to switch your
own model.

The full command surface lives in the vendored `acpx` skill (utils-agent).
This doc covers only local conventions: the canonical invocations, the
model shortcuts, and how to watch a run.

## Canonical invocations

Default — watchable background run. Write the prompt to a file, stream
`text` output to a log, and run it in the harness's background mode
(Claude Code: `run_in_background`; elsewhere: `nohup … &` — see
Watching a run):

```bash
slug=review-auth   # short task label
cat > "/tmp/acpx-$slug.prompt.md" <<'EOF'
<the prompt>
EOF
log=$(mktemp "/tmp/acpx-$slug.XXXXXX")
acpx --format text --suppress-reads --no-terminal \
  --non-interactive-permissions deny --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md" > "$log" 2>&1
echo "log: $log"
```

The shortcut (`agpt` here) selects the model — we never pass `--model`;
the shortcut's config entry pins it, keeping model ids in the one place
the drift audit refreshes. Swap in any name from the table below.
`mktemp` keeps concurrent runs from clobbering each other's logs; the
final `echo` is how the log path survives into later tool calls and
reaches the human. `--prompt-retries` absorbs transient adapter errors,
and `--format text` stays explicit so a project `.acpxrc.json` cannot
silently change the output format.

The invoking agent tails the log to relay progress. The run is finished
when the log ends with `[done] <stopReason>`; the final answer is the
assistant text just before it. The log is also the forensic trail when a
run misbehaves — a quiet `exec` leaves none. `--suppress-reads` keeps the
stream readable when the subagent reads large files.

Fall back to a foreground run only for quick, low-stakes prompts where
nobody needs progress. Keep the safety flags:

```bash
# final answer only
acpx --format quiet --no-terminal --non-interactive-permissions deny \
  --timeout 300 agpt exec 'quick question'

# machine-readable for scripts — same raw ACP wire schema as the session
# stream log, so the jq recipe in Watching a run applies
acpx --format json --json-strict --no-terminal \
  --non-interactive-permissions deny --timeout 300 agpt exec -f prompt.md
```

Foreground runs race the harness's own command timeout (often 2 minutes);
raise it or stay short.

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

The `cursor-agent` ids are pins to the current latest of each family and go
stale as the catalog moves; cursor-agent's own bare aliases (`opus`, `gpt`,
`sonnet`, ...) resolve to *older* generations, so they are not a
latest-tracking escape hatch. Run the drift audit in the dotfiles repo
(`scripts/audit/acpx-model-drift.sh`) to flag pins the catalog dropped or
superseded, then refresh the ids in `home/dot_acpx/config.json.tmpl` and this
table together.

The config is templated per machine (machines.toml `agent_clis`), so the
rendered shortcut set varies by box — don't assume from this table. Run
`acpx config show` to see what this machine actually has.

## Watching a run

The default invocation already streams: `--format text` emits assistant
text as it arrives plus `[thinking]` and `[tool]`/`[plan]` status lines.
Thinking is truncated in text mode — fine for watching; when full
reasoning matters (relaying it, auditing a run), use `--format json` or
the wire log instead.

The command is the same everywhere; only the launch and the progress
feed differ:

| Who runs it          | Launch with         | Follow progress via                 |
| -------------------- | ------------------- | ----------------------------------- |
| Claude Code          | `run_in_background` | Read/tail `$log` between tool calls |
| Codex / cursor-agent | `nohup … &`         | `tail` `$log` in later tool calls   |
| Human (spectating)   | —                   | `tail -f` the path the agent echoed |

Bare `&` survives Claude Code's tool shell but is reaped by
cursor-agent's; `nohup` works in both. With the redirect in place the
command's own output stays empty until exit — the log file is the feed.
The invoking agent relays progress by default; spectating is opt-in.

Persistent sessions (not `exec`) additionally append the raw ACP wire log
to `~/.acpx/sessions/<recordId>.stream.ndjson` no matter which `--format`
the caller picked, so you can watch a session some other process started
quietly. Find the record id with `acpx <agent> sessions show` (its `id:`
line) in that session's cwd, or across directories with
`acpx <agent> sessions list --local`, then:

```bash
tail -f ~/.acpx/sessions/<recordId>.stream.ndjson | jq -j '
  select(.method=="session/update") | .params.update |
  if .sessionUpdate=="agent_thought_chunk" then "\u001b[2m"+(.content.text//empty)+"\u001b[0m"
  elif .sessionUpdate=="agent_message_chunk" then (.content.text//empty)
  elif .sessionUpdate=="tool_call" then "\n[tool] "+(.title//"")+"\n"
  else empty end'
```

Caveats: `exec` one-shots write no wire log — their stdout/log file is
the only feed (if the path was never echoed, try
`ls -t /tmp/acpx-*.log* | head -1`). Wire logs keep full prompts,
reasoning, and tool output, and prune only removes closed sessions:
`sessions close`, then `sessions prune --include-history`. Treat them as
sensitive and prune periodically.

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

- `acpx` CLI: installed via mise (`npm:acpx`).
- `cursor-agent` on PATH: backs the `agpt*`/`aopus*`/`agemini` shortcuts.
  Installed via its own installer (`~/.local/bin/cursor-agent`), not
  mise-managed. `cursor-agent login` once.
- `claude-agent-acp` on PATH: backs the `afable*` shortcuts. Installed via
  mise (`npm:@agentclientprotocol/claude-agent-acp`). Uses the `claude` CLI's
  own auth; log in with `claude` once.
- State lives under `~/.acpx/` (sessions, queues, flows). acpx has no XDG /
  relocation env var, so this path is fixed.

## Validation checklist

- The canonical invocation returns a reply on this machine.
- The `cursor-agent` model ids pass the drift audit (see Model shortcuts
  above). The `afable*` entries use the `fable` alias, which tracks the latest
  Fable release on its own.
- `acpx config show` output matches machines.toml `agent_clis` for this box:
  every rendered shortcut has its backing CLI on PATH, and none are missing.
- The shortcut actually ran on the pinned model (ask it; or check session
  metadata) — `cursor-agent` must honor `--model <id> acp`, and the `afable*`
  entries need `claude-agent-acp` on PATH.
- No write action was taken by the spawned agent without an appropriate
  permission mode.
- Streaming and stream-file behavior statements above were verified on acpx
  0.13.1; mise installs `npm:acpx` at `latest`, so re-check them when the CLI
  moves.
