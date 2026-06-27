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
tier and runs through `cursor-agent` as the ACP adapter. Reasoning tier is
encoded in the model id itself.

| Shortcut  | Model                              | Use for                         |
| --------- | ---------------------------------- | ------------------------------- |
| `agpt`    | `gpt-5.5-high`                     | Best general GPT, high reasoning |
| `aopus`   | `claude-opus-4-8-thinking-max`     | Best Claude, max thinking, 1M ctx |
| `agemini` | `gemini-3.1-pro`                   | Best Gemini                     |

Invoke by name; `acpx <name>` is enough — the model is baked into the config.

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

## Prerequisites

- `acpx` CLI: installed via mise (`npm:acpx`).
- `cursor-agent` on PATH: backs every shortcut. Installed via its own installer
  (`~/.local/bin/cursor-agent`), not mise-managed. `cursor-agent login` once.
- State lives under `~/.acpx/` (sessions, queues, flows). acpx has no XDG /
  relocation env var, so this path is fixed.

## Validation checklist

- The model ids match `cursor-agent --list-models` (the catalog drifts; if a
  shortcut errors on an unknown model, refresh the id in `~/.acpx/config.json`).
- `acpx config show` lists `agpt` / `aopus` / `agemini`.
- The shortcut actually ran on the pinned model (ask it; or check session
  metadata) — `cursor-agent` must honor `--model <id> acp`.
- No write action was taken by the spawned agent without an appropriate
  permission mode.
