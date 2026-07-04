# acpx Conventions (Skill-like)

## Purpose

Use this playbook to run another coding agent from inside a session via
`acpx`, a headless ACP (Agent Client Protocol) CLI for agent-to-agent work.
The full command surface lives in the vendored `acpx` skill (utils-agent);
this doc covers the local model shortcuts and when to reach for them.

## When to use

- You want a second opinion or a parallel worker from a different model
  (e.g. "have GPT review this", "ask Opus to draft the plan").
- You need a one-shot answer from a specific model without leaving the session.
- You are scripting a multi-agent step and want machine-readable output.

Skip it for normal in-session work — these shortcuts spawn a *separate* agent,
they are not a way to switch your own model.

## Model shortcuts

Defined in `~/.acpx/config.json` (`agents` map). Each pins a model + reasoning
tier. The `agpt*`/`aopus*`/`agemini` shortcuts run through `cursor-agent` as
the ACP adapter, with the reasoning tier encoded in the model id itself; where
`cursor-agent` is absent, `agpt*` fall back to the Codex adapter (`codex-acp`,
GPT model from `~/.codex/config.toml`). The `afable*` shortcuts run Claude Code
through `claude-agent-acp`, with the model and effort pinned via
`ANTHROPIC_MODEL` and `CLAUDE_CODE_EFFORT_LEVEL` env vars in the entry (the
adapter takes no model/effort CLI args).

| Shortcut     | Model                                   | Use for                            |
| ------------ | --------------------------------------- | ---------------------------------- |
| `agpt`       | `gpt-5.5-high-fast`                      | Best general GPT, high reasoning   |
| `agpt-extra` | `gpt-5.5-extra-high-fast`               | GPT for the hardest problems       |
| `aopus`      | `claude-opus-4-8-thinking-xhigh-fast`   | Best Claude, xhigh thinking, 1M ctx |
| `aopus-max`  | `claude-opus-4-8-thinking-max-fast`     | Claude at max thinking, 1M ctx     |
| `afable`     | `fable` at `xhigh` effort               | Claude Code on Fable, xhigh effort |
| `afable-max` | `fable` at `max` effort                 | Claude Code on Fable, max effort   |
| `agemini`    | `gemini-3.1-pro`                        | Best Gemini                        |

Invoke by name: `acpx <name>` is enough, since the model is baked into the
config. The config is templated per machine, so it emits only the shortcuts
whose backing CLI is present (machines.toml `agent_clis`); a box without
`cursor-agent` won't list the `agpt*`/`aopus*`/`agemini` entries.

## Defaults

- One-shot, no saved state: `acpx <name> exec '<prompt>'`.
- Quiet final answer only: `acpx --format quiet <name> exec '<prompt>'`.
- Machine-readable for scripts: `acpx --format json --json-strict <name> exec '<prompt>'`.
- Persistent multi-turn session in a repo: `acpx <name> 'prompt'` (auto-resumes
  by `(agent, cwd, name)`; bootstrap with `acpx <name> sessions ensure` first).
- Permission mode defaults to `approve-reads` (reads auto-approved, writes
  prompt). Add `--approve-all` only for trusted automation, `--deny-all` /
  `--no-terminal` for review-only.

## Examples

```bash
# One-shot cross-model review
acpx --format quiet agpt exec 'Review the diff in src/auth/ for security issues.'

# Ask Opus to draft something, machine-readable
acpx --format json --json-strict aopus exec 'Draft a migration plan for X.' > plan.ndjson

# Compare the same prompt across models
acpx compare agpt aopus agemini 'Summarize this repo in 3 lines.'

# Inspect what is configured
acpx config show
```

## Crit review bridge

crit's per-comment "send to agent" button dispatches the comment to whatever
`agent_cmd` names in `~/.crit.config.json`. It is wired to
`~/.local/bin/crit-agent`, which runs an acpx agent **reply-only**: reads are
auto-approved for context, but `--no-terminal --non-interactive-permissions
deny` refuse writes, so the agent suggests a reply and never edits the tree.
crit posts the wrapper's stdout back as the reply; the human or the original
in-session agent applies any change.

crit sends no model choice, so the wrapper picks one (first match wins):

1. `CRIT_AGENT_MODEL`: explicit host-local override (`.envrc` / mise), any acpx
   shortcut.
2. Launcher-aware contrast: a model unlike whoever started the crit daemon, read
   from `AI_AGENT` / `CLAUDECODE`. The GPT target is `agpt` (cursor-agent, or the
   Codex adapter where absent); the Claude target is `aopus` with `cursor-agent`,
   else `afable`.
3. Machine default: the GPT-family target above, baked into the wrapper at apply
   time from machines.toml `agent_clis`. A machine with no agent CLIs can't
   dispatch, and the wrapper says so.

Both the wrapper and the acpx shortcut list derive from the same `agent_clis`
overlay, so the bridge stays independent of the acpx config. Full design in the
dotfiles repo: `docs/plans/crit-agent-bridge-plan.md`.

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

- The `cursor-agent` model ids match `cursor-agent --list-models` (the catalog
  drifts; if a shortcut errors on an unknown model, refresh the id in
  `~/.acpx/config.json`). The `afable*` entries use the `fable` alias, which
  tracks the latest Fable release on its own.
- `acpx config show` lists the shortcuts for this machine's `agent_clis`: all
  seven where `cursor-agent` and `claude` are both present, `afable*` only on a
  claude-without-cursor-agent box, none where `agent_clis` is empty.
- The shortcut actually ran on the pinned model (ask it; or check session
  metadata) — `cursor-agent` must honor `--model <id> acp`, and the `afable*`
  entries need `claude-agent-acp` on PATH.
- No write action was taken by the spawned agent without an appropriate
  permission mode.
