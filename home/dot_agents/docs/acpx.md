# acpx Conventions

`acpx` is a headless ACP (Agent Client Protocol) CLI for running another
coding agent in a separate process with its own context. The full command
surface lives in the vendored `acpx` skill (utils-agent). This document
defines local conventions.

## Launch

Write the prompt to a file. Background the run and redirect it to a log:

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

Claude Code uses this redirected shape for relaying output. Codex,
cursor-agent, and pi run acpx directly without the `log=`, `echo`, and
redirect lines because their native surfaces provide the feed. See
[acpx-harness-lanes.md](acpx-harness-lanes.md). A direct-shape run leaves no
log.

The shortcut name selects the model, so `agpt` is the complete model
selection.

Keep these flags:

- `--format text` prevents a project `.acpxrc.json` from changing the output
  format.
- `--prompt-retries` absorbs transient adapter errors.
- `--no-terminal --non-interactive-permissions deny` makes tool-shell
  permission handling fail closed.

For a quick, low-stakes prompt that nobody needs to watch, run quietly in the
foreground:

```bash
acpx --format quiet --no-terminal --non-interactive-permissions deny \
  --timeout 300 agpt exec 'quick question'
# machine-readable for scripts:
acpx --format json --json-strict --no-terminal \
  --non-interactive-permissions deny --timeout 300 agpt exec -f prompt.md
```

Rules:

- Shortcut names (`agpt`, `aopus`, ...) are acpx agent names, not binaries.
  Invoke them as `acpx <name>`; `which agpt` finds nothing.
- Put global flags before `<name>`.
- Only `-f/--file` goes after `exec`.
- `-f -` reads stdin, so a heredoc works.
- Set acpx `--timeout` against the harness command timeout, which is often 2
  minutes. Background any run that will outlast it.
- The permission flags above deny writes instead of prompting in tool shells.
- For a hard read-only guarantee, use `--permission-policy` as documented
  under Permission modes in the skill.
- Reserve `--approve-all` for trusted automation.

## Finish

A run is complete when the log ends with a `[done] <stopReason>` marker. The
final answer is the assistant text immediately before it.

Handle the final marker as follows:

- `[done] end_turn`: natural completion.
- `[done] cancelled`: the run was cancelled or killed. On SIGTERM, acpx sends
  ACP `session/cancel`.
- `[error]` as the last line: terminal failure, usually during startup, such
  as `RUNTIME: Authentication required`.
- `[error]` before the last line: recoverable adapter noise. Narrate it and
  continue.
- No marker: the process died from SIGKILL, a crash, or another hard failure.
  Only the harness completion notification ends this case.

## Relay (Claude Code)

`--format text` streams assistant text and `[thinking]`, `[tool]`, and
`[plan]` status lines. Thinking is truncated in text mode. Use `--format json`
when full reasoning matters.

Use one blocking `~/.agents/bin/poll-stream` call per wait. Read its header
for arguments, exit codes, and defaults.

```bash
~/.agents/bin/poll-stream "$log" "$log.offset" 240 8192 > /tmp/chunk
```

Relay loop:

1. Launch with the canonical block.
2. Read the `log:` line from the background task output before polling.
3. Poll in the foreground with the tool timeout above max-wait-s. Use 270s
   over the default 240s because the helper may hold max-wait-s plus one
   second of clock-tick granularity.
4. Redirect every chunk to a file. This is required: through a pipe, an
   early-exiting reader such as `head` can cause a silent exit 141. A partial
   reader can exit 0 after dropping bytes while the offset still advances.
5. Narrate each chunk as it arrives.
6. Check the tail in a separate call. Never chain it after a poll; chaining
   masks the quiet-window exit and prints consumed bytes again.

   ```bash
   tail -c 64 "$log"
   ```

7. Stop only when:
   - The final log line starts with `[done] `.
   - A short-wait drain, `poll-stream "$log" "$log.offset" 5`, returns empty.

   Both checks are required. The byte cap can split a marker across chunks,
   quoted marker text can occur mid-stream, and the tail can show a marker
   before all preceding bytes have been consumed.

8. Treat the harness completion notification as the backstop for a dead,
   markerless, or forgotten run. Drain with short waits and report the tail.

A four-minute silence costs one round trip and remains inside the five-minute
prompt-cache window. Poll count scales with output rather than elapsed time.

To cancel:

- Stop the background task, or run `pkill -f "acpx-$slug"`.
- Keep the slug-specific pattern. A broad kill can terminate cursor-agent's
  shared `worker-server`.
- Expect `[done] cancelled`.

An `exec` one-shot cannot accept follow-up input. Use a named session when
follow-ups are likely.

On first-party API machines, probe ToolSearch for `Monitor`. Use the native
Monitor tool when available because it wakes per line. It is provider-gated
off Bedrock, Vertex, and Foundry; use the relay when unavailable.

## Shortcuts

Run `acpx config show` to inspect the model pins configured on the current
machine.

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

Adapter behavior:

- `agpt*`, `aopus*`, and `agemini` run through `cursor-agent`. Their model ids
  encode the reasoning tier.
- Those shortcuts carry `--add-dir` on `~/.agents/plugins` and, where it
  exists, `~/.claude/plugins/marketplaces`. cursor-agent loads plugin
  marketplaces in print mode but not under ACP, so skills arrive as files.
- An added root is readable by absolute path but not searchable: glob and grep
  resolve against the primary workspace and fail on it. Give the prompt the
  exact path of every file the agent needs.
- Without cursor-agent, `agpt` and `agptx` fall back to `codex-acp` and take
  their GPT model from `~/.codex/config.toml`. `codex-acp` loads plugin skills
  natively from that same file, so it needs no `--add-dir`.
- `agptw` has no fallback because Codex pins one model and exposes only
  reasoning effort.
- `afable*` run Claude Code through `claude-agent-acp`. The entry's
  `ANTHROPIC_MODEL` and `CLAUDE_CODE_EFFORT_LEVEL` environment variables
  select the model and effort because the adapter accepts no model or effort
  CLI arguments.
- `afable*` list plugin skills natively and namespaced, as
  `core:writing-for-humans`. That needs `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1`,
  exported from `$ZDOTDIR/.zshenv`; without it acpx withholds Claude user
  settings and the session sees only Claude Code's own skills.
- A shortcut is rendered only when its backing CLI appears in machines.toml
  `agent_clis`.

`agptw` is the rewrite lane:

- Give it the draft and the path
  `~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md`.
- Prefer `agptw` over `agpt` for prose-editing delegation.
- It uses the cheapest GPT-5.6 tier without the `-fast` suffix.
- Avoid low-reasoning Sol, which invents code spans absent from the source.
- Avoid high-reasoning Terra, which deletes filenames from the draft.
- See `docs/research/acpx-rewrite-model-bakeoff.md` in the dotfiles repo for
  the measurements and repinning method.

The `cursor-agent` ids pin specific models. Bare aliases (`opus`, `gpt`, ...)
resolve to older generations. Run the drift audit at
`scripts/audit/acpx-model-drift.sh` in the dotfiles repo. It reads
`home/dot_acpx/config.json.tmpl` and flags dropped or superseded pins.

## Past exec

Use `exec` for one-shot work. Use another mode when its condition applies:

- **Named session**: use `-s <name>`, bootstrapped with `sessions ensure`,
  when follow-up prompts must preserve subagent context. `NO_SESSION` means
  the session does not exist yet.
- **`acpx compare <agent-a> <agent-b> ... '<prompt>'`**: use for same-prompt
  cross-model comparisons. Rows include status and wall time but truncate
  replies. Run `exec` for each agent when you need full text.
- **Flows**: use for durable multi-step orchestration.

See Sessions, Compare, and Flows in the vendored skill for their mechanics.

## Prerequisites

`acpx` installs through mise (`npm:acpx`). Each shortcut family requires its
backing CLI on PATH and authenticated once:

- `agpt*`, `aopus*`, `agemini` → `cursor-agent` (`cursor-agent login`), with
  `agpt*` falling back to `codex-acp` on boxes without it.
- `afable*` → `claude-agent-acp`, authenticated through the `claude` CLI.

Scope every cleanup kill to one run using its prompt-file slug. cursor-agent
keeps a background `worker-server` that brokers authentication for later runs.
Killing it causes `RUNTIME: Authentication required` until a fresh interactive
login, even while `cursor-agent status` reports that authentication is valid.

Sessions, queues, and flows live under `~/.acpx/`. acpx has no XDG relocation
environment variable.

## Validation

- The canonical launch returns a reply.
- `acpx config show` matches machines.toml `agent_clis` for this box.
- Every rendered shortcut's backing CLI is on PATH.
- The pins pass the drift audit.
- `afable*` tracks the latest release through the `fable` alias.
- The run used the pinned model. Ask it or read the session metadata.
- The cursor-agent shortcuts start, proving their `--add-dir` roots exist.
  cursor-agent refuses to launch when one names a missing directory.
- No spawned agent wrote outside its permission mode.
- `~/.agents/bin/poll-stream` materialized from `home/dot_agents/bin/`.
- Its source passes `make test-acpx-poll-stream`.
- Its materialization passes the CI chezmoi dry-run smoke.
- Version-verified against acpx 0.13.2 (mise installs `npm:acpx` at `latest`),
  codex rust-v0.149.1, cursor-agent 2026.07.01, pi 0.80.3. Re-verify the
  matching sections when any of these moves.
