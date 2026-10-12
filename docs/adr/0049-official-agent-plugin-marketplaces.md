---
status: accepted
doc_type: adr
created: 2026-10-11
updated: 2026-10-12
related:
  - ../plans/upstream-agent-plugins-plan.md
  - ../references/agent-marketplace.md
  - 0023-apm-agent-marketplace-packaging.md
status_detail: "User chose official marketplaces wherever the client supports them."
---

# ADR 0049: Prefer official agent plugin marketplaces

Install upstream plugins directly from official marketplaces when the selected
client can consume the catalog. Prefer the upstream maintainer's own repository
or marketplace over curated mirrors and third-party aggregators. Declare the
source, plugin identity, client
eligibility, and enabled default in `agent_upstream_plugins.toml`. Native CLIs
own registrations, payload caches, and installation state. Git marketplaces
follow upstream main, with explicit native updates during maintenance. A
compatible source must honor the declared enabled default as well as install
the plugin. Codex's built-in remote catalog does not honor local enabled
settings, so disabled Superpowers uses the maintainer's native Git catalog
instead. This retains the upstream plugin and metadata without a local wrapper.

Keep `agent-marketplace/` for authored skills, reviewed local customizations,
and compatibility adapters. Use whole collection selections for adapters when
the entire upstream skill collection is wanted. Do not maintain a list of
individual skills merely to reconstruct an available plugin.

## Why

The prior shared artifact repackaged Matt Pocock's 24 selected skills, 47
Pstack skills, and 45 Obsidian skills from two repositories. Obsidian Wiki alone
had 40 subdirectory dependencies. Those lists omitted new skills and retained a
retired skill after an upstream update. Several providers now publish native
marketplaces that eliminate this duplicate packaging work.

The user explicitly preferred official marketplace installs over retaining
complete upstream plugins inside our reviewed artifact. This narrows ADR 0023's
shared packaging responsibility to content that still needs it.

## Consequences

Upstream plugin payloads and native metadata stay under upstream ownership.
Local patches are not silently applied to official installations. A client
without a compatible upstream catalog receives a documented local adapter;
the presence of a native manifest alone is insufficient.

Native updates can require network access and different official channels can
ship different versions. The local release receipt covers only the local
artifact. Keep native inventory evidence separately, and retain the previous
artifact until replacements are verified. Restart existing sessions after an
update.

The consumer installs upstream replacements before reconciling local orphans.
OMP requires removing a matching runtime name first; retain the previous
artifact and restore its install/default if the replacement fails.
It restores the declared enabled defaults, including after a failed refresh of
a disabled Codex plugin, and refuses marketplace source collisions. It does
not remove unrelated native plugins or marketplaces.

The [migration plan](../plans/upstream-agent-plugins-plan.md) records rollout,
compatibility exceptions, validation, and recovery boundaries.
