---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-30
updated: 2026-09-30
related:
  - ../plans/agent-clis-consolidation-plan.md
  - 0012-config-gating-convention.md
  - 0020-apply-reconciles-plugin-installs.md
  - 0027-codex-standalone-installer.md
  - 0029-claude-code-native-installer.md
  - 0032-acpx-model-routing.md
---

# ADR 0041 — agent_clis is the single per-machine agent declaration

## Decision

`agent_clis` in `machines.toml` lists every AI agent CLI a machine gets. A
catalogue, `home/.chezmoidata/agents.toml`, describes each id: binary, install
mechanism, adapters, config paths, Orca agent id, plugin support, and the acpx
harness it satisfies. `features.tmpl` rejects an id the catalogue does not know.

Every surface that installs, gates, or configures an agent CLI derives from the
selection: the mise harness entries, the `codex-acp` formula, the Claude,
Codex, and cursor-agent install hooks, the `.codex`, `.pi`, and
`.cursor/cli-config.json` gates, the plugin reconcile hooks, and Orca's agent
picker. acpx keeps its own route declarations; the render fails when a declared
route's harness CLI is not selected.

## Rationale

Before this decision the same question, "does this machine have agent X", had
four answers: `agent_clis` for Claude, the `codex` package group for Codex, an
unconditional mise entry for omp, pi, and gemini, and nothing at all for
cursor-agent. The gaps were not theoretical: omp was installed on the work
laptop where Cortex XDR terminates it on launch, cursor-agent was declared on
two machines and installed on one by hand, and Orca offered every binary it
could find. One validated list with one catalogue makes the per-machine agent
set a fact that templates, hooks, and tests can all read.

acpx routes stay separate because they answer a different question, which
harness and provider serve a model family, and their preference order is
policy, not inventory: deriving the agent set from routes would make omp the
default agent wherever local inference sorts first. Package groups were not the
right home either; they are Homebrew-shaped and agents install through three
mechanisms.

## Consequences

- Adding an agent means one catalogue entry and one list edit; a typo fails the
  apply instead of silently doing nothing.
- `packages.retired` stays Homebrew-only; the mise hook removes a delisted
  catalogue agent itself.
- On `managed_allowlist` machines the catalogue records an install mechanism
  the allowlist may not run; the allowlist remains the authority on which hooks
  execute there.
- ADR 0027's gate moves from the `codex` package group to `agent_clis`; the
  standalone-installer decision itself is unchanged.
