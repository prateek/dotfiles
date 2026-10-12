---
status: archived
doc_type: plan
created: 2026-10-12
updated: 2026-10-12
related:
  - ../adr/0049-official-agent-plugin-marketplaces.md
  - ../research/agent-skill-collection-audit.md
  - ../references/agent-marketplace.md
closed: 2026-10-12
current_guidance: ../references/agent-marketplace.md
status_detail: "Implemented and host-verified; restart existing sessions and reload Pi to discover the changed plugins."
---

# Additional maintainer marketplace plugins

Use the maintainers' native marketplaces for UI/UX Pro Max, Crit, and Better
Writing wherever the client accepts their catalogs. This follows
[ADR 0049](../adr/0049-official-agent-plugin-marketplaces.md) and the
[collection audit](../research/agent-skill-collection-audit.md). The user
confirmed these three candidates, rather than the three locally customized
upstream derivatives identified in the same audit.

## Scope and first functional slice

Declare `ui-ux-pro-max@ui-ux-pro-max-skill` and `better-writing@forjd` for Claude,
OMP, and Pi. Crit already uses `crit@crit` there. Install and verify the two new
native plugins before replacing the mixed local packages on the host.

Split UI/UX imports out of `design`, leaving authored `devtool-ui` available in
both clients. Split Better Writing out of `core`, leaving the writing router
and other core skills. The split adapters are eligible only for Codex. Its
current native marketplace discovery cannot consume these upstream catalogs.

Use collection payloads for UI/UX and Crit adapters. Keep their patches and
Crit's hook payload, subject to the existing Codex hook suppression. Better
Writing's Codex adapter keeps its paired explicit-only controls. Native
Claude/OMP/Pi installs use upstream content: UI/UX lacks our local icon fixes,
and Better Writing uses upstream invocation behavior. UI/UX remains disabled;
Better Writing is enabled as the imported skill previously belonged to active
core. Crit remains enabled.

Update the writing router to discover Better Writing from the client skill
catalog and resolve reference paths relative to that skill. It must not retain
a relative link to a removed sibling skill or assume a native cache path.

## Acceptance and verification

- No UI/UX or Better Writing duplication in Claude/OMP/Pi package selection.
- Authored core/design skills remain available under their existing identities.
- Codex retains the patched adapters with the declared enabled defaults.
- Crit's collection conversion preserves all existing skill and hook bytes.
- Packaging, consumer/config, and native installation checks pass.
- Native inventories and both Codex profile caches match the declared versions
  and enabled states; unrelated user plugins remain installed.
- Pi desired state is applied and verified. Existing sessions and its extension
  still need a reload; runtime model/service evaluation is outside this work.

## Recovery

The validated preceding artifact is retained at
`~/.agents/plugins.before-additional-upstream-marketplaces-20261012`.
Restore matching source and both policy files together, then follow the
[rollback procedure](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md).
Native marketplace installs and Pi configuration require their own reversal;
restoring the artifact alone does not restore prior native selection.

## Completed rollout

Claude and OMP inventories confirmed Better Writing 2.0.0 and Crit 1.8.14 enabled,
and UI/UX Pro Max 2.13.0 disabled, each from its maintainer's marketplace. Both
clients have all 21 declared local/upstream installations. Pi desired state was
applied and verified; its extension was not reloaded.

Canonical and Orca Codex profiles have all 19 declared installations, including
Better Writing and UI/UX adapters. All 1,508 local cached files per profile match
the materialized source bytes and modes. `core` contains no Better Writing copy;
`design` contains only authored `devtool-ui`. Crit's collection conversion
preserves all six existing plugin files byte-for-byte and mode-for-mode.

Packaging passed 57 tests and deterministic rebuild checks; combined
consumer/config/upstream-policy checks passed 53 tests. The isolated native
Claude/Codex scenario passed installation, skill discovery, update, stale-file
removal, relocation, rollback, and Git marketplace transport, preserving an
unrelated plugin. Its obsolete fixed roster was replaced with per-client
selection checks while retaining those guarantees.

The final scoped script-36 apply succeeded. Native inventories, enabled states,
artifact receipts, Pi desired state, documentation lifecycle, skill frontmatter,
and whitespace checks passed. Source changes remain uncommitted. Runtime model
calls and service-backed skill evaluation were not performed.
