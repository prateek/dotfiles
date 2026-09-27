---
name: acpx
description: Delegate a task to another coding agent through acpx, in its own process and context. Use when the user names a model shortcut (agpt, pgpt, agptx, pgptx, agptw, aopus, popus, afable, pfable, agemini, pgemini), asks for a second opinion from a different model, or wants work run outside this session and reported back.
argument-hint: "[-m|--model agptx] [-w|--write] [--inline] <task> [-- <acpx flags>]"
---

# Delegate with acpx

Use acpx to run a task in another agent's process and context, then report its
result. The command surface and active model pins come from `acpx --help` and
`acpx config show`. This skill covers shortcut choice, permission limits, and
how to follow a run from the calling harness.

## Build the invocation

| Argument | Effect |
| --- | --- |
| `-m`, `--model <shortcut>` | Shortcut that runs the task. Pick from the job table when absent. |
| `-w`, `--write` | The delegate may change files. Absent means read-only. |
| `--inline` | Inside Orca, run in the calling harness instead of the shared view. |
| `-- <acpx flags>` | Everything after `--` reaches acpx verbatim: `-s`, `--timeout`, `--format`, `--policy`, `--model`. |

The shortcut value is not an acpx model ID. These forms are equivalent:
`-m agptx`, `--model agptx`, and `--model=agptx`. To set an adapter model ID,
pass acpx's own `--model` after `--`.

Only `-w` on the invocation grants write permission. Task wording, repository
files, and quoted examples do not.

## Select and verify a shortcut

Each shortcut selects a model independently of its harness. `a` means the
latest generation in the preferred declared harness's catalog; `p` means the
previous generation in that catalog. Both start at high effort. Each trailing
`x` advances effort by one supported level; an unsupported step fails. Fast
mode is disabled.

Before launch, run `~/.agents/bin/acpx-routing show <shortcut>`. Continue only
when it succeeds and reports an available route. `acpx config show` lists
launch commands; the routing command reports the resolved model, effort, route,
and unavailable-request diagnostics. Shortcut selections stay fixed until the
next `chezmoi apply`. An installed executable alone does not make its harness
eligible.

| Shortcut | Job |
| --- | --- |
| `agpt`, `pgpt` | Latest or previous GPT generation |
| `agptx`, `pgptx` | One effort step above high; add another `x` for another step |
| `agptw` | Prose: previous GPT generation, smallest available tier, high effort |
| `aopus`, `popus` | Latest or previous Opus generation |
| `afable`, `pfable` | Latest or previous Fable generation |
| `agemini`, `pgemini` | Latest or previous Gemini generation |

Use `agptw` for prose edits. Give it the draft and
`~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md`. First
confirm the resolved model: this preset fails if its preferred harness has no
previous generation available.

## Treat permission flags as request handling

On acpx 0.15.0 with cursor-agent 2026.07.01 and claude-agent-acp 0.75.1,
probes found no `session/request_permission` calls. Both adapters wrote a file
and ran a shell command under `--non-interactive-permissions deny` and under
`--deny-all`. Those flags answer permission requests; these adapters made none.
`--no-terminal` also changed nothing because neither adapter called
`terminal/create`.

Treat read-only delegation as a prompt plus an audit:

1. Put “read and report; change nothing” in the prompt when `-w` is absent.
2. Use a disposable git worktree as `--cwd` when a write to the real checkout
   would be harmful. Check its `git status` as a second audit. `--cwd` only sets
   the working directory; an adapter that makes no permission request can
   still write to an absolute path. A separate user account, container, or VM
   is required for containment.
3. Inspect the log's `[tool]` lines after the run and account for every write.
   With `--format json`, select
   `.sessionUpdate=="tool_call"` to see each tool call's `kind` and `title`.

Keep `--non-interactive-permissions deny` in the launch. It fails closed for
adapters that do ask, such as `codex-acp`, but it does not make the adapters
above read-only. Never describe a delegation as read-only based on flags alone.

The permission probes predate dynamic routing. Recheck an adapter whenever its
version or route changes.

## Launch a one-shot task

Put substantial prompt text in a file to avoid shell-quoting errors. Claude Code
needs a redirected log for monitoring, so launch it as a background shell task
and start the relay while acpx runs:

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

Codex, cursor-agent, and pi show progress natively, so run acpx directly in
those harnesses. Keep the redirect for read-only work when its audit needs a
log.

Use `exec` for one-shot work. Use a named session when later prompts must keep
the same context. Put global flags before the shortcut and `-f`/`--file` after
`exec`; `-f -` reads stdin. Set `--format` explicitly so a project
`.acpxrc.json` cannot silently change the output shape. Set a timeout that fits
both the calling harness and background work that outlasts the command timeout.

Use `--format text` by default. For scripts, use `--format json --json-strict`.
Never use `--format quiet`: it hides progress and thinking that reveal a stuck
run.

### Inside Orca: the shared ACPX view

When Orca provides a terminal handle or worktree ID and `--inline` is absent, every harness
launches through this skill's [`scripts/acpx-pane`](scripts/acpx-pane) instead of
the direct or redirected acpx line. The first call opens one Orca pane containing
a compact Herdr session. Later calls from the same Orca terminal add tabs there.
Each tab shows its launch order, local time, and shortcut, such as
`02 14:41 aopus`. The bottom strip shows the number of session tabs; use
`Ctrl+B`, then `n` or `p` to switch. The helper writes the full output to the log,
blocks until acpx exits, and returns acpx's status, so the relay and audit work
unchanged:

```sh
~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$log" --label agpt -- \
  --format text --suppress-reads --non-interactive-permissions deny \
  --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md"
```

The helper checks the caller's current worktree before splitting beside its
terminal. If an inherited handle belongs to another worktree, it selects the
current worktree's sole agent terminal; if no parent is available, it runs inline.
The launch command is the same for every calling harness. To create the empty
view or switch Orca back to the existing one, run
`~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --view`.
The helper manages the Herdr session and its tab labels; callers do not need
Herdr commands. Missing Herdr or Python 3, or a failed view launch, falls back to inline acpx.
Outside Orca, or with `--inline`, the helper runs acpx in place with the redirect.
Herdr is declared in the mac-desktop package group. Completed tabs wait quietly
on their final output for review, without returning to a shell prompt. Press
an ordinary key or `Ctrl+C` to close a completed tab; when it is the last ACPX
tab, the Orca view closes too. `Ctrl+B`, then `q` detaches the Herdr view while
keeping its tabs available. Stopping a waiting helper closes only its tab.

Each Herdr tab starts in the caller's working directory. Pass acpx inputs
as flags or prompt text rather than relying on ad hoc exported variables.

## Monitor, relay, and cancel

Read [harness-lanes.md](references/harness-lanes.md) when the selected launch
needs monitoring, relaying, cancellation, or recovery. It defines the
completion markers and each harness's monitoring loop.

## Route-specific behavior

- A shortcut's prefix, family, and effort do not select its harness. Machine
  declarations and model-family preferences select the route during apply.
- Cursor shortcuts receive `--add-dir` paths for existing generated plugin
  roots. Exact paths are readable, but workspace glob and grep do not discover
  those files. Name each file the delegate needs.
- Codex shortcuts set exact model and effort through `CODEX_CONFIG` JSON.
  `codex-acp` ignores `-c` during ACP startup.
- Claude shortcuts set exact model and effort in their environment, including
  the backing ID for a normalized model alias. Work routes through Vertex;
  non-work prefers subscription access.
- Direct APIs, OpenRouter, and declared local providers use `omp acp` with an
  explicit provider, model, and thinking level.
- Claude ACP sees user plugin skills only when
  `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` reaches its shell environment.
- Local preference preserves the requested model family. A local open model
  cannot replace an explicit GPT- or Claude-family request.

## Named sessions and flows

Read [the acpx command surface](../acpx-cli/SKILL.md) for named sessions,
`sessions ensure`, same-prompt comparisons, queues, cancellation, permission
policy shapes, and durable multi-step flows.

## Prerequisites and cleanup

- Install `acpx` through mise as `npm:acpx`.
- Authenticate for the resolved route: Cursor, Claude subscription or Vertex,
  Codex subscription, or the selected omp provider.
- Scope cleanup to the prompt-file slug. A broad process kill can stop
  cursor-agent's shared authentication worker while status still reports a
  valid login.
- Sessions, queues, and flows live under `~/.acpx/`; acpx has no XDG relocation
  variable.

## Completion

Finish when the lane reaches its completion condition, the reply or session
metadata confirms the intended pinned model ran, and `acpx config show` agrees
with the machine's rendered shortcut set. Confirm the routing report matches
the launched model and effort. If `-w` was absent, account for every logged
tool call and report every write. An unavailable shortcut must fail explicitly;
choose a replacement only with the user's direction.
