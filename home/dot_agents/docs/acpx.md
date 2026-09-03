# acpx Conventions

`acpx` is a headless ACP (Agent Client Protocol) CLI for running another
coding agent from inside a session: a second opinion from a different model, a
delegated one-shot task, a scripted multi-agent step. It spawns a separate
process with its own context; your own model and session carry on untouched.

The full command surface lives in the vendored `acpx` skill (utils-agent).
This doc is the local conventions layer on top of it.

## Launch

Write the prompt to a file, then background the run and redirect it to a log:

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

That is the redirected **shape**, which Claude Code relays from. Codex,
cursor-agent, and pi run acpx directly and drop the `log=`, `echo`, and
redirect lines, because their own surfaces are the feed and a redirect would
leave them watching a silent command — see
[acpx-harness-lanes.md](acpx-harness-lanes.md). What the redirect buys either
way is a **trail**: a direct-shape run leaves no log behind.

The shortcut name pins the model, so `agpt` is the whole model selection.
`--format text` stays explicit because a project `.acpxrc.json` can otherwise
change it. `--prompt-retries` absorbs transient adapter errors.

For a quick, low-stakes prompt nobody needs to watch, run it quiet in the
foreground and keep the safety flags:

```bash
acpx --format quiet --no-terminal --non-interactive-permissions deny \
  --timeout 300 agpt exec 'quick question'
# machine-readable for scripts:
acpx --format json --json-strict --no-terminal \
  --non-interactive-permissions deny --timeout 300 agpt exec -f prompt.md
```

What trips agents up:

- Shortcut names (`agpt`, `aopus`, ...) are acpx agent names, not binaries.
  Reach them as `acpx <name>`; `which agpt` finds nothing.
- Global flags go before `<name>`. Only `-f/--file` goes after `exec`, where
  `-f -` reads stdin, so a heredoc works.
- Set acpx `--timeout` against the harness's own command timeout, which is
  often 2 minutes. A tool shell that short kills a longer run mid-flight, so
  background anything that will outlast it.
- The permission flags above fail closed in tool shells: writes are denied
  rather than prompted. For a hard read-only guarantee use
  `--permission-policy` (skill: Permission modes). Keep `--approve-all` for
  trusted automation.

## Finish

A run is over when the log ends with a `[done] <stopReason>` **marker**, and
the final answer is the assistant text just before it. Branch on which marker:

- `[done] end_turn` — a natural finish.
- `[done] cancelled` — cancelled or killed; acpx sends ACP `session/cancel` on
  SIGTERM.
- `[error]` as the **last** line — terminal, typically a startup failure like
  `RUNTIME: Authentication required`. Mid-stream `[error]` lines are
  recoverable adapter noise: narrate them and keep going.
- No marker at all — the run died hard (SIGKILL, crash). Only the harness
  completion notification ends this one.

## Relay (Claude Code)

`--format text` streams as it goes: assistant text, plus `[thinking]` and
`[tool]`/`[plan]` status lines. Thinking is truncated in text mode, so switch
to `--format json` when full reasoning matters.

Turn each wait into one blocking call with `~/.agents/bin/poll-stream`. Its
header is the contract for arguments, exit codes, and defaults; read it there
rather than guessing.

```bash
~/.agents/bin/poll-stream "$log" "$log.offset" 240 8192 > /tmp/chunk
```

1. Launch with the block above, then read the `log:` line out of the
   background task's output before polling.
2. Poll in the foreground with the tool timeout set above max-wait-s — 270s
   over the default 240s, since the helper holds max-wait-s plus up to a
   second of clock-tick granularity.
3. Redirect each chunk to a file, as above. The file capture is load-bearing:
   through a pipe, an early-exiting reader like `head` gives a silent exit
   141, and a partial reader can exit 0 having dropped bytes while the offset
   advanced anyway.
4. Narrate each chunk as it arrives.
5. Check the tail as its own call, never chained after a poll — chaining masks
   the quiet-window exit and re-prints bytes you already consumed.

   ```bash
   tail -c 64 "$log"
   ```

6. Stop when the final log line starts with `[done] ` **and** a short-wait
   **drain** (`poll-stream "$log" "$log.offset" 5`) comes back empty. Both
   halves matter: the byte cap can split a marker across chunks, quoted marker
   text can appear mid-stream, and the tail can show a marker whose preceding
   bytes you have not read yet.
7. Treat the harness completion notification as the backstop for a dead,
   markerless, or forgotten run: drain with short waits and report what the
   tail shows.

A four-minute silence costs one round trip and stays inside the five-minute
prompt-cache window. Polls scale with output, not with elapsed time.

To cancel, stop the background task, or kill scoped to this run alone with
`pkill -f "acpx-$slug"` — the slug is what keeps the pattern narrow, and
Prerequisites explains what a broad one destroys. A cancelled run ends
`[done] cancelled`. An `exec` one-shot cannot be steered mid-flight, so when
follow-ups look likely, open a named session instead.

On first-party API machines the native Monitor tool is better than this loop,
since it wakes per line. It is provider-gated off Bedrock, Vertex, and
Foundry, so probe ToolSearch for `Monitor` first and fall back to the relay.

## Shortcuts

Which model each shortcut resolves to lives in the config; run
`acpx config show` to read the pins this machine actually has. What the config
cannot hold is why you would pick one, so that is what this table is:

| Shortcut  | Reach for it when                                     |
| --------- | ----------------------------------------------------- |
| `agpt`    | Default GPT. A second opinion, a delegated task        |
| `agptx`   | The problem beat `agpt`                                |
| `agptw`   | Editing prose (see below)                              |
| `aopus`   | Default Claude. Long context, deep reasoning           |
| `aopusx`  | Claude at max thinking, when `aopus` came back thin    |
| `afable`  | Claude Code itself, with its harness and skills loaded |
| `afablex` | Same, at max effort                                    |
| `agemini` | A third opinion from outside both families             |

Adapters differ by family. `agpt*`, `aopus*`, and `agemini` run through
`cursor-agent`, with the reasoning tier encoded in the model id. Where
cursor-agent is absent, `agpt` and `agptx` fall back to `codex-acp`, taking
their GPT model from `~/.codex/config.toml`; `agptw` has no fallback, because
Codex pins one model and exposes only reasoning effort. `afable*` run Claude
Code through `claude-agent-acp`, with model and effort set by the entry's
`ANTHROPIC_MODEL` and `CLAUDE_CODE_EFFORT_LEVEL` env vars, since that adapter
takes no model or effort CLI arguments.

`agptw` is the rewrite lane: hand it a draft plus the `writing-for-humans`
rules and take back edited prose. It runs the cheapest GPT-5.6 tier and skips
the `-fast` suffix that doubles the rate, because a background rewrite needs
no priority scheduling. Prefer it over `agpt` for any prose-editing
delegation. Two settings to stay away from: a low-reasoning Sol invents code
spans the source never had, and a high-reasoning Terra deletes filenames out
of the draft. The measurements, and the method for re-picking this pin, are in
`docs/research/acpx-rewrite-model-bakeoff.md` in the dotfiles repo.

The `cursor-agent` ids pin the current latest of each family and go stale as
the catalog moves. The bare aliases (`opus`, `gpt`, ...) are no escape hatch —
they resolve to *older* generations. The drift audit
(`scripts/audit/acpx-model-drift.sh` in the dotfiles repo) reads the pins
straight out of `home/dot_acpx/config.json.tmpl` and flags dropped or
superseded ones, so refreshing a pin is a one-file edit.

The config is templated per machine from machines.toml `agent_clis`, so a
shortcut in the table is absent wherever its backing CLI is.

## Past exec

`exec` covers most of our use. Escalate with a reason:

- **Named session** (`-s <name>`, bootstrapped with `sessions ensure`) when
  follow-up prompts need the subagent to keep context. A `NO_SESSION` error
  means none exists yet.
- **`acpx compare <agent-a> <agent-b> ... '<prompt>'`** for same-prompt
  cross-model bake-offs. Its rows carry status and wall time, and truncate the
  reply, so run `exec` per agent when you need the full text.
- **Flows** for durable multi-step orchestration.

Mechanics for all three live in the skill, under Sessions, Compare, and Flows.

## Prerequisites

`acpx` installs through mise (`npm:acpx`). Each shortcut family needs its
backing CLI on PATH and logged in once:

- `agpt*`, `aopus*`, `agemini` → `cursor-agent` (`cursor-agent login`), with
  `agpt*` falling back to `codex-acp` on boxes without it.
- `afable*` → `claude-agent-acp`, authenticated through the `claude` CLI.

Scope every cleanup kill to one run, by its prompt-file slug. cursor-agent
keeps a background `worker-server` that brokers auth for every later run: kill
it and each one fails with `RUNTIME: Authentication required` until a fresh
interactive login, while `cursor-agent status` still reports you as logged in.

State lives under `~/.acpx/` — sessions, queues, flows. acpx has no XDG
relocation env var.

## Validation

- The canonical launch returns a reply, and `acpx config show` matches
  machines.toml `agent_clis` for this box, with every rendered shortcut's
  backing CLI on PATH.
- The pins pass the drift audit. `afable*` tracks the latest release on its
  own through the `fable` alias.
- A run landed on the pinned model: ask it, or read the session metadata.
- No spawned agent wrote anything outside its permission mode.
- `~/.agents/bin/poll-stream` materialized from `home/dot_agents/bin/`. Its
  source is covered by `make test-acpx-poll-stream`, its materialization by
  the CI chezmoi dry-run smoke.
- Version-verified against acpx 0.13.2 (mise installs `npm:acpx` at `latest`),
  codex rust-v0.149.1, cursor-agent 2026.07.01, pi 0.80.3. Re-verify the
  matching sections when any of these moves.
