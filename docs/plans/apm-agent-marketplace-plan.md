---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-06
updated: 2026-09-07
related:
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../research/apm-marketplace-migration-verification.md
  - ../references/agent-marketplace.md
  - ../research/apm-modules-vendoring-research.md
  - ../research/apm-skill-marketplace-spike.md
  - ../research/agent-marketplace-packaging-tools-research.md
  - ../research/nix-agent-skills-packaging-research.md
  - agent-plugin-renderer-plan.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Migration landed and scoped live apply verified in Claude and both canonical and Orca Codex profiles. Required local checks, offline source transport, and isolated native recovery passed. Fresh interactive invocation checks remain a rollout step."
---

# APM Agent Marketplace Plan

Create a self-contained `agent-marketplace/` project at the dotfiles repository
root, with its own Makefile and pinned tools. Commit APM's fetched
`apm_modules/` trees alongside their manifests and locks. Keep authored skills
and reviewed local changes separately, then build ten native plugins and both
marketplace catalogs from those inputs.

APM owns dependency acquisition and metadata generation. Git owns acceptance
and recovery of reviewed bytes. The build creates a disposable marketplace
artifact; chezmoi, Nix, or another consumer can materialize that artifact.
An APM registry or mirror is a future improvement to acquisition and recovery.

This replaces the earlier proposal to maintain a separate curated source copy
under `home/.chezmoiassets/`. It also changes the output policy: complete built
plugins are ignored build output, avoiding a second committed copy of the
upstream payload beside `apm_modules`.

[ADR 0023](../adr/0023-apm-agent-marketplace-packaging.md) records the boundary.
The [module-source research](../research/apm-modules-vendoring-research.md)
supports the acquisition proposal; the
[executed spike](../research/apm-skill-marketplace-spike.md) establishes native
publication behavior. The current
[management skill](../../.agents/skills/agent-skill-management/SKILL.md) routes
current operations and validation.

## Evidence and limits

| Finding | Consequence |
| --- | --- |
| The executed APM 0.29.1 spike preserved 1,471 payload files and modes, 124 provenance files, and 22 paired invocation policies. | Capture a fresh baseline. Preserve payload behavior and invocation policies; omit our generated `SOURCE.md` files as an approved change. |
| Claude discovered 158 top-level skills; Codex discovered 162, matching the current renderer. | Compare per-plugin inventories. The four nested trycycle skills are existing Codex behavior. |
| Native source publication generated both catalogs offline; bundle export dropped helpers/provenance or rejected evals. | Keep native directory publication. Committing the cache does not repair the bundle exporter. |
| Pinned source shows `apm lock` resolves/downloads into APM storage without deploying agent files; `apm lock --update` refreshes refs. | Prefer this public command over a repo-owned acquisition/copy pipeline. Validate its behavior against our dependencies first. |
| APM treats `apm_modules` as a rebuildable cache, checks cached content hashes, and can replace edited entries. | Commit the accepted cache deliberately; keep local deltas outside it and keep acquisition out of ordinary builds. |
| APM cache hashes omit symlinks and executable modes. | Retain independent path-containment and executable-bit checks. The lockfile alone does not cover the complete published artifact. |

The [implementation verification](../research/apm-marketplace-migration-verification.md)
records executed native acquisition, all 60 accepted inputs, 1,347 retained
payload files, full source Git/archive transport, network-denied builds, native
installation/update/rollback, and local Git distribution. Source inspection used
`ask src github:microsoft/apm@v0.29.1`, resolving to
`1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc`.

The portable source/build project and consumer adapters are implemented in this
checkout. Current operations are documented in the
[marketplace reference](../references/agent-marketplace.md). All required local
checks passed. Commit `f085615` landed, and the authorized scoped live apply
verified version 1.1.0 payloads, native inventories, and enabled states in Claude
and both canonical and Orca Codex profiles. Fresh native Codex processes found
all 162 skills. Fresh interactive invocation checks remain; the
[rollout record](../research/apm-marketplace-migration-verification.md#live-cutover)
distinguishes live evidence from the isolated implementation tests.

## Folder and ownership

Keep everything required to build and test the marketplace inside
`agent-marketplace/`. Its Makefile must work after that folder is copied
outside dotfiles. Root-level Make targets may delegate into it. Host policy,
chezmoi hooks, and native install reconciliation remain consumer adapters
outside the packaging project.

This is an explicit exception to the current rule placing machine-wide
package source under `home/`: the root folder is a portable publishing
project. Update the repo's source-location guidance during implementation.
Keeping it outside the chezmoi source root also permits native filenames
without `literal_` escapes.

```text
agent-marketplace/
  Makefile
  mise.toml                       pinned build/test tools
  README.md                       authoring, review, build, export
  apm.yml                         marketplace publication recipe
  scripts/                        small build/check helpers
  tests/                          packaging and cache-contract checks
  packages/
    core/
      apm.yml                     plugin metadata + devDependencies.apm
      apm.lock.yaml               APM-owned accepted resolution
      apm_modules/                committed APM-fetched content and receipts
      skills/<skill-id>/...       authored skill source only
      .codex-plugin/plugin.json   authored compatibility/UI metadata
      publish.toml                only needed selections, aliases, extra files
      patches/                    reviewed edits at published native paths
      overlays/                   local additions to published payload
    review/
      ...
    ...eight more packages...
  build/                          ignored
    marketplace/
      .claude-plugin/marketplace.json
      .agents/plugins/marketplace.json
      plugins/<package>/...
home/.chezmoidata/agent_plugins.toml   consumer policy
```

Use one APM project per existing package. Preserve APM's module paths and
normalization receipts, including `.apm-pin`. These committed trees are the
accepted dependency inputs. Local edits are patches or overlays applied to
temporary build copies, so an APM refresh cannot erase them.

Use APM's own dependency/skill metadata for selection wherever it suffices.
`publish.toml` records only publication details APM cannot express for our
grouping: curated aliases, selected source paths, and supporting files.
It must not become a second dependency manifest or resolver.

Use `apm.lock.yaml` for upstream repository identity and resolved revisions.
Git records acceptance; patches and overlays hold local changes. Retire our
generated `SOURCE.md` files without adding a replacement provenance file or
directory. Preserve upstream files, including license and notice files.

A small assembly step remains necessary: combine local skills with selected
APM module content and copy complete hook/helper/eval trees into native plugin
directories. It owns no downloads, dependency resolution, lock updates, or
second curated source store. Start with Make recipes and simple file copies;
add a helper only where repeated copying, path checks, or patch application
needs one.

APM generates Claude manifests and both catalogs inside the assembled output.
Keep `targets: [claude]` on package manifests and acquisition refs under
`devDependencies.apm`. Omit `dependencies` entirely in publication manifests;
`dependencies: {}` selects the unsuitable bundle path. Copy the root
publication recipe into the output before packing; its relative
`./plugins/<package>` paths describe that output.

Preserve authored Codex manifests for all existing packages so their current
interface metadata survives. Every Claude hook-bearing package retains
`hooks: {}` under the current skills-only Codex policy. Validate shared
names and versions against APM metadata. APM has no Codex manifest generator;
the earlier two minimal overrides established hook suppression only.

## Makefile contract

These are the project-local target contracts. Verify exact APM command
behavior in phase 1 before production use.

| Command | Contract |
| --- | --- |
| `make -C agent-marketplace fetch PACKAGE=core` | Run native `apm lock` for the selected package to acquire declared/locked inputs. Require a clean accepted cache and lock; acquisition may replace content and need network. |
| `make -C agent-marketplace update PACKAGE=core` | Run native `apm lock --update`; leave cache/lock changes visible for Git review. Require a clean accepted cache and lock before replacement. |
| `make -C agent-marketplace build` | Validate committed inputs, assemble and scan native plugin trees, and run offline APM manifest/catalog generation. Never fetch missing inputs. |
| `make -C agent-marketplace check` | Check source/cache/patch contracts and a fresh build, including content scanning, versions, and repeatability. Wire this into required local/CI checks. |
| `make -C agent-marketplace export` | Archive the complete validated marketplace for native consumers. Refuse unchecked or stale build output. |
| `make -C agent-marketplace clean` | Remove only disposable output. Keep committed modules, locks, source, and local deltas. |

Build each assembled plugin with `apm pack --offline --force`, then run
`apm pack --offline` at the assembled marketplace root. The root command does
not build children. Offline acceptance uses network denial; a flag alone does
not establish that the complete build avoids the network.

The source tree needs pinned APM to build. Materializing an already built
artifact needs no APM. Chezmoi may orchestrate build followed by copy, but
that makes APM a prerequisite for that build-on-apply path. Keep this explicit;
the previous proposal's APM-free apply depended on committed final output.

## Work sequence

Execute the phases in order. Preserve an isolated baseline checkout with the
old renderer, source library, and payload until native acceptance passes.
Capture useful evidence in these docs and keep disposable probes out of the
committed project.

### 1. Verify native acquisition and committed-cache replay

Provision APM 0.29.1 through Mise and resolve its executable before isolating
fixtures. Retain the normal Mise data directory; changing it while leaving
old shims on PATH caused the earlier setup incident. Bound subprocess
execution and clean up probe process groups.

Exercise `apm lock` and `apm lock --update` in a disposable project containing
a virtual skill dependency and a whole plugin with hooks. Verify module
content, locks, receipts, unchanged agent targets, and repeat invocation.
Confirm that development dependencies are acquired and that missing or failed
downloads produce a failure the Make target propagates.
Both fetch and update must refuse a dirty cache/lock before APM runs, including
pending acquisition changes. Plain lock generation can replace a modified
cache entry too. Exercise that refusal through the public Make targets.

Check Git's view of the cache, including hidden normalized files, upstream
ignore rules, and intentionally tracked dependencies. APM's normal install
adds an ignore rule for `apm_modules`; lock-only mode skips that mutation.
Where an install fallback is needed, an exact ignore rule followed by scoped
re-inclusion rules can preserve the chosen Git policy. Inspect additions
explicitly: upstream nested `.gitignore` files can still hide cached files.

Completion: a Git archive/clean checkout contains every accepted cache file and
executable bit, including receipts; cache directories are ordinary tracked
content rather than nested Git repositories/submodules. Acquisition behavior
is recorded as executed evidence. If the native command cannot preserve the
required input, stop this migration at the documented gap instead of
reintroducing the old vendoring engine under a new name.

### 2. Bootstrap accepted modules and separate local changes

Capture current package IDs, policy, native metadata, per-plugin inventories,
and a full payload/path/mode baseline from the existing renderer. Record the
source revision and actual Claude/Codex versions. Treat the earlier counts as
a historical cross-check.

Create the isolated project and acquire each package's accepted upstream
revisions through APM. Preserve resolved revisions during migration; a move
must not silently become an upstream upgrade. If a historical input cannot
be fetched, retain its existing accepted source and report that package as
unmigrated. Do not delete the only surviving reviewed bytes.

Keep old deployment-bearing locks with the baseline. Establish new acquisition
projects without legacy agent-target claims, using the recorded exact refs
and comparing the complete resulting dependency graph before acceptance.
Do not assume a lock-only invocation clears an old deployment ledger. Any
producer/schema-induced hash change needs an explained source comparison.

Move authored skills into the project and normalize the eight recorded
`literal_` filenames. Derive patches/overlays for all current local deltas,
including condensed descriptions, invocation sidecars, license copies, and
existing crit patches. Use the old `SOURCE.md` notes to account for local
deltas, then retire those repo-generated files. APM owns the fetched tree;
our changes apply only to temporary copies.

Record publication aliases using the existing dependency/frontmatter
identity. Include `orca-stration` versus skill name `orchestration`, and
core's `deep-research` versus deployed directory
`claude-deep-research-skill`. Preserve package membership and deliberate
selection of individual skills from larger upstreams.

Completion: every retained payload has a mapped new input; every local delta
is accounted for. Record the omitted repo-generated `SOURCE.md` paths in the
baseline comparison. Locked upstream content and reviewed changes remain
distinguishable. The committed module snapshot survives a clean checkout and
can supply publication without a second `skills/vendor` store.

### 3. Build complete native plugins from the committed inputs

Implement the bounded assembly step inside the project. Use selected module
content, authored source, and reviewed patches/overlays. Refuse path escapes,
missing inputs, ambiguous aliases, and unplanned collisions before publishing
output. Patches must fail visibly on drift. Copy complete payload directories,
including hook scripts and eval files the APM bundle exporter omitted.

A build leaves source, cache, and locks unchanged. Missing cache content fails
locally. For a missing committed file, identify the path and direct the user
to restore that file from Git. A copy outside Git needs a complete source
export. Direct the user to fetch only for unacquired declarations whose cache
and lock satisfy the clean-input requirement. Build never acquires inputs.
Validate APM content hashes using the pinned producer's implementation rather
than inventing another hash format, and retain separate executable-bit and
symlink checks. Do not treat `apm audit` pin replay as whole-tree validation.

Keep the current source-surface rules for unsupported dependency components
and the content scan that rejects hidden control characters. `apm lock`
does not run these checks. Validate the dependency source surface, then scan
the selected build payload after applying patches/overlays. Run both checks
offline without deploying agent files. Build must reject findings before
output is ready for export or materialization; `make check` covers this through
its fresh build. Preserve the negative public-workflow tests for unsupported
components and hidden Unicode, including a finding introduced by a local patch.

Generate the native manifests/catalogs and preserve all existing Codex UI
fields and hook suppression. Compare every package's output to the old
renderer by skill inventory, payload bytes, and modes, excluding only the
identified repo-generated `SOURCE.md` files. Keep upstream-provided files with
that name. Review any necessary reference repair individually. Include all 22
paired human-only controls; this proves the file contract, not model invocation
behavior.

Completion: a clean checkout of this isolated folder builds with network
denied after tool provisioning. Two builds match; a changed cache file,
missing helper, or stale patch causes an appropriate failure. Baseline payload
matches except for the approved `SOURCE.md` removals; native discovery matches.
Deleting a committed helper produces the Git recovery instruction. Restoring
only that file restores the offline build, with unrelated edits preserved.

### 4. Replace the maintenance workflow and policy readers

Replace `vendor-agent-package` with the project's native acquisition targets.
Git review accepts the changed lock and complete module diff together. Use
native lock generation after editing dependency declarations. Require that
removed dependency keys are absent from the resulting lock before considering
`apm prune --dry-run` and then `apm prune` for leftover cache directories.
APM can re-integrate surviving hooks when prune removes locked dependency
keys, even when prior deployment records are empty.

Gate this exact removal sequence with a removed dependency and a surviving
hooks dependency. Assert that only the selected cache and lock change, with
transitive inputs retained and no agent config created or modified; exit
status alone is insufficient. If the gate fails, defer pruning and leave
unused cache directories excluded from publication. Build membership always
comes from declarations and explicit selections, never from every directory
present under `apm_modules`.

An upstream update follows: require clean acquisition inputs, refresh through
APM, review the cache/lock diff, adjust patches, rebuild, and inspect the
published diff. A local change edits authored source or a patch/overlay.
Published payload or native metadata changes require a package version bump,
with matching authored Codex version; catalogs derive versions from metadata.

Migrate the validator, inventory, context audit, patch checks, and skill
console to this model. Resolve imported skill identity through publication
selection and the APM lock; remove readers and validation rules that require
our `SOURCE.md` files. Authored skills remain editable directly; imported
skills put accepted edits in patches/overlays.
The console's guarded plan stages all affected source, version, and delta
changes and previews the resulting build. It must not edit an APM cache entry
as if that were durable local skill source. Source-removal operations use APM
manifest/lock ownership and keep unrelated packages intact.
Imported text edits also fingerprint marketplace inputs before planning and
recheck them before the first write, including when dirty targets are permitted.
New console patches follow all existing filename-ordered patches and preserve
valid files without a final newline.

Move `default_loaded` and local per-agent eligibility into the consumer
policy file. Config templates read that policy; runtime inventory reads
generated JSON catalogs. Preserve the four enabled defaults: `core`,
`mattpocock`, `review`, and `utils-agent`. Keep the other six available and
disabled. Pi retains its Claude-plugin selection, and Cursor retains its
current marketplace/ACP behavior.

Catalogs describe published availability independently of local eligibility.
This changes the old `render = "none"` catalog-filtering contract: excluded
plugins remain available while local config/reconciliation excludes their
activation. Replace those fixtures explicitly. Require known, explicit policy
entries so a new package never acquires an implicit enabled default.

Completion: acquisition is APM-owned, local edits survive refresh, and the
console's guarded-write guarantees pass with the new source ownership.
All four consumer config merge suites pass. Retire `SOURCE.md` generation and
its field-preservation assertions. Remove the old acquisition helper after
its remaining guarantees have replacements.

### 5. Integrate materialization and native release updates

Keep the adapter small: obtain `build/marketplace` through the project's
Makefile or receive a prebuilt artifact, validate it, then copy it to
`~/.agents/plugins`. Stage a complete sibling tree before replacing the
owned live root. Failed build/copy/validation leaves the live tree usable.
Keep the previous artifact for recovery; native CLI operations remain
separate state changes.

Update script 36 and its change hash for the new source, cache, policy, and
build/adapter code. Retain script 35 and the Codex runtime
`~/.agents/skills` stub. Retire old `~/.agents/packages` files only after
ownership/content checks that preserve unrecognized local changes.

Adapt the native reconciler to the artifact and consumer policy. Snapshot CLI
state once and reconcile only `prateek-local`. Claude needs explicit updates
of changed installed versions; the current implementation installs missing
plugins but never updates existing ones. Restore desired enabled state after
installation/update and remove owned orphans.

Prove Codex's configured-root lookup of
`.agents/plugins/marketplace.json`, native installation, and cache refresh.
Its add command enables the plugin, so preserve automatic refresh of enabled
defaults and an explicit refresh-and-restore path for an installed disabled
plugin used by a project override. Preserve unrelated plugins and config.

Completion: scoped isolated apply and native Claude/Codex checks cover every
package, versioned payload updates, stale-file removal, relocated artifacts,
and disabled state. Include a materialize-only check with APM absent.
Unrelated network-using chezmoi scripts are outside the offline check.
A reader-only Codex probe cannot satisfy installation/cache acceptance.

### 6. Export and rehearse recovery

Archive the complete built marketplace, with relative catalog sources and
all plugin payloads inside the export. Record the input dotfiles revision and
tool version with the release receipt. A fresh machine can build from the
committed module snapshot; an existing exported artifact can be installed
without a build toolchain.

Validate relocated local-directory consumption and an artifact-root Git
distribution in isolated native client state. A distribution branch in the
existing dotfiles repository remains an option for following releases; the
source project stays in dotfiles. Remote publication is a separate action.
A future Nix consumer can build this same project or use the resulting
artifact; packaging does not read chezmoi-specific inputs.

Rehearse rollback before live cutover: restore the previous artifact and
managed policy, restore native registration/install state through the CLIs,
and verify the prior payload and enabled set. If a client cannot downgrade
directly, prove its native remove/reinstall sequence. Do not hand-edit native
cache databases.

Completion: a relocated artifact works without its source checkout or upstream
network; the previous release can be restored with its native state and
unrelated user state preserved.

### 7. Cut over and retire the old implementation

After isolated parity and recovery pass, remove the custom manifest/catalog
renderer, the separate vendored source store, obsolete `package.toml` files,
and recurring chezmoi filename transforms. Keep the small publication
assembly and consumer adapters. Move packaging-specific helpers/tests inside
the isolated project; root Make targets delegate to its own Makefile.

Update the management skill/references, AGENTS source-location contract,
tests index, and active source-path consumers. Include the skill-search
symlink, crit eval runner, iOS Make targets, ignore rules, and apply tree hash.
Account for every removed assertion with equivalent coverage or an explicit
tradeoff. [ADR 0016](../adr/0016-vendor-into-skill-references.md) remains a
separate proposal; retain existing behavior and correct its nested-discovery
assumption before any adoption.

Validate the complete implementation diff, then land/apply within the
authorized scope using the repo workflow. Verify native inventories, hooks,
versions, and enablement after the actual scoped apply and in a fresh agent
session. Retain the rollback artifact until those checks pass.

Completion: one isolated source/build project supplies the live marketplace;
all required checks have recorded results. Update current operating guidance,
record successor relationships for earlier decisions, and close this plan
after rollout. Remove disposable probes while retaining the findings.

## Required checks

Use the [test index](../../tests/README.md#agent-package-checks) for public
seams and environment isolation. The project's `check` target belongs in a
required CI lane with pinned tools provisioned first. Keep native agent tests
as a separate host lane; expand the current Codex first-plugin read to cover
all packages and install/update behavior.

```sh
make -C agent-marketplace check
make test-agent-skill-packages test-vendor-skill-patches test-skill-console
make test-claude-settings test-codex-config test-cursor-config test-pi-settings
make test-agent-skill-packages-native
make test-docs-lifecycle
git diff --check
```

When old target names retire, preserve their guarantees through delegation
and update the test index. Run each required check once through the canonical
lane. Console producer checks and authenticated crit evals remain separate;
ordinary packaging checks do not establish their runtime behavior.

The acceptance record must cover:

- Cache acquisition, full Git round-trip, hashes, executable bits, receipts,
  recovery of missing committed files, and failure without silent ref upgrades.
- Complete native payload assembly, collision/path checks, patch drift,
  source-surface/content-scan rejection, invocation policies, and offline
  repeatability.
- Guarded maintenance edits, versioned releases, consumer defaults, and
  preservation of unrelated source/config.
- Native discovery, installation, cache updates, relocation, and rollback.

## Future TODO: APM registry or mirror

Defer hosting and operating a registry until the committed-cache workflow
works. APM already has experimental native registry support and a separate
Git archive proxy mechanism; evaluate those interfaces before designing a
new service.

The follow-up should choose which interface serves our locked inputs, retain
immutable artifacts by resolved revision/content hash, and prove cold-cache
restoration while GitHub is unavailable. Verify that any strict mirror mode
really prevents fallback to GitHub. Migration to that service should replace
the acquisition source without changing package grouping, local patches,
the Makefile's build contract, or consumer materialization.

For now, Git contains the accepted dependency bytes and exported artifacts
can be retained locally. An APM lockfile by itself is insufficient for outage
independence, and registry work is not a prerequisite for this first step.
