---
status: active
doc_type: reference
summary: "Shared package status, pin-aware operations, bulk latest, and banner/audit integration."
created: 2026-10-12
updated: 2026-10-15
related:
  - ../retired.md
  - ../adr/0049-shared-package-operations.md
---

# dotpkgs

`dotpkgs` inventories machine packages, compares their version policies with
available updates, and plans or executes operations through their owning tools.
Chezmoi installs the executable in `~/.local/bin` and Python modules in
`~/.local/lib/dotpkgs`. The executable uses uv's cached script environment;
its pinned dependencies are mirrored in `scripts/packages/dotpkgs/pyproject.toml`.
The first invocation may download Python/dependencies. Once provisioned,
`doctor`, cached status, and help require no network checks.

```sh
dotpkgs doctor
dotpkgs managers
dotpkgs managers --verbose             # provider limits and privilege guidance
dotpkgs list                           # compact inventory, including desired missing items
dotpkgs list --all                     # also show dependencies and disabled items
dotpkgs status                         # counts and packages needing attention
dotpkgs status --all                   # also show current packages
dotpkgs status --manager mise
dotpkgs outdated                       # includes pins with newer releases
dotpkgs --json status --cached --manager mise

dotpkgs update mise:node --dry-run       # preserves its current version policy
dotpkgs update --all --latest --dry-run  # preview every manager, including pin changes
dotpkgs update --all --latest            # execute the plan, reporting manual steps
dotpkgs pin mise:node --version 24.12.0 --dry-run
dotpkgs unpin mise:node --dry-run

dotpkgs install brew:example --group developer-tools --dry-run
dotpkgs install brew:example-app --kind cask --group mac-desktop --dry-run
dotpkgs remove brew:example --dry-run
dotpkgs exec --dry-run brew -- info --json=v2 git
```

Package IDs start with the manager, then a colon and the native name; for
example `mise:npm:agent-slack`. `list` gives exact IDs. With one `--manager`,
a bare native name is also accepted. An omitted manager on reads selects all;
writes require explicit IDs or `update --all`. Repeat `--manager` to limit a
bulk update. New grouped declarations require `--group` so an install cannot
silently change an arbitrary machine role. Unsupported `--version` combinations
fail before writes rather than silently installing a different version.

Use `--source /path/to/dotfiles` when changing a worktree. Otherwise source
operations resolve the canonical checkout through `chezmoi source-path`.
`DOTPKGS_SOURCE` is the equivalent environment override. Mise inventories and
operations run from the home directory, independent of the invoking project.
Native credentials and proxies remain the underlying manager's responsibility.
There is no separate token store; offline doctor does not authenticate.

## Status

Each record includes `id`, `manager`, `name`, `installed`, `requested`,
`latest_allowed`, `latest`, `pinned`, `status`, and `note`. Providers add fields
such as `kind`, `source`, `path`, or Raycast `dependencies`.

| Status | Meaning |
| --- | --- |
| `current` | The installed state matches the manager's policy-eligible state; see owner-specific limits below. |
| `update_available` | An update fits the current policy, or source needs rebuilding. |
| `pinned_outdated` | Newer upstream state exists beyond the current pin, lock, or release channel. |
| `policy_mismatch` | A directly comparable installed version differs from the declared version. |
| `missing` | The configured item is not installed. |
| `unknown` | No valid comparison was made, or a build lacks a receipt. |
| `disabled` | An absent native agent or Swift helper is not selected/enabled for this machine. |

Text `list` shows canonical IDs, installed versions, and meaningful pin or absence
states. Homebrew dependencies and disabled entries are hidden unless `--all` or
an explicit package ID selects them. JSON retains the full inventory and original
version/status fields. Brew, MAS, gh, and simple zinit declarations supplement
installed inventories with desired missing entries. Brew and MAS declarations
come from the rendered Brewfile, preserving OS gates, MAS opt-in, fork
replacements, and selected agent adapters. A source-built helper can be
present without a version receipt; `present` distinguishes that case from absence.

Text `status` leads with counts and hides current/disabled rows by default.
`outdated` keeps update rows in `packages`, full selected coverage in `summary`,
and unknown, missing, or policy-mismatch rows in `unresolved`. An empty update
list therefore does not erase uncertainty. Human views display unresolved
rows and their reasons. `checked_at` is rendered as a UTC timestamp, with a
distinct label for live and cached results. Interactive terminals show provider
progress on stderr.

`list` avoids upstream comparisons. `status` refreshes successful snapshots under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/dotpkgs/`; `status --cached` returns the
original `checked_at`, not a fresh timestamp. A failed probe returns an error
and preserves the previous snapshot. A cache read never substitutes for a live
check silently. A selected-package check does not replace the complete provider
snapshot. The banner owns its summary cache; `summary` does not replace a
`status` snapshot. Applied source edits invalidate affected snapshots even when a
later native step never starts. Execution also invalidates its provider snapshot.

An explicitly requested unavailable provider fails, including in TSV mode.
An all-provider read reports unavailable providers without treating them as empty
successful inventories. Package-specific remote probes run only for selected
packages; native tools that expose one combined inventory/comparison still use
that shared query.

“Latest” has an owner-specific meaning. Homebrew compares its available catalog
and installed receipts; status disables implicit `brew update`, while the
update operation explicitly refreshes it. Ordinary updates and banner counts respect
Homebrew’s non-greedy policy: self-updating and `latest` casks are skipped unless
`--latest` is requested. Catalog versions remain available as `latest` metadata, so a cask can be
`current` under normal Homebrew policy while its catalog version is newer than
its receipt. This is not proof that its self-updated app bundle is current.
A versioned formula stays in that
formula's release line. Cask receipts can lag an app's self-updated internals.
Mise compares both permitted versions and `outdated --bump`; opaque runtime
aliases without a numeric version remain unknown. APM compares accepted locked
commits with upstream default branches, including pinned refs. Git checks use
`ls-remote`, without fetching objects or moving refs. Xcode uses the stable
versions in xcodes' catalog; installation can still fail on an older macOS.
MAS reports the compatible App Store release. Source-built helpers use digests,
not invented release numbers. Raycast separately reports upstream dependency
versions and the build's source digest.

## Operations and boundaries

| Manager | Integrated writes and limits |
| --- | --- |
| `brew` | Install/remove selected declarations, update, native hold/unhold. Bulk latest clears native holds and includes greedy cask upgrades. Changing a versioned formula's major line requires explicit replacement. |
| `mise` | Install/remove, update, pin/unpin. Edits static owning source entries, generated agent version fields, or the established unmanaged `zz-local.toml`. Removing a host-local override requires manual review/removal of underlying declarations before uninstalling. Required adapters cannot be removed independently of their agent. |
| `claude`, `cursor` | Native installation/update and machine-agent deselection plus reversible launcher removal. No integrated durable pin control; installing one version alone would not disable auto-update. |
| `codex` | Native install/update/remove plus standalone pin/unpin. Pins go in `package_policy.native.codex` and disable the installer's latest-channel tracking. |
| `gh` | Extension install/remove/update and native pin/unpin. Pins are read from native manifest/Git metadata, survive normal updates, and are not fresh-machine declarations. Unpinned extensions update in place; pin changes and bulk latest on a pinned extension remove/reinstall it, and an installation failure can leave it absent. |
| `zinit` | Install/remove simple `zinit light` declarations, update through zinit, and persist `ver` pins in the shell source. Tracked local edits block updates. |
| `apm` | Shared-graph acquisition, declaration pin changes, guarded removal, and validation. Review acquired changes, repair patches, and bump affected plugin versions before installing accepted inputs. Installing an existing dependency validates/materializes the entire marketplace. |
| `mas` | Install/remove declarations and native app operations. Updates run only for apps `mas outdated` reports. Authentication/admin access may be required. No version-pin API. |
| `setapp` | Install missing declared apps and reversibly remove bundles/declarations. Updates require the signed Setapp client and are reported as manual steps. No version-pin API. |
| `xcode` | Install/select the pin, change the pin, install latest stable, or remove an explicit version. The only ID is `xcode:Xcode`. Continuous latest tracking is unsupported, so `unpin` fails; `update --latest` selects a new exact pin. Review the related iOS runtime/device policy after version changes. |
| `raycast` | Rebuild local extensions whose receipt no longer matches the source; bulk latest resolves dependency versions within siblings' required peer ranges (optional peers are ignored, and an exact pin never moves down), updates source manifests/lockfiles when a version moves, and rebuilds. Removal requires an explicit source change and removal of the imported bundle in Raycast; the helper refuses it before writes. Git and lockfiles own source version policy. |
| `externals` | Refresh declared checkouts and fast-forward updates. Add/remove/ref changes require editing the owning chezmoi external declaration; no generic source editor is exposed. |
| `swift` | Build declared helpers and record source/binary digests; updates skip a helper whose receipt matches its source. Removal archives the binary and disables its owning hook through `package_policy.swift`. Git owns source version policy. |

Unsupported operations fail before writes. `managers` repeats the relevant
limits at the command line. `exec` is an explicit native escape hatch: it does
not reconcile declarations, invalidate caches, take the write lock, or classify
the operation as read-only. Native arguments must follow a literal `--`.
Helper options belong before that separator and work on either side of the
manager, as in `exec --dry-run brew -- info git` or
`exec brew --dry-run -- info git`. Missing separators fail before invoking the
native command. Everything after the separator is passed literally. Plain `exec`
preserves native stdout, stderr, and exit status. `exec --json` captures them as
`stdout`, `stderr`, and `exit_code` in the envelope; this is an explicit request
for native output, which can include sensitive data. Use it for native
capabilities the helper does not abstract.

Dry runs show source diffs and exact command arguments, including any manual
steps. A planning error prevents the entire invocation from executing.
Unavailable managers are skipped during bulk updates. Successful plans merge
edits to shared files before execution and reject intervening source changes.
A process lock serializes dotpkgs writes. Source edits happen first; if a native
command fails, completed effects and desired-source edits remain visible.
Execution stops and returns nonzero rather than attempting an unsafe rollback.
Results distinguish `source_status` and `applied_sources` from native execution.
Every step has an `execution` outcome: `completed`, `failed`, `manual`, or
`not_started`. A later provider can have applied source edits and native steps
not started. Source-write failures also retain the list of applied files.
Inspect these fields and the source diff before retrying. Quarantined files are
retained under the state directory's `removed/` tree; the completed step reports
the actual recovery destination.

After successful native steps, the helper reads the selected installed inventory
into `observed`. Command completion and that observation do not assert upstream
freshness or policy convergence; run `status` for the comparison. An observation
failure is reported separately from completed native steps. Human write output
labels step outcomes, shows command environment overrides, and describes
installer, archive, receipt, and manual steps without raw JSON. Use `--verbose`
for installer environment and routine privilege details.

Only `update` accepts write-side `--all`. `--group` is limited to grouped-provider
installs, and `--kind` to Brew installs. Unsupported options fail before probing
or writing. `--version` is offered only on install, pin, and remove; provider
support is validated before inventory. `managers` shows operation capabilities,
including manual and review requirements, with details under `--verbose`.

Bulk latest means the newest version each owner can install, with explicit
pin/range changes where integrated. It does not bypass operating-system
compatibility, native authentication, source-review requirements, or manual
app-client steps. Manual steps produce an incomplete result and nonzero exit.
No package updates run merely by opening a shell.

## Sudo and administrator access

Run `dotpkgs` as your normal user, **never `sudo dotpkgs`**. Source edits,
caches, and user installs must stay owned by you. `help`, `doctor`, `managers`,
`list`, `status`, `outdated`, banner summaries, and dry runs require no sudo.
A dry run describes elevation a later execution needs; it never requests it.

| Owner/operation | Sudo needed? |
| --- | --- |
| Homebrew catalog refresh, formula operations, holds | No, when run as the Homebrew owner. Initial Homebrew bootstrap is separate. |
| Homebrew cask install/update/remove | Sometimes: package installers, system destinations, and uninstall scripts can require it. Homebrew owns the prompt. |
| Mise, native agent CLIs, gh extensions, zinit, APM, externals | No for the managed user-owned destinations. |
| Swift and Raycast builds | No with the required toolchains already installed. Toolchain setup is separate. |
| MAS install/update/remove | Yes; current `mas` requests elevation itself and may reuse valid sudo credentials. App Store login is a separate requirement. |
| Xcode install | May prompt through `xcodes` for privileged installation setup. |
| Xcode select | Yes when changing the system developer directory; `xcodes` handles elevation. |
| Xcode removal | Depends on bundle permissions; delegated to `xcodes`. |
| Setapp install/remove | No automatic sudo. Installation selects a writable directory; removal needs write access to the bundle. A protected bundle can fail with a permission error. |
| Setapp updates and other manual steps | Follow the app/review workflow; authorization is managed there. |
| `exec` | Unknown until its native arguments are inspected; labeled `delegated`. |

`managers --verbose` shows owner-level guidance. Human plans show privilege
requirements when authorization may be needed; `--verbose` also shows routine
user-owned steps. Every step has a `privilege:{sudo,reason}` object in JSON. Values are
`not_needed`, `may_prompt`, `required`, `manual`, or `delegated`. These describe
the operation, not whether a password dialog will appear: a cached sudo ticket
can satisfy an elevation requirement. File edits use ordinary user permissions.
The helper does not collect passwords, pre-authorize sudo, or elevate itself.
Native installers and package scripts retain their own authorization behavior.

Sources: [Homebrew installation](https://docs.brew.sh/Installation),
[MAS root privileges](https://github.com/mas-cli/mas#root-privileges),
[xcodes](https://github.com/XcodesOrg/xcodes), and installed native command help.

## JSON and shell integration

Success envelope:

```json
{"schema_version":1,"ok":true,"results":[{"manager":"mise","status":"ok","packages":[],"summary":{},"checked_at":1791763200}]}
```

Read failures are per-manager `{"manager":"mise","status":"error","error":"..."}`
records with top-level `ok:false`; successful managers retain their results.
Usage failures use `{"schema_version":1,"ok":false,"error":"..."}`.
Write results include `plan:{edits:[{path,diff}],steps:[{type,privilege,...}],notes:[]}` and a status
of `planned`, `completed`, `manual`, `skipped`, `not_started`, or `error`.
Doctor parses source package/policy data, resolves selected groups, reports the
source path, and separates executable availability from provider file/app
presence. Authentication, network, and toolchain execution remain untested.
Native probe errors identify the command to run directly for its diagnostic;
arbitrary native stderr is not copied into inventory JSON. Unexpected response
shapes become per-provider errors without discarding other provider results.
`managers` returns the provider catalog; `exec` returns its native argument vector.
Native write output goes to stderr so JSON stdout stays parseable.
Exit codes: 0 success, 1 incomplete/failed operation, 2 invalid input or setup,
130 interruption. The banner protocol also uses 3 for a missing manager, including
a structured error envelope with `--json`. Native `exec` preserves the native
exit code, including with `--json`.

The banner runs `dotpkgs summary --manager brew|mise|apm` in its existing
background refresh. This emits a TSV header of outdated, total,
pinned-outdated, and unknown counts, then package JSON. The banner only formats
and caches that result. Existing TTLs, locks, startup gating, and fastfetch
rendering remain in the banner. Pin and unknown counts appear as row suffixes.
Chezmoi drift remains a separate banner source because it is configuration
state, not a package update. APM stays opt-in for the banner.

The Brew/app inventory and usage audits consume `list --format tsv`; fork
reconciliation consumes `outdated --format tsv`. Columns are name, installed,
latest, kind, and installed-on-request. These consumers still own their
specialized comparisons, dependency graphs, and usage evidence. They snapshot
package state once per run. TSV remains an installed-only projection and requires
one selected provider so native names cannot collide across providers. Failed
inventory probes stop the audit with an explicit diagnostic; they must not be interpreted as an empty installation.

## Validation and installation

```sh
just test-tools
just test-python -p test_dotpkgs.py -p test_brewfile.py -p test_agents.py
just test-shell tests/bats/hooks/shell-banner*.bats tests/bats/packages/fork-reconcile.bats tests/bats/packages/brew-inventory.bats
```

From the desired checkout, preview and apply only the helper and banner:

```sh
chezmoi -S "$PWD/home" diff --recursive ~/.local/bin/dotpkgs ~/.local/lib/dotpkgs ~/.config/dotfiles/shell-banner
chezmoi -S "$PWD/home" apply --parent-dirs --recursive --exclude=scripts ~/.local/bin/dotpkgs ~/.local/lib/dotpkgs ~/.config/dotfiles/shell-banner
cd /tmp
command -v dotpkgs
dotpkgs --help
dotpkgs --json doctor
```

Fixture tests substitute processes/HTTP transport at the external boundary.
They prove planning, policy classification, declaration preservation, failure
handling, and consumer wiring. Live read-only checks prove current parser
compatibility; they do not prove every real install/update path. Test writes
use temporary homes and source trees. Real upgrades remain user-invoked.

Command references: [Homebrew](https://docs.brew.sh/Manpage),
[mise outdated](https://mise.jdx.dev/cli/outdated.html),
[gh extension install](https://cli.github.com/manual/gh_extension_install),
[gh native pin metadata](https://github.com/cli/cli/blob/v2.101.0/pkg/cmd/extension/extension.go#L150-L173),
[Cursor CLI installation](https://docs.cursor.com/en/cli/installation), and
[CLI creator](https://github.com/openai/skills/tree/main/skills/.curated/cli-creator).
Native installer URLs and local `--help` output are also implementation evidence.
