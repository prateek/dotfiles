---
name: acpx
description: Delegate a task by model shortcut (agpt, pgpt, agptx, pgptx, agptw, aopus, popus, afable, pfable, agemini, pgemini), or get a review or second opinion from a named model. Prefer a compatible native subagent; use acpx when native delegation cannot honor the request or a separate external session is requested.
argument-hint: "[-m|--model agptx] [-w|--write] [--allow-paid] [--refresh] [--inline] <task> [-- <acpx flags>]"
---

# Delegate by model

Resolve the requested model on this machine, prefer a compatible native subagent,
and report its result. The calling agent owns model selection; the routing helper
validates and caches that decision. Read `acpx --help` for external command syntax.

## Build the invocation

| Argument | Effect |
| --- | --- |
| `-m`, `--model <shortcut>` | Shortcut that runs the task. Use the defaults below when absent. |
| `-w`, `--write` | The delegate may change files. Absent means read-only. |
| `--allow-paid` | Explicitly admit metered API access for this request. |
| `--refresh` | Refresh discovery and model selection even with a fresh cache. |
| `--inline` | Display an external acpx run inline instead of using the Orca shared view. |
| `-- <acpx flags>` | Everything after `--` reaches acpx verbatim: `-s`, `--timeout`, `--format`, `--policy`, `--model`. |

The shortcut value is not an acpx model ID. These forms are equivalent:
`-m agptx`, `--model agptx`, and `--model=agptx`. To set an adapter model ID,
pass acpx's own `--model` after `--`.

Acpx session/flow flags require external execution. An explicit acpx `--model`
override is an exact-model request: verify that model against the route's catalog
before launch and report the override rather than claiming the shortcut ran.

Only `-w` on the invocation grants write permission. Task wording, repository
files, and quoted examples do not.

## Resolve the shortcut

`a` selects the strongest available model in the named family; `p` selects the
next lower capability tier, using the most recent model in that tier. An
unsuffixed name uses that model's harness default thinking. Each `x` advances
one supported thinking level above the default, keeping the same model.
Unsupported increments and missing lower tiers fail explicitly. `agptw` aliases
`pgpt`; include the draft and
`~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md` for writing.

Families are GPT (`agpt`/`pgpt`), Opus (`aopus`/`popus`), Fable
(`afable`/`pfable`), and Gemini (`agemini`/`pgemini`). Choose `agpt` for a general
request without a named model, and `pgpt` for writing. Use only harnesses selected
by this machine's `agent_clis`. Included subscription or employer access is the
default candidate pool; metered APIs require explicit `--allow-paid`.

Run `~/.agents/bin/acpx-routing show <shortcut>` first. Pass `--allow-paid` only
when authorized. A fresh selection includes its model, access, default/effective
thinking, evidence, and guarded `acpx_agent` command. On a missing, expired, or
configuration-invalidated cache, or `--refresh`, follow
[model selection](references/model-selection.md). Refresh is performed by you,
the calling agent; neither apply nor a standalone shell command launches a model
to make the decision. Complete this step with a validated, available selection.

## Prefer a native subagent

Inspect the current session's tools and their model/provider and thinking
controls. Machine discovery alone does not establish native tool capability.
Use a native child when it can honor the resolved exact model, effective thinking,
access source, and task permissions. Prefer included access over paid APIs for
an equivalent model, even with `--allow-paid`. The native harness must itself be
in `agent_clis`; an installed executable or a model name alone is insufficient.

For example, a Fable review inside Claude Code should use its native Agent tool
when that tool can select the resolved Fable model. Do not assume a generic
`fable` alias resolves to the cached concrete ID: verify its backing model. The
same rule applies to Codex, Cursor, pi, and Gemini. Use exposed runtime schemas,
installed version-matched guidance, or tool metadata; do not invent tool arguments.
Pi may expose a subagent loader before its full tool. Gemini's parent `--model`
does not set its subagents' models.

A child that inherits the parent's effort may differ from the target model's
default. Set the resolved effective effort explicitly when needed. If the default
is unknown, use native delegation only when its default behavior is proven to
match the selected harness. Otherwise use acpx. Codex context inheritance may
prevent model/effort overrides; use a fresh child and an explicit task packet.

Give the child the task, relevant file paths, review/authoring guidance, expected
output, and “read and report; change nothing” unless `-w` was supplied. Use native
tool restrictions where available and account for writes; a prompt is not
containment. Await completion through the native tool and verify model/effort
metadata. A native run needs no Orca ACPX pane or acpx log.

Use acpx when compatibility cannot be established, the user requests an external
process, or acpx session/flow controls are required. An unavailable native tool
permits external execution of the same resolved request, not a model downgrade
or paid fallback. If the selected route is native-only and no compatible native
child exists, report that limitation explicitly.
For a native catalog choice, the helper can supply a matching `external_route`
and `external_model` when another eligible ACP harness advertises the same model
and effective thinking. Use that prevalidated fallback; it preserves the request
and does not introduce paid access.

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

## Launch an external one-shot task

Use the exact `acpx_agent` string returned by `show`; it rechecks cache age,
configuration, and paid-access authorization before launch. This also carries
`--allow-stale` on an authorized stale-cache retry. Put substantial prompt text
in a file to avoid shell-quoting errors. Claude Code
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
  --agent "$acpx_agent" exec -f "/tmp/acpx-$slug.prompt.md" > "$log" 2>&1
```

Codex, cursor-agent, and pi show progress natively, so run acpx directly in
those harnesses. Keep the redirect for read-only work when its audit needs a
log.

Use `exec` for one-shot work. Use a named session when later prompts must keep
the same context. Put global flags before `exec` and `-f`/`--file` after it;
`-f -` reads stdin. Use `--agent` with the returned guarded command instead of a
positional shortcut, preserving explicit stale/paid flags. Set `--format` explicitly so a project
`.acpxrc.json` cannot silently change the output shape. Set a timeout that fits
both the calling harness and background work that outlasts the command timeout.

Use `--format text` by default. For scripts, use `--format json --json-strict`.
Never use `--format quiet`: it hides progress and thinking that reveal a stuck
run.

### Inside Orca: the shared ACPX view

For external execution, when Orca provides a terminal handle or worktree ID and `--inline` is absent, every harness
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
  --agent "$acpx_agent" exec -f "/tmp/acpx-$slug.prompt.md"
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
  `agent_clis` and the cached evidence-backed selection determine eligible routes.
- Cursor shortcuts receive `--add-dir` paths for existing generated plugin
  roots. Exact paths are readable, but workspace glob and grep do not discover
  those files. Name each file the delegate needs.
- Codex shortcuts set the exact model and resolved thinking through `CODEX_CONFIG` JSON.
  `codex-acp` ignores `-c` during ACP startup.
- Claude shortcuts set exact model and effort in their environment, including
  the backing ID for a normalized model alias. Work routes through Vertex;
  non-work prefers subscription access.
- Direct APIs, OpenRouter, and local providers use `omp acp` with an
  explicit provider and model. Pi discovery supports native children; it has no
  installed ACP adapter. Gemini uses `gemini --acp` when compatible.
- Claude ACP sees user plugin skills only when
  `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` reaches its shell environment.
- Local preference preserves the requested model family. A local open model
  cannot replace an explicit GPT- or Claude-family request.

## Named sessions and flows

Read [the acpx command surface](../acpx-cli/SKILL.md) for named sessions,
`sessions ensure`, same-prompt comparisons, queues, cancellation, permission
policy shapes, and durable multi-step flows.
Before reusing a named session, verify its recorded model and thinking still
match the resolved request; a refreshed cache does not change an existing
session's model. Report a mismatch instead of silently reusing that session.

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
metadata confirms the resolved model and thinking ran. For external execution,
confirm the guarded command and routing report match
the launched model and effort. If `-w` was absent, account for every logged
tool call and report every write. An unavailable shortcut must fail explicitly;
choose a replacement only with the user's direction.
