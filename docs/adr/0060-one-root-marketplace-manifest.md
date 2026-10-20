---
status: accepted
doc_type: adr
summary: "agent-marketplace/marketplace.toml holds every plugin's version, native manifest, and selections; the build generates each plugin.json, and src/<plugin>/ holds only hand-written files."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - 0025-shared-apm-acquisition.md
  - 0059-one-plugin-set-for-every-harness.md
  - ../plans/agent-marketplace-layout-plan.md
  - ../research/agent-marketplace-adapter-layout-research.md
  - ../references/agent-marketplace.md
---

# ADR 0060 — One root marketplace manifest

## Decision

`agent-marketplace/marketplace.toml` is the single authored manifest for the
local marketplace. It holds:

- the catalog's identity and version;
- one `[plugins.<name>]` table per plugin, in catalog order, with the plugin's
  version and native manifest. The manifest is either `display_name` for the
  shared template, or a verbatim `[plugins.<name>.manifest]` table;
- the plugin's selections from the APM cache, as `[[plugins.<name>.skills]]`
  and `[[plugins.<name>.payloads]]`, plus `mirror_invocation_controls`.

The build generates every `.codex-plugin/plugin.json` in one canonical key
order, and rejects keys outside it. Per-plugin `publish.toml` and
`plugin.json` files no longer exist. The build refuses one left in `src/`.
`src/<plugin>/` holds only hand-written files (skills, patches, overlays,
evals) and exists only when a plugin has some. Version bumps from the skill
console and the skill-rewrite flow edit the plugin's table as text.

This refines [ADR 0025](0025-shared-apm-acquisition.md), whose per-plugin
directories held selections and native metadata. Its shared acquisition, the
committed cache, and patches applied per plugin are unchanged.

## Rationale

Nine of the twelve plugin manifests were the same template with a different
display name, and per-plugin metadata files changed in 42 commits in six weeks,
almost all version bumps. One file makes the catalog, its order, every version,
and every selection reviewable in one place. Adapters no longer need a
directory just to hold two small files.

## Consequences

- Concurrent version bumps on different plugins touch one file. They edit
  separate tables, so they usually merge cleanly.
- Two console sessions that edit different plugins write the same file. The
  console's recheck before writing makes the second re-plan, which is the safe
  outcome.
- crit's generated manifest moved `hooks` ahead of `interface` to fit the
  canonical order. Its version was bumped for that change alone.
