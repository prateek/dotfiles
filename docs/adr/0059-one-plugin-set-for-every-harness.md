---
status: accepted
doc_type: adr
summary: "Every plugin goes to every harness a machine selects in agent_clis: the per-client policy flags are gone, Codex installs upstream Claude-format catalogs natively, and local adapters exist only to carry patches we keep."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - 0049-official-agent-plugin-marketplaces.md
  - ../plans/agent-marketplace-layout-plan.md
  - ../research/agent-marketplace-adapter-layout-research.md
  - ../references/agent-marketplace.md
  - 0041-agent-clis-single-declaration.md
---

# ADR 0059 — One plugin set for every harness

## Decision

Every plugin, local or official, goes to every harness the machine selects in
`agent_clis`. `agent_plugins.toml` and `agent_upstream_plugins.toml` keep only
`default_loaded`; the `claude` and `codex` keys are gone. Harness selection is
unchanged: `.chezmoiignore` drops unselected agents' config paths
([ADR 0041](0041-agent-clis-single-declaration.md)), and apply reconciles only
selected agents that take plugins.

- **Codex installs official plugins natively** from their upstream
  Claude-format catalogs. The upstream reconciler accepts a Codex marketplace
  snapshot that holds either `.agents/plugins/marketplace.json` or
  `.claude-plugin/marketplace.json`.
- **Pi, OMP, and Cursor follow Claude's selection.** Pi and OMP read the same
  policy. Cursor loads the plugins Claude has installed and enabled.
- **Local adapters exist only to carry patches we keep.** Each kept adapter
  serves both clients and replaces the official install. Adapters without such
  a patch are retired in favour of the official plugin.
- **Retired official installs are listed explicitly** in
  `retired_agent_upstream_plugins`. The reconciler uninstalls them from every
  client, and the Claude and Pi configs pin them disabled, because their
  settings merges keep stale keys. Codex never installed them, so its config
  omits them.

This refines [ADR 0049](0049-official-agent-plugin-marketplaces.md), which
preferred official marketplaces wherever a client supported them, but kept
Codex-only adapters because Codex appeared not to read Claude catalogs.

## Rationale

No plugin or skill was meant for one harness. Every `claude = false` or
`codex = false` worked around a client: an adapter covered Codex while Claude
installed upstream, or the reverse. The workaround gave the two clients
different behavior for the same plugin, because adapters applied our patches
and official installs did not.

Codex reads `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`
(verified in its source at `rust-v0.163.0`), and every retired adapter's
upstream uses `./` plugin sources, which Codex accepts. The only blockers were
our reconciler's snapshot check and the policy flags.

## Consequences

- The local catalog drops obsidian, apple-hig, shortcut, ios-tools, and
  ui-ux-pro-max, and their dependencies leave the APM cache (about 51 MB).
- Claude now runs our patched mattpocock, crit, obsidian-wiki, and
  better-writing. Codex now runs upstream ui-ux-pro-max, including the icon
  generator our patch used to delete.
- Hooks stay harness-specific by policy: Codex manifests carry `hooks: {}`.
- Codex installing a Claude-format catalog has not yet been run live. The check
  is tracked in [`GHOST_OF_COMMITS_PAST.md`](../../GHOST_OF_COMMITS_PAST.md).
