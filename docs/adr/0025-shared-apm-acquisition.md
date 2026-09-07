---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - 0023-apm-agent-marketplace-packaging.md
  - ../plans/apm-agent-marketplace-plan.md
  - ../research/apm-marketplace-migration-verification.md
current_guidance: ../references/agent-marketplace.md
status_detail: "Accepted simplification: one root acquisition project and one metadata authority per native plugin."
---

# ADR 0025: Share APM acquisition across native plugins

Use one maintained `agent-marketplace/apm.yml`, one native lockfile, and one
committed `apm_modules/` tree for all upstream dependencies. Keep separate
`packages/<name>/` directories for authored skills, publication selections,
patches, overlays, and native plugin metadata. Remove per-plugin APM projects.

This refines [ADR 0023](0023-apm-agent-marketplace-packaging.md) and the
[migration plan](../plans/apm-agent-marketplace-plan.md). Its isolation, Git
acceptance, offline build, and consumer boundaries remain in force.

## Why

Plugin grouping determines what a client can install and enable. It does not
require separate dependency graphs or fetched copies. A shared acquisition
project gives dependencies one declaration and accepted resolution even when
several plugins select them. It also removes repeated lock and cache maintenance.

The owner requested one APM manifest and authorized removing the per-plugin
structure without a compatibility migration. Plugin IDs and independent native
installation remain part of the output contract.

## Metadata and publication

Each plugin's `.codex-plugin/plugin.json` is authoritative for its name, version,
shared descriptive metadata, and Codex interface fields. The build derives an
APM publication manifest in temporary output, uses native APM to generate the
Claude manifest and both catalogs, then removes the temporary APM manifests.
Consumers receive native payloads and a release receipt without acquisition data.

The temporary manifests select native Claude publication and carry no dependency
key. Acquired content is selected from the shared cache before packing; local
patches apply independently to each plugin's temporary copy. No new dependency
resolver or curated source store is introduced.

## Maintenance consequences

`make fetch` and `make update` run native APM at the project root. Updates cover
the shared graph and require review of every affected plugin's output. Bump only
the affected plugin's Codex manifest version; native publication derives matching
Claude metadata. The removed `PACKAGE` selector is rejected to prevent silently
expanding the scope of an old update command.

Before removing a dependency, check skill and supporting-payload selections in
every plugin, including disabled ones. Console deletion checks repeat immediately
before writes. Unselected cache content is retained until explicit native prune;
ordinary builds and console edits do not mutate accepted inputs.

A shared identity has one accepted revision across plugins. Independent pinned
versions of the same dependency are outside this contract. Git and complete
source exports retain reviewed bytes; a private APM registry or mirror remains
future work.

The [verification record](../research/apm-marketplace-migration-verification.md#shared-acquisition-follow-up)
tracks native lock replay, unchanged input bytes and modes, independent plugin
publication, and consumer checks for this refinement.
