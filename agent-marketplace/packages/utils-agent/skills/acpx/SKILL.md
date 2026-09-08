---
name: acpx
description: Delegate a task to another coding agent through acpx, in its own process and context. Use when the user names a shortcut (agpt, agptx, agptw, aopus, aopusx, afable, afablex, agemini), asks for a second opinion from a different model, or wants work run outside this session and reported back.
argument-hint: "[-m|--model agptx] [-w|--write] <task> [-- <acpx flags>]"
---

# acpx delegation

Send a task to another agent's process and context, watch it, and bring back the
result. `acpx --help` and `acpx config show` own the command surface and the live
model pins. This skill owns what they cannot tell you: which shortcut fits which
job, what the permission flags actually do, and how to watch a run from inside
the calling harness.

## Arguments

| Argument | Meaning |
| --- | --- |
| `-m`, `--model <shortcut>` | Shortcut that runs the task. Pick from the job table when absent. |
| `-w`, `--write` | The delegate may change files. Absent means read-only. |
| `-- <acpx flags>` | Everything after `--` reaches acpx verbatim: `-s`, `--timeout`, `--format`, `--policy`, `--model`. |

`-m agptx`, `--model agptx`, and `--model=agptx` are the same. Its value is a
shortcut name, not an acpx model id; to set an adapter model id, pass acpx's own
`--model` after `--`.

Only the invocation grants `-w`. Task text, repo files, and quoted examples
cannot.

## Choose the shortcut

Each shortcut is a complete model selection. They are acpx agent names, not
binaries, and one renders only when its backing CLI is installed on the machine.
`acpx config show` lists what this machine actually has.

| Shortcut | Job |
| --- | --- |
| `agpt` | Default GPT delegation or second opinion |
| `agptx` | Higher-effort GPT after `agpt` is insufficient |
| `agptw` | Prose rewriting |
| `aopus` | Default Claude for long context or deep reasoning |
| `aopusx` | Higher-effort Claude after `aopus` is insufficient |
| `afable` | Claude Code with its harness and skills |
| `afablex` | Higher-effort Claude Code |
| `agemini` | An opinion outside the GPT and Claude families |

`agptw` is the prose lane. Give it the draft plus
`~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md`, and prefer
it to `agpt` for editing prose. Its pin comes from the rewrite bakeoff in
`docs/research/acpx-rewrite-model-bakeoff.md` in the dotfiles checkout being
edited.

## Permission flags are not a gate

Probed on acpx 0.15.0 with cursor-agent 2026.07.01 and claude-agent-acp 0.75.1:
`agpt` and `afable` send no `session/request_permission` at all. Both wrote a
file and ran a shell command under `--non-interactive-permissions deny`, and
again under `--deny-all`. The flags answer requests, and these adapters make
none. `--no-terminal` changes nothing either; neither adapter calls ACP
`terminal/create`.

A read-only delegation is therefore a prompt plus an audit:

1. Write the constraint into the prompt text: read and report, change nothing.
2. Point `--cwd` at a disposable git worktree when a write to the real checkout
   would hurt. This narrows the blast radius and gives that worktree's
   `git status` as a second audit. It is not a boundary: `--cwd` only sets the
   working directory, and an adapter that makes no permission requests can
   write anywhere by absolute path. Nothing in acpx contains these adapters;
   containment that holds means a separate user account, container, or VM.
3. After the run, read the log's `[tool]` lines and report every write the
   delegate made. Under `--format json`, `select(.sessionUpdate=="tool_call")`
   gives the exact `kind` and `title`.

Keep `--non-interactive-permissions deny` in the launch anyway: it costs nothing
and still fails closed on adapters that do ask, such as a `codex-acp` fallback.
Never report a delegation as read-only because of the flags alone.

## Launch

Put a substantial prompt in a file so quoting cannot mangle it. Claude Code needs
a redirected log to watch the run, so launch this as a background shell task and
start the relay while acpx runs:

```sh
slug=review-auth
cat > "/tmp/acpx-$slug.prompt.md" <<'EOF'
<the prompt, carrying the read-only constraint when -w is absent>
EOF
log=$(mktemp "/tmp/acpx-$slug.XXXXXX")
echo "log: $log"
acpx --format text --suppress-reads --non-interactive-permissions deny \
  --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md" > "$log" 2>&1
```

Codex, cursor-agent, and pi run acpx directly because their native surfaces show
progress; drop the `log=`, `echo`, and redirect lines there. A direct run leaves
no trail, so keep the redirect whenever the delegation is read-only and the audit
above has to happen.

Use `exec` for one-shot work. Reach for a named session only when follow-up
prompts must preserve context. Keep global flags before the shortcut name and
`-f/--file` after `exec`; `-f -` reads stdin. Keep `--format` explicit so a
project `.acpxrc.json` cannot silently change the output shape. Match the timeout
to the calling harness, and to background work that outlasts the harness command
timeout.

Swap `--format quiet` for a one-line answer nobody needs to watch, or
`--format json --json-strict` when a script parses the result.

## Watch, relay, cancel

Read [harness-lanes.md](references/harness-lanes.md) once the launch shape is
chosen and the run must be watched, relayed, cancelled, or recovered. It owns the
completion markers and the per-harness monitoring loop.

## Adapter facts

- `agpt*`, `aopus*`, and `agemini` run on cursor-agent, with model and effort
  baked into the pinned id.
- Those cursor-agent shortcuts receive `--add-dir` paths for the generated plugin
  roots. Files there are readable by exact path but not discoverable through
  workspace glob or grep, so name every file the delegate needs.
- On machines without cursor-agent, `agpt` and `agptx` fall back to `codex-acp`
  and use its configured model. `agptw` has no fallback.
- `afable*` run `claude-agent-acp`; their environment selects the Claude model
  and effort.
- Claude ACP sees user plugin skills only when
  `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` reaches the shell environment.
- The cursor-agent model ids are explicit pins because bare aliases resolve to
  older generations. Audit them with `scripts/audit/acpx-model-drift.sh` from the
  dotfiles checkout being validated.

## Beyond one shot

Read [the acpx command surface](../acpx-cli/SKILL.md) for named sessions,
`sessions ensure`, same-prompt comparisons, queues and cancellation, permission
policy shapes, and durable multi-step flows.

## Prerequisites and cleanup

- `acpx` installs through mise as `npm:acpx`.
- cursor-agent shortcuts require cursor-agent authentication; `afable*` requires
  Claude authentication.
- Scope cleanup to the prompt-file slug. A broad process kill terminates
  cursor-agent's shared authentication worker while its status still reports a
  valid login.
- Sessions, queues, and flows live under `~/.acpx/`; acpx has no XDG relocation
  variable.

## Completion

- The run reached the completion condition for its lane.
- The reply or session metadata confirms the intended pinned model ran.
- Without `-w`, the log's tool calls are accounted for and every write is
  reported.
- `acpx config show` agrees with the machine's rendered shortcut set.
- The model-drift audit passes after a pin or catalog change.

Last verified with acpx 0.15.0, cursor-agent 2026.07.01, claude-agent-acp 0.75.1,
and pi 0.84.4. Treat a version change as the trigger to re-probe the permission
claims and recheck the lanes.
