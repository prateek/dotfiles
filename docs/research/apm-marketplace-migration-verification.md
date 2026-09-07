---
status: active
doc_type: research
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - ../plans/apm-agent-marketplace-plan.md
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../adr/0025-shared-apm-acquisition.md
  - ../references/agent-marketplace.md
  - ../../agent-marketplace/README.md
status_detail: "Migration landed and scoped live cutover verified. Fresh authenticated Claude and Codex sessions discovered the expected skills and followed a console edit/apply/revert round trip. Skill invocation behavior and authenticated Crit evals remain untested."
---

# APM Marketplace Migration Verification

The implementation replaces the custom acquisition and manifest/catalog renderer
with the isolated `agent-marketplace/` project. APM 0.29.1 owns acquisition, native
locks, Claude manifests, and both catalogs. The project assembles reviewed inputs;
consumer adapters materialize artifacts and reconcile native installations.

This record distinguishes implementation checks in disposable state, the
authorized [live cutover](#live-cutover), and
[fresh model-session discovery](#live-maintenance-round-trip).
Catalog visibility does not establish skill invocation or authenticated Crit
eval behavior.

## Baseline and acquisition

The comparison baseline is dotfiles commit
`9a24d70664e52f119f00907929c2587305d54bc7`. An isolated Git archive retained the old
source, renderer, locks, and output during implementation.

All 60 direct dependencies were acquired through native APM 0.29.1 at their
previously accepted resolved revisions. Package counts were core 4, design 2,
experimental 3, ios 3, mattpocock 1, obsidian-wiki 41, review 1, superpowers 1,
utils-agent 4, and utils-human 0. No upstream upgrade was folded into the move.

One-time bootstrap declarations used exact accepted SHAs, then recovered the
original manifest reference semantics. Leaving a lock's `resolved_ref` as that
bootstrap SHA while changing its declaration to an unpinned ref caused APM to
resolve again. The bootstrap used APM's LockFile model to establish compatible
input, followed by native lock generation and offline replay. There is no
production lock-rewrite helper.

APM 0.29.1 normalized Crit as `skill_bundle`; the older acquisition recorded
`marketplace_plugin`. That accounts for changed producer hashes. The accepted
upstream revision and retained native payload still matched.

Executed acquisition gates included:

- Native `apm lock` for a virtual skill and a whole Crit plugin with hooks,
  followed by network-denied cached replay. Locks and caches retained no
  deployment claims and created no agent config.
- All ten acquisition locks replayed offline unchanged.
- A disposable accepted review package updated through the public Make target
  from Crit `31d6a6a9195bdda735c1e8f68a75359839f8d3c8` to
  `7cf3e97f154a7ffd895c7fe07fab20807d03df25`, with the change left for Git review.
- Public fetch and update targets refused unaccepted cache/lock changes before
  APM ran. Native missing-dependency failure propagated through both Make targets.
- Declaration removal followed by native lock generation, `apm prune --dry-run`,
  and prune retained a surviving transitive dependency's hooks and executable
  helper. Its complete bytes/modes remained equal, its depth stayed transitive,
  and no Claude, Codex, Cursor, or generic agent config appeared. A separate
  cached Crit removal rehearsal retained the surviving hooks payload too.

Local-path APM dependencies carry neither a remote `content_hash` nor `.apm-pin`.
They are useful hermetic acquisition fixtures but are rejected as cached
publication inputs. Authored local skills use direct source directories.

## Payload and source transport

Before retiring the old source, the replacement matched all **1,347 retained
payload files**, including bytes and full permission modes. The comparison
covered skills, hooks, and evals. It intentionally omitted the **124 repo-generated
`SOURCE.md` files**. Upstream-owned files with that name remain publication input;
there is a negative/positive build fixture for this distinction.

The migration preserved all ten plugin IDs, curated directory aliases, Codex
interface metadata, hook suppression, and the 22 paired human-only invocation
controls. All plugins moved to version 1.1.0. Eight `literal_` filenames became
native filenames in the source project. Existing local deltas became patches
and authored additions; accepted APM inputs stayed pristine.

After parity, these authored operational references changed deliberately:

- The skills-searcher test and skill instructions point to its new source path.
- The iOS audit's source fallback locates the assembled neighboring simulator
  skill; its installed sibling behavior remains intact.
- Crit eval paths, Make targets, the management skill, and current docs point to
  the isolated project and native publication workflow.

An explicit source-only Git fixture retained **3,032 project files and all 60
APM receipts**, including 2,624 cache files and files hidden by upstream
`.gitignore` rules. A Git archive of it reproduced every file's bytes and modes.
Native lock files were normalized from mode 0600 to 0644 because Git records executable status, not
arbitrary owner/group read permissions.

That final standalone source export passed the complete 21-test project check,
two fresh builds, and export under macOS network denial after
provisioning Python 3.14.6, uv 0.11.26, APM 0.29.1, and PyYAML 6.0.3. APM's pinned
hash validates cache content; separate checks reject payload symlinks, special files,
and executable-bit changes against Git's index. A source export outside Git
trusts its archive's file modes; it cannot compare them to an absent index.
The artifact receipt independently validates all exported bytes and modes.
The post-review replay retained the same 3,032 source files and exported 1,384
artifact files, including four added upstream license/notice payloads. Its source
digest was `ddee827d0d3c68f3edbc6375af298a12cba0a841ba4a85c0286a310441e8b1cf`.
The extracted artifact passed receipt validation too. Runtime `__pycache__`
entries are excluded without traversal from source and publication.

## Native clients and recovery

Executed versions were **Claude Code 2.1.261** and **Codex CLI 0.153.4**. The durable
[host scenario](../../tests/scenarios/agents/native-marketplace.py) uses isolated
HOME, CODEX_HOME, and CLAUDE_CONFIG_DIR, resolved tool executables, and no model calls.
The normal Mise data directory remains unchanged.

The combined scoped apply now runs real scripts 35/36, all four client config
entries, and the managed symlinks in an isolated home with external CLI fixtures.
It checks both native catalogs' relative paths, executable payloads, enabled
defaults, unrelated client state, preserved Codex `.system` skills, retired old
skill projections, and preservation of unknown legacy source. An identical second
apply changes neither config/receipt bytes nor native calls; direct managed
targets pass `chezmoi verify`. Source byte and executable-mode changes alter
script 36's hash. The native-client lane below separately checks those CLI boundaries.

The production materializer and reconciler passed these checks for every package:

1. Initial native installation with four enabled defaults and six disabled
   packages, preserving an unrelated marketplace and plugin in each client.
2. A versioned 1.1.0 → 1.1.1 payload update, including deletion of a stale helper.
   Both native cache contents and enabled states matched the new release.
3. Materialization retry preserved the prior release instead of rotating it away.
4. Relocated artifact registration refreshed installed disabled Codex packages.
5. Native rollback restored version 1.1.0, prior payloads, and enabled states.
   Claude uses native remove/install to support downgrade and remove stale files.
6. Both clients consumed an artifact-root Git repository through local smart HTTP.
   The Git repository contained the built marketplace, without the source project
   or APM cache. This was local distribution validation, not remote publication.

Codex read all plugins from the root `.agents/plugins/marketplace.json` and
reported these skill counts, with no hooks exposed:

| Package | Codex skills |
| --- | ---: |
| core | 13 |
| design | 22 |
| experimental | 17 |
| ios | 7 |
| mattpocock | 25 |
| obsidian-wiki | 45 |
| review | 6 |
| superpowers | 14 |
| utils-agent | 8 |
| utils-human | 5 |

The total is 162; Claude's top-level source inventory is 158. The four nested
trycycle skills explain the difference. The earlier spike established Claude's
listing behavior; the new host lane validates native installation and the complete
cached payload, rather than making an authenticated Claude listing call.

Native Codex marketplace relocation requires remove/add: adding the same name
with a different root fails. Removing a registration temporarily hides its
installed entries from listing, so the adapter snapshots installations first.
Codex `plugin add` enables a plugin; disabled-state restoration now happens after
each refresh, even when a later install fails. The app-server reader buffers
fragmented JSON responses and bounds response waits.

The first migration's legacy artifact has no release receipt. A separate native
rehearsal restored it after a new-format installation: all ten version-1.0.0
plugins, every baseline plugin file's bytes/modes, the four defaults, 162 Codex
skills, and unrelated state matched. Codex registered `$HOME` for the old catalog
at `.agents/plugins/marketplace.json`; new artifacts instead register the artifact
root. The [recovery procedure](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md#first-migration-rollback)
records both formats and keeps the failed new artifact for inspection.

Legacy `~/.agents/packages` retirement compares the directory to chezmoi's target
archive of the pinned old Git source. Matching content moves to
`~/.agents/packages.retired`; unknown files, edits, symlinks, missing history, or
an existing backup preserve the old directory and report why. No source backup
is deleted by this migration helper.

## Final local checks

All checks below passed through the repository's public command surfaces:

| Check | Result |
| --- | --- |
| `make -C agent-marketplace check` and `export` | 21 tests, two matching fresh builds, and a checked complete marketplace archive |
| `make test-agent-skill-packages test-skill-console test-chezmoi-apply` | 12 consumer tests, 57 console tests, and chezmoi dry-run validation for ci, personal, and work |
| `make test-claude-settings test-codex-config test-cursor-config test-pi-settings` | 17 config tests and six Pi launcher scenarios |
| `make test-agent-skill-packages-native` | Project check plus the real Claude/Codex installation, update, relocation, rollback, and Git distribution scenario; the host Bats lane was repeated against the final notice-bearing artifact after the 21-test project check |
| `make test-ios-audit` | 16 tests, including authored-source and installed-sibling skill lookup |
| Skills-searcher zsh suite | Passed from the new authored-source location |
| `make test-docs-lifecycle` | 37 validator tests and all 84 current docs; historical link repair follows detected skill moves without permitting prose edits |
| Rendered script 36 ShellCheck and changed-skill frontmatter/link checks | Passed |
| `git diff --check` | Passed with fetched bytes and patch whitespace preserved by scoped Git attributes |

Independent reviews found and verified fixes for rollback loss on materialization
retry, disabled Codex state after a failed refresh, fragmented app-server replies,
cache executable-bit damage, and imported edits to overlay sidecars. The final
console test also checks that source bytes, modes, locks, metadata, and host policy
invalidate an approval while disposable build output does not.

The follow-up no-context review reproduced missing skill entrypoints, Python
cache publication outside its fingerprint, and imported edits whose reviewed
inputs changed after staging. Regression tests first failed, then passed with
root validation, consistent cache exclusion, and a commit-time source digest
guard before any write. That guard still applies with dirty-target override;
unrelated repository edits remain permitted. Failed build/export attempts preserve
the previously accepted artifact and archive.

The reviewer also found console patch ordering/newline cases and four omitted
upstream notices. Console patches now follow all existing filename-ordered
patches, use a stable counter after nonnumeric names, leave room for temporary
write filenames, and preserve files without final newlines. The public stage/build
regression includes a 241-byte existing patch filename. Explicit publication
entries retain the root licenses from Next Level Builder, Apple HIG, and Kepano,
plus Apple HIG's third-party notices. All four published files match their cached
bytes. The audit covered 60 dependencies and 20 named notice candidates; the other
16 already had identical copies in their plugins.
The reviewer reran the original cases, a 15-edit patch chain, and a 245-byte
existing filename. The replacement names stayed at 35 bytes across another edit,
staged builds passed, and no findings remained.

Updated `agent-skill-management`, `chezmoi-management`, and `land-changes` now
describe portable input ownership, script-created targets, pending script effects,
and the limits of direct chezmoi verification. The other four repo-local skills
needed no path correction. Metadata, links, the chezmoi skill validator, and the two
new eval fixtures pass structural checks; no model eval was run.

The source-only Git/archive and network-denied check described above is separate
from the working-checkout checks. Temporary baseline checkouts, acquisition probes,
native profiles, and source-export fixtures were removed after recording results.
The checked marketplace and its export remain ignored build output.

## Live cutover

Commit `f0856157b8ed980e2e1395df07009a9ea9ecf284` was fast-forwarded into
`~/dotfiles` and pushed to `master`. The scoped chezmoi apply ran from that
canonical checkout after provisioning the project's locked tool environment.
It applied scripts 35/36, the affected directly managed files, and the managed
symlinks. Cursor config was gated off on this machine. Codex's managed plugin
fragment already matched; its unrelated live reasoning setting was preserved.

The materialized artifact's 1,384 files matched the checked release and committed
source digest above. Claude, canonical Codex, and this Orca account's separate
Codex profile each installed all ten plugins at version 1.1.0. Every cached
payload file matched its artifact bytes and modes. Only `core`, `mattpocock`,
`review`, and `utils-agent` were enabled. Installed disabled Codex plugins were
explicitly refreshed and restored to disabled state.

Fresh native Codex app-server processes discovered all 162 skills in both
profiles. Unrelated native plugins and Codex settings remained unchanged.
The applied direct targets passed `chezmoi verify`, and the scoped diff, including
scripts 35/36, was empty. The old artifact remained byte-for-byte at
`~/.agents/plugins.previous`. Legacy source at `~/.agents/packages` differed from
the migration baseline, so retirement preserved it. Codex runtime skills and
modes were preserved; their generated README now points to the isolated project.

The first remote CI run caught two stale warning assertions in the broad CI
apply scenario. The native publisher no longer emits the retired renderer's
component-mapping warnings. The replacement checks inspect the materialized
Codex manifests for omitted eval registration and explicit hook suppression;
the existing convergence and disabled-wiki cleanup checks remain intact.
The corrected scenario and complete `make test-ci` lane passed locally.
Correction commit `2c76d98655a2c391a27608fd8819ecbf3e4a0cb7` also passed the
[remote CI run](https://github.com/prateek/dotfiles/actions/runs/34133873665),
including the macOS and shellcheck jobs.

## Live maintenance round trip

Fresh authenticated Claude 2.1.261 and Codex 0.153.4 sessions ran from the
canonical checkout. A catalog-only prompt asked about three repo-local skills
(`agent-skill-management`, `chezmoi-management`, and `land-changes`) and one skill
from each enabled plugin (`core:code-gardening`, `mattpocock:domain-modeling`,
`review:crit-cli`, and `utils-agent:ask`). Both clients reported all seven names
and their descriptions. Their event streams contained no tool calls.

The public `skill-console render` and `skill-console apply --commit` commands
then staged and wrote two temporary description edits: one authored skill and
one imported skill. Each description received a different random marker. The
console changed the authored source directly, created an imported patch, and
bumped both packages' APM and Codex native versions from 1.1.0 to 1.1.1. All staged
checks passed before its six guarded writes. The 2,624 committed APM cache files
remained unchanged.

The normal script-36 chezmoi diff became nonempty. After its dry-run, scoped
apply rebuilt the artifact and refreshed native installations. No script-state
reset or forced refresh was needed for the enabled plugins. Chezmoi inherited
the active Orca `CODEX_HOME`; the normal reconciler was also run with that
variable unset to refresh canonical `~/.codex`.

| Stage | Claude | Orca Codex | Canonical Codex |
| --- | --- | --- | --- |
| Sample edits applied | All seven skills visible; both exact markers present | Same | Same |
| Source restored and applied again | All seven descriptions exactly match baseline; no markers | Same | Same |

Every run used the same prompt, which contained no marker values, and made no
tool calls. This establishes fresh-session catalog propagation independently of
reading source files in those sessions. All enabled native cache payloads matched
the corresponding artifact bytes and modes after both applies.

Cleanup restored exactly the six sample paths after checking their recorded
before/after hashes. The canonical checkout was clean and script 36 had no
remaining diff. Native settings and unrelated Claude plugin records were
unchanged; all committed APM cache hashes still matched. A separately landed
`utils-agent` 1.1.1 update was preserved. The original legacy artifact was
restored at `~/.agents/plugins.previous` after the test's artifact rotations.

The console requires the root `make test-tools` prerequisites as documented in
the [test index](../../tests/README.md), in addition to the portable project's
tools. Its staged Pi checks need the provisioned Bats libraries. The guarded
console run used the exact recorded Claude 2.1.258 producer through mise; the
model-session probes used the ordinary 2.1.261 client. No producer guard was
bypassed. These results cover description edits and refresh behavior, not skill
body execution, human-only policy behavior, or authenticated Crit evals.

## Shared acquisition follow-up

[ADR 0025](../adr/0025-shared-apm-acquisition.md) replaces the initial per-plugin
APM projects with one root manifest, lock, and committed cache. The ten plugin
directories retain their selections and local content; each native Codex manifest
now owns its plugin's version and common metadata. Temporary APM manifests are
derived during packing and removed before export or materialization.

All **2,624 cached files** moved without byte or permission-mode changes. The
combined lock retained all **60 accepted dependency records**. Native APM 0.29.1
replayed that root lock with macOS network access denied, produced the same parsed
records, and left the complete cache unchanged. It wrote no agent deployment
state. The committed root lock uses native serialization and regular-file mode
0644. No dependency revision was updated during consolidation.

Against the pre-consolidation artifact at `2c76d98`, all **1,351 non-metadata
payload files** matched by bytes and full modes. All ten Claude/Codex manifest
pairs matched after excluding only version; plugins now use 1.2.0. The artifact
removed eleven APM manifests: one marketplace recipe and ten temporary plugin
recipes. Catalog membership, Codex interface metadata, hooks policy, and skill
content were preserved.

Public Make tests prove two plugins can select one shared input while a patch
changes only one plugin's output. The shared cache remains pristine, each plugin
gets its own native version, and no APM publication manifest remains in the
artifact. Root fetch/update retain dirty-input and native-failure checks; the old
`PACKAGE` selector fails before touching inputs. The portable suite passed all
23 tests and repeatable builds.

The console writes authored content or imported patches/overlays, bumps only the
plugin's native Codex version, and builds matching Claude metadata. Deletion uses
the root manifest and native lock generation without modifying cache content.
Ownership checks cover all plugin selections. Tests also introduce a skill or
supporting-payload selection in a different plugin after planning and assert
refusal before any write. All 57 console tests and 12 consumer tests passed,
including the combined isolated chezmoi apply and unchanged repeat apply.

The isolated native host lane passed with the new artifact: all ten plugins
installed, updated, relocated, rolled back, and installed from an artifact-root
Git marketplace. These native CLI checks use no model calls; the historical live
model-session results above belong to the earlier layout.

A complete source copy containing 3,014 files was force-added to a disposable Git
repository and exported through `git archive`. Every byte and full permission mode
survived the round trip, including the 2,624 cached files. The public root `make
fetch` replayed unchanged with networking denied. The archive then passed `make
check export` outside Git under the same network denial using the provisioned tool
environment. All four config merge suites, docs lifecycle checks, repo-local skill
frontmatter parsing, and `git diff --check` passed. A fresh no-context adversarial
review reported no actionable findings. The comment pass found no new comments to
prune.

The redundant authored APM/Codex version-equality assertion is retired. Its
replacement checks actual generated Claude and Codex metadata against independent
expected versions through public builds, including a console edit. All earlier
path, corruption, stale-patch, invocation-policy, source-change, partial-write,
and cache-preservation assertions remain.

## Replaced assertions

| Previous guarantee or assertion | Replacement or explicit contract change |
| --- | --- |
| Valid committed layout, explicit defaults, empty runtime skill stub | Project `check`, consumer package tests, and unchanged root-maintenance assertions |
| Full-SHA declarations | Native manifest refs may float; accepted lock revisions and full cache hashes are validated, and builds never resolve refs |
| Chezmoi-dangerous names require `literal_` | Source moved outside chezmoi; native paths and Git/archive mode preservation are checked |
| SOURCE generation, License/Notes retention, separate pristine hashes | Removed by decision; licenses remain payload, APM validates pristine hashes, and Git retains reviewed cache/patch history |
| Curated aliases, stale skills removed, local source preserved | Explicit selections, collision checks, clean artifact replacement, and cache-unchanged patch tests |
| Hand-authored hooks survive imports; ambiguous hook sources fail | Authored/selected output collisions fail before replacing the artifact; there is no destructive import-copy step |
| Hooks manifest/helper execution and Codex suppression | Project hook fixtures plus native all-plugin discovery/cache checks |
| Broad CI apply warns that evals and hooks are Claude-only | Native publication emits no custom mapping warnings; the same apply scenario checks omitted Codex eval registration and explicit empty hook objects in the materialized manifests |
| Source-surface and hidden Unicode audit, special audit false-positive exemption | Unsupported source components and post-patch critical scan are retained; the old audit exemption disappears with that audit path |
| Reverse patches reproduce SOURCE-recorded pristine bytes | Pristine APM hash validation plus applying patches to temporary copies; damaged cache and stale patches fail before publication |
| Patch paths can be submitted upstream unchanged | Deliberately changed to native published paths; aliases require path remapping for upstream submission |
| Handwritten catalogs/config fragments match package policy | Native catalogs validate membership/containment; four real config merge suites read explicit host policy |
| `render = none` removes a catalog entry | Catalog availability is independent; local eligibility only changes activation |
| CLI ownership, steady-state reads, dry-run, named errors | Consumer subprocess fixtures retain these assertions and add disabled-state failure recovery |
| First-plugin Codex read and Claude marketplace validation | One native host scenario covers all packages, installation, updates, stale removal, relocation, rollback, and Git distribution |
| Console validation, stale snapshots, staging, guarded writes and partial deletion | Existing tests migrated to durable ownership; imported description/paired-policy edits build as patches/overlays with matching version bumps and untouched caches |

Console producer parity remains pinned to Claude 2.1.258 and its recorded binary
hash. Passing the packaging host lane on 2.1.261 does not certify that producer.
Authenticated Crit evals and fresh skill invocation checks remain untested.
The live checks above verify native state and model-session catalog visibility,
including maintenance updates and restoration; they do not certify skill behavior.
