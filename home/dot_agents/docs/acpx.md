# acpx Conventions

Use `acpx` to delegate a task to another coding agent in a separate process and
context. The vendored `acpx` skill owns the full command surface; this document
records machine-specific launch, shortcut, and safety conventions.

## Defaults

- Use `exec` for a one-shot delegation. Use a named session only when follow-up
  prompts must preserve context.
- Put substantial prompts in `/tmp/acpx-<slug>.prompt.md`.
- Use the shortcut name as the complete model selection; `agpt`, `aopus`, and
  similar names are acpx agent names, not binaries.
- Run with non-interactive permissions that fail closed. Use a hard read-only
  permission policy when writes must be impossible.
- Match acpx's timeout to the calling harness and background work that can
  outlast the harness command timeout.
- Read [acpx-harness-lanes.md](acpx-harness-lanes.md) when a run must be
  watched, relayed, cancelled, or recovered.

## Launch

Claude Code needs a redirected log for a watchable run. Launch this block as a
background shell task so the relay loop can start while acpx is running:

```sh
slug=review-auth
cat > "/tmp/acpx-$slug.prompt.md" <<'EOF'
<the prompt>
EOF
log=$(mktemp "/tmp/acpx-$slug.XXXXXX")
echo "log: $log"
acpx --format text --suppress-reads --no-terminal \
  --non-interactive-permissions deny --timeout 600 --prompt-retries 2 \
  agpt exec -f "/tmp/acpx-$slug.prompt.md" > "$log" 2>&1
```

Codex, cursor-agent, and pi run the same acpx command directly because their
native command surfaces expose progress. Omit the `log=`, `echo`, and redirect
lines for that direct lane. When starting cursor-agent manually with `&`, keep
the redirection and add `nohup`; see
[acpx-harness-lanes.md](acpx-harness-lanes.md). A direct run leaves no log
trail.

For a quick prompt that nobody needs to watch:

```sh
acpx --format quiet --no-terminal --non-interactive-permissions deny \
  --timeout 300 agpt exec 'quick question'
```

For machine-readable output:

```sh
acpx --format json --json-strict --no-terminal \
  --non-interactive-permissions deny --timeout 300 agpt exec -f prompt.md
```

Keep global flags before the shortcut name. Put `-f/--file` after `exec`; `-f -`
reads standard input. Keep `--format` explicit so a project `.acpxrc.json`
cannot silently change the output shape.

## Shortcuts

Read the actual pins with `acpx config show`.

| Shortcut | Use |
| --- | --- |
| `agpt` | Default GPT delegation or second opinion |
| `agptx` | Higher-effort GPT after `agpt` is insufficient |
| `agptw` | Prose rewriting |
| `aopus` | Default Claude for long context or deep reasoning |
| `aopusx` | Higher-effort Claude after `aopus` is insufficient |
| `afable` | Claude Code with its harness and skills |
| `afablex` | Higher-effort Claude Code |
| `agemini` | An opinion outside the GPT and Claude families |

`agptw` is the prose lane. Give it the draft and
`~/.agents/plugins/plugins/core/skills/writing-for-humans/SKILL.md`; prefer it
to `agpt` for editing prose. Its pin comes from the rewrite-model bakeoff in
`docs/research/acpx-rewrite-model-bakeoff.md` in the dotfiles checkout being
edited.

## Adapter configuration

- `agpt*`, `aopus*`, and `agemini` use cursor-agent, with model and effort in
  the configured model id.
- Those cursor-agent shortcuts receive `--add-dir` paths for the generated
  plugin roots. Files there are readable by exact path but not discoverable
  through workspace glob or grep, so prompts must name needed files.
- On machines without cursor-agent, `agpt` and `agptx` fall back to `codex-acp`
  and use its configured model. `agptw` has no fallback.
- `afable*` use `claude-agent-acp`; their environment selects the Claude model
  and effort.
- Claude ACP sees user plugin skills only when
  `ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` reaches the shell environment.
- A shortcut renders only when its backing CLI appears in the machine's
  `agent_clis` data.

The cursor-agent model ids are explicit pins. Audit them with
`scripts/audit/acpx-model-drift.sh` from the dotfiles checkout being validated;
outside a checkout, resolve the configured chezmoi source first. Bare model
aliases may resolve to older generations.

## Beyond one-shot execution

Use the vendored `acpx` skill for:

- named sessions and `sessions ensure`
- same-prompt comparisons
- queues and cancellation
- permission policies
- durable multi-step flows

Do not copy those command surfaces into this file.

## Prerequisites and safety

- `acpx` installs through mise as `npm:acpx`.
- cursor-agent-backed shortcuts require cursor-agent authentication;
  `afable*` requires Claude authentication.
- Scope cleanup to the prompt-file slug. A broad process kill can terminate
  cursor-agent's shared authentication worker while its status still reports a
  valid login.
- Sessions, queues, and flows live under `~/.acpx/`; acpx has no XDG relocation
  variable.

## Completion

- The run reaches the harness-specific completion condition.
- Session metadata or the reply confirms the intended pinned model ran.
- The process wrote nothing outside its permission mode.
- `acpx config show` agrees with the machine's rendered shortcut set.
- The model-drift audit passes after a pin or catalog change.
- The relevant launch and monitoring paths are reverified after an acpx,
  adapter, or harness upgrade.

Last verified with acpx 0.13.2, codex rust-v0.149.1, cursor-agent 2026.07.01,
and pi 0.80.3. Treat a version change as the trigger to recheck the affected
claims above.
