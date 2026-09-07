---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - ../plans/apm-agent-marketplace-plan.md
  - ../research/apm-modules-vendoring-research.md
  - ../research/apm-skill-marketplace-spike.md
  - 0007-default-loaded-plugin-policy.md
  - 0013-apm-vendored-tool-integrations.md
  - 0019-plugin-hooks-in-vendored-payload.md
  - 0020-apply-reconciles-plugin-installs.md
current_guidance: ../references/agent-marketplace.md
status_detail: "Accepted after review: isolated folder/Makefile, committed APM modules, separate content scanning, Git recovery, and no generated SOURCE.md files. Native acquisition, payload parity, portable builds, and isolated native recovery are verified; rollout remains in the plan."
---

# ADR 0023: Isolate marketplace packaging and commit APM module inputs

Keep a portable `agent-marketplace/` project at the dotfiles repository root,
with its own Makefile and tool pins. Use native APM commands to acquire
dependencies and commit the accepted `apm_modules/` trees with their locks.
Build separate native plugins and both marketplace catalogs from that source;
consumer adapters own materialization and activation.

## Why

The owner wants Git review of upstream changes and access to accepted bytes
during upstream deletion or hosting outages. Committing APM's fetched trees
preserves that property while retiring our separate vendored-copy workflow.
A root project with its own Makefile can build independently of chezmoi or a
future Nix consumer.

The [executed spike](../research/apm-skill-marketplace-spike.md) demonstrated
APM native source publication with full payload preservation. Its bundle
exporter could omit required supporting files. The
[module-source research](../research/apm-modules-vendoring-research.md) identifies
`apm lock` and `apm lock --update` as native acquisition commands that skip
agent deployment. Exercising that replacement workflow remains a migration gate.

## Boundaries and consequences

APM owns resolution, downloads, lock data, and its normalized module layout.
Git records acceptance of the complete fetched tree. Authored skills and
local patches/overlays live outside the cache: APM may replace modified
cache entries. Normal builds read accepted inputs and never acquire missing
dependencies. Missing committed files are restored from Git or a complete
source export; acquisition requires clean cache and lock inputs.

The APM lock records upstream repositories and resolved revisions. Retire
our generated `SOURCE.md` files and their readers, without adding replacement
provenance files. Patches/overlays carry local deltas, replacing ADR 0013's
`SOURCE.md` local-delta notes. Preserve upstream license and notice files.

A bounded publication step selects content, preserves curated aliases, and
applies local changes to temporary copies. It then invokes APM for Claude
manifests and both catalogs. Authored Codex metadata preserves current
interface fields and hook suppression. This retains a small assembly step
because the tested APM bundle exporter cannot preserve the whole payload.
Preserve source-surface validation and content scanning as explicit build
checks; native lock acquisition skips them. Scan the selected payload after
local changes, before making it available to consumers.

Complete plugin output is ignored and exportable. APM is required to build;
a prebuilt artifact can be materialized without it. Consumer activation policy
stays outside the packaging project, and native CLIs remain the only writers
of their install/cache records. The existing review, hook, and default-policy
intent of ADRs 0007, 0013, 0019, and 0020 remains.

This deliberately commits a directory APM normally treats as disposable.
Native lifecycle commands are restricted to explicit acquisition/maintenance,
and acceptance checks include a clean Git round-trip, cache integrity,
executable bits, and supporting files. Retaining full fetched inputs may cost
more repository space than the existing selected skill copies.

Defer our own APM registry or Git archive mirror. It can later replace the
acquisition/recovery source without changing packaging or consumer contracts.
The [migration plan](../plans/apm-agent-marketplace-plan.md) owns that TODO and
the native cache/update, export, and rollback gates. Current implementation
remains authoritative until the replacement passes them.
