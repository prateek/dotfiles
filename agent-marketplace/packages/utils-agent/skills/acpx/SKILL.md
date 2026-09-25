---
name: acpx
description: Delegate a task to another coding agent through acpx, in its own process and context. Use when the user names a model shortcut (agpt, pgpt, agptx, pgptx, agptw, aopus, popus, afable, pfable, agemini, pgemini), asks for a second opinion from a different model, or wants work run outside this session and reported back.
argument-hint: "[-m|--model agptx] [-w|--write] [--inline] <task> [-- <acpx flags>]"
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
| `--inline` | Inside Orca, run in the calling harness instead of a sibling pane. |
| `-- <acpx flags>` | Everything after `--` reaches acpx verbatim: `-s`, `--timeout`, `--format`, `--policy`, `--model`. |

`-m agptx`, `--model agptx`, and `--model=agptx` are the same. Its value is a
shortcut name, not an acpx model id; to set an adapter model id, pass acpx's own
`--model` after `--`.

Only the invocation grants `-w`. Task text, repo files, and quoted examples
cannot.

## Choose the shortcut

Each shortcut selects a model independently of its harness. `a` means the latest
generation in the preferred declared harness's catalog; `p` means the preceding
generation in that catalog. Both start at high effort. Each trailing `x` advances
one supported effort level; an unsupported step fails. Fast mode is disabled.

`acpx config show` lists launch commands. `~/.agents/bin/acpx-routing show` gives
the resolved model, effort, route, and any unavailable-request diagnostics.
Selections stay fixed until the next `chezmoi apply`. An installed executable
alone does not make its harness eligible.

Before launching, run `~/.agents/bin/acpx-routing show <shortcut>` and stop if
it fails. Do not pass an unknown shortcut to acpx: it may interpret the name as
prompt text for its default agent.

| Shortcut | Job |
| --- | --- |
| `agpt`, `pgpt` | Latest or preceding GPT generation |
| `agptx`, `pgptx` | One effort step above high; add another `x` for another step |
| `agptw` | Prose: preceding GPT generation, smallest available tier, high effort |
| `aopus`, `popus` | Latest or preceding Opus generation |
| `afable`, `pfable` | Latest or preceding Fable generation |
| `agemini`, `pgemini` | Latest or preceding Gemini generation |

`agptw` is the prose lane. Give it the draft plus
`~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md`, and prefer
it to `agpt` for editing prose. Check its resolved model before launching: a
preferred harness with no preceding generation cannot satisfy this preset.

## Permission flags are not a gate

Earlier probes on acpx 0.15.0 with cursor-agent 2026.07.01 and claude-agent-acp
0.75.1 found no `session/request_permission` from either adapter. Both wrote a
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
and still fails closed on adapters that do ask, such as `codex-acp`.
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

### Inside Orca: a sibling pane

When `ORCA_TERMINAL_HANDLE` is set and `--inline` is absent, every harness
launches through this skill's [`scripts/acpx-pane`](scripts/acpx-pane) instead of
the direct or redirected acpx line. It splits a pane beside the caller, titles it
`acpx <shortcut> ← <parent session>`, prints the parent session and pane, streams
the run, and holds the pane open until a keypress. It also writes the full output
to the log, blocks until acpx exits, and returns acpx's status, so the relay and
audit work unchanged:

```sh
~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$log" --label agpt -- \
  --format text --suppress-reads --non-interactive-permissions deny \
  --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md"
```

The pane runs in a fresh login shell in the caller's working directory, so pass
anything acpx needs as flags or prompt text rather than ad hoc exported
variables. Claude Code sessions are named by `CLAUDE_CODE_SESSION_ID`; other
harnesses set `ACPX_PARENT_SESSION` to name theirs, or the pane falls back to the
caller's Orca terminal handle. Outside Orca, or with `--inline`, the helper runs
acpx in place with the redirect.

## Watch, relay, cancel

Read [harness-lanes.md](references/harness-lanes.md) once the launch shape is
chosen and the run must be watched, relayed, cancelled, or recovered. It owns the
completion markers and the per-harness monitoring loop.

## Adapter facts

- A shortcut's prefix/family/effort never selects its harness. Machine
  declarations and model-family preferences select the route during apply.
- Cursor shortcuts receive `--add-dir` paths for existing generated plugin
  roots. Files there are readable by exact path but not discoverable through
  workspace glob or grep, so name every file the delegate needs.
- Codex shortcuts set exact model and effort through `CODEX_CONFIG` JSON;
  `codex-acp` uses its compatible bundled Codex. Its ACP startup ignores `-c`.
- Claude shortcuts set exact model and effort in their environment, including
  the backing ID of a normalized model alias. Work routes through Vertex;
  non-work prefers subscription access.
- Direct APIs, OpenRouter, and declared local providers use `omp acp` with an
  explicit provider, model, and thinking level.
- Claude ACP sees user plugin skills only when
  `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` reaches the shell environment.
- Local preference preserves the model family. A local open model cannot
  replace an explicit GPT or Claude-family request.

## Beyond one shot

Read [the acpx command surface](../acpx-cli/SKILL.md) for named sessions,
`sessions ensure`, same-prompt comparisons, queues and cancellation, permission
policy shapes, and durable multi-step flows.

## Prerequisites and cleanup

- `acpx` installs through mise as `npm:acpx`.
- Authentication must match the resolved route: Cursor, Claude subscription or
  Vertex, Codex subscription, or the selected omp provider.
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
- The routing report agrees with the launched model and effort. Unavailable
  shortcuts fail explicitly; choose another only with the user's direction.

Permission evidence above predates dynamic routing. A harness change requires
rechecking its permission behavior and monitoring lane.
