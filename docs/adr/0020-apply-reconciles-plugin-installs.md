---
status: accepted
doc_type: adr
created: 2026-09-02
owner: Prateek
related:
  - 0007-default-loaded-plugin-policy.md
  - 0019-plugin-hooks-in-vendored-payload.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Accepted with the superpowers package on 2026-09-02; first apply on a Codex machine validates the Codex lane."
---

# ADR 0020: `chezmoi apply` reconciles plugin install records through the native CLIs

## Context

`chezmoi apply` renders the local plugin marketplace under `~/.agents/plugins`
and merges the activation policy into `~/.claude/settings.json` and
`~/.codex/config.toml`, but Claude Code and Codex enumerate plugins from their
own install records, which chezmoi never wrote. A new package therefore stayed
invisible until someone ran the commands `reconcile-agent-plugins` printed,
and a package flipped to `default_loaded = false` stayed enabled in Claude
until the matching `plugin disable` ran. Adding superpowers made that a
recurring manual step on every machine.

Verified on Claude Code 2.1.258 with an isolated `CLAUDE_CONFIG_DIR`:
declaring the marketplace in settings is not enough for `claude plugin
install` to resolve it (the CLI needs `marketplace add` once); `plugin list
--json` reports each install with its scope and enabled state; `install` is
idempotent and enables the plugin; `enable`, `disable`, and `uninstall` exit
non-zero when the plugin is already in the target state; and plugins from a
`directory` marketplace load in place, so content refreshes need no reinstall.
Codex exposes `plugin add`, `plugin list --json`, `plugin marketplace`, and
`plugin remove`, with enablement living in `config.toml`; it copies plugins
into its cache, so `add` doubles as the content refresh.

## Decision

`reconcile-agent-plugins --apply --agent <cli>...` converges each CLI's
records, and `run_onchange_after_36-agent-plugins.sh.tmpl` runs it right
after rendering the marketplace, for every CLI in the machine's `agent_clis`.
The CLIs remain the only writers of their install records and caches.

- Claude: register `prateek-local` when `marketplace list --json` lacks it;
  install each rendered package missing from `plugin list --json`; toggle
  enable state to match `default_loaded` only when it differs; uninstall
  `@prateek-local` records for packages that no longer render. Commands run
  from `$HOME` so project-scoped plugin settings do not colour the state.
- Codex: `plugin add` every default-loaded package on each run (the cache
  refresh) and `plugin remove` orphaned `@prateek-local` records. Disabled
  packages are not added because `add` also writes `enabled = true`, which
  the config merge would only correct on the next apply.
- A CLI listed in `agent_clis` but missing from `PATH`, or any failing CLI
  command, fails the script. chezmoi then retries on the next apply instead of
  recording the run as done.
- The flag-less invocation still prints the full command list for a human.

## Consequences

- On Claude no post-apply step remains, and per-project enablement of a
  disabled package works as soon as apply has run. On Codex a disabled
  package still needs a manual `codex plugin add` (then a config re-apply)
  before a project override can load it, because `add` also enables and
  Codex has no disable verb; the SKILL.md override recipe says so.
- The Codex lane is written from the CLI reference and cannot run on the
  work laptop (no Codex there); the first apply on a personal machine is its
  live check.
- The reconcile runs only when script 36's inputs change (renderer,
  reconciler, package tree). Hand-uninstalling a plugin is not repaired until
  the next such change or a `chezmoi state delete-bucket --bucket=scriptState`.
- Machines whose `agent_clis` is empty (the `ci` type, and the test harness
  built on it) skip the step and never shell out to a CLI.

## Alternatives considered

- **Keep the preview-only helper.** Zero risk to tool-owned state, but every
  package change needs the same manual sequence on every machine, and the
  disabled-by-default policy is only as good as whoever remembers the
  `disable` half.
- **Write `installed_plugins.json` and the cache from chezmoi.** Removes the
  CLI dependency, but forges records whose schema both tools change without
  notice; ADR 0007's boundary against editing tool-owned paths stands.
- **A separate always-run script for self-healing.** Better repair of
  hand-made drift, at the cost of a CLI round trip on every apply; the
  onchange trigger covers the cases the repo actually produces.
