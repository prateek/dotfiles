---
status: accepted
doc_type: adr
created: 2026-07-02
owner: Prateek
related:
  - ../plans/crit-integration-plan.md
  - ../plans/agent-plugin-renderer-plan.md
  - 0007-default-loaded-plugin-policy.md
status_detail: "Accepted with the crit re-vendor; applies to future agent tool integrations."
---

# ADR 0013 — Agent tool integrations stay APM-vendored

## Context

crit ships per-agent integration files (skills, an ExitPlanMode plan-review
hook, plugin manifests) and offers three delivery paths: its official Claude
plugin marketplace (`crit@crit`), binary-native installs (`crit install
claude-code` / `codex-plugin`), and plain files that a consumer can vendor.
This repo vendored crit's Codex-flavored skills through APM in May 2026 and
they went stale: a session audit found agents overriding the foreground-launch
guidance, improvising `--author` values, and one review killed by the Bash
10-minute cap. An earlier plan for this branch chose the native path
(marketplace for Claude, `crit install codex-plugin` at apply time), which
conflicted with the same-day decision to make APM packages the single delivery
mechanism for agent-facing dependencies.

## Decision

Agent tool integrations are delivered like every other agent-facing
dependency: APM-vendored into a package under `home/dot_agents/packages/`,
reviewed, committed, and projected by the renderers.

For crit specifically:

- The review package vendors `integrations/claude-code/skills/{crit,crit-cli}`
  (the variant matching real usage; session data showed crit use is entirely
  Claude-side).
- The ExitPlanMode → `crit plan-hook` hook ships as a reviewed
  `PermissionRequest` block in `claude-settings-managed.json.tmpl`, merged by
  the settings modify script. The managed fragment owns that hook list; other
  hook events pass through untouched.
- Intentional divergence from upstream is recorded as a "Local delta" note in
  the vendored skill's SOURCE.md and re-applied after each re-vendor until
  upstream takes the fix.
- Upgrading the crit binary (`mise run crit:use ...`) pairs with re-running
  `vendor-agent-package review`, because the skills reference subcommands that
  must exist in the installed binary.

## Alternatives

- **Official marketplace (`crit@crit`)**: always release-fresh and carries the
  hook, but installs are a GitHub fetch with no committed copy and no review
  gate — the "trust a moving upstream" model the vendor pipeline exists to
  prevent. Rejected.
- **Binary-native installs at apply time**: offline and perfectly
  version-matched (integrations are embedded in the binary), but the written
  files are tool-owned and unreviewed, and they land inside renderer-owned
  roots that clean stale files, requiring carve-outs. Rejected.

## Consequences

- Vendored integration skills can lag the binary between re-vendors; the
  binary's own `crit check` staleness nag and the upgrade↔re-vendor pairing
  bound the drift.
- Local deltas are re-applied manually after re-vendoring until upstreamed.
- The renderer needs no hook projection for crit; the managed settings
  fragment carries it. Broader payload support is the
  [Agent Plugin Renderer plan](../plans/agent-plugin-renderer-plan.md).
