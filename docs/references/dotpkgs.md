---
status: active
doc_type: reference
created: 2026-10-12
updated: 2026-10-12
related:
  - ../plans/package-helper-plan.md
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
dotpkgs status                         # all available managers
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

`list` avoids upstream comparisons. `status` refreshes successful snapshots under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/dotpkgs/`; `status --cached` returns the
original `checked_at`, not a fresh timestamp. A failed probe returns an error
and preserves the previous snapshot. A cache read never substitutes for a live
check silently. Every successful mutation invalidates its manager snapshot.

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
| `gh` | Extension install/remove/update and native pin/unpin. Pins are read from native manifest/Git metadata, survive normal updates, and are not fresh-machine declarations. Pin changes may remove/reinstall the selected extension; an installation failure can leave it absent. |
| `zinit` | Install/remove simple `zinit light` declarations, update through zinit, and persist `ver` pins in the shell source. Tracked local edits block updates. |
| `apm` | Shared-graph acquisition, declaration pin changes, guarded removal, and validation. Review acquired changes, repair patches, and bump affected plugin versions before installing accepted inputs. Installing an existing dependency validates/materializes the entire marketplace. |
| `mas` | Install/remove declarations and native app operations. Authentication/admin access may be required. No version-pin API. |
| `setapp` | Install missing declared apps and reversibly remove bundles/declarations. Updates require the signed Setapp client and are reported as manual steps. No version-pin API. |
| `xcode` | Install/select the pin, change the pin, install latest stable, or remove an explicit version. Review the related iOS runtime/device policy after version changes. |
| `raycast` | Rebuild local extensions; bulk latest resolves dependency versions, updates source manifests/lockfiles, and rebuilds. Removal requires an explicit source change and removal of the imported bundle in Raycast; the helper refuses it before writes. Git and lockfiles own source version policy. |
| `externals` | Refresh declared checkouts and fast-forward updates. Add/remove/ref changes require editing the owning chezmoi external declaration; no generic source editor is exposed. |
| `swift` | Build declared helpers and record source/binary digests. Removal archives the binary and disables its owning hook through `package_policy.swift`. Git owns source version policy. |

Unsupported operations fail before writes. `managers` repeats the relevant
limits at the command line. `exec` is an explicit native escape hatch: it does
not reconcile declarations, invalidate caches, take the write lock, or classify
the operation as read-only. Native arguments must follow a literal `--`.
Helper options belong before that separator and work on either side of the
manager, as in `exec --dry-run brew -- info git` or
`exec brew --dry-run -- info git`. Missing separators fail before invoking the
native command. Everything after the separator is passed literally. Use it for native
capabilities the helper does not abstract.

Dry runs show source diffs and exact command arguments, including any manual
steps. A planning error prevents the entire invocation from executing.
Unavailable managers are skipped during bulk updates. Successful plans merge
edits to shared files before execution and reject intervening source changes.
A process lock serializes dotpkgs writes. Source edits happen first; if a native
command fails, completed effects and desired-source edits remain visible.
Execution stops and returns nonzero rather than attempting an unsafe rollback.
Quarantined files are retained under the state directory's `removed/` tree.

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

`managers` shows owner-level guidance. Every planned step shows a `sudo` label
and reason in text and a `privilege:{sudo,reason}` object in JSON. Values are
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

Read failures are per-manager `{"manager":"mise","status":"error","error":"mise outdated exited 1"}`
records with top-level `ok:false`; successful managers retain their results.
Usage failures use `{"schema_version":1,"ok":false,"error":"..."}`.
Write results include `plan:{edits:[{path,diff}],steps:[{type,privilege,...}],notes:[]}` and a status
of `planned`, `completed`, `manual`, `skipped`, or `error`.
Doctor reports prerequisite availability and the source path; `managers`
returns the provider catalog; `exec` returns its native argument vector.
Native write output goes to stderr so JSON stdout stays parseable.
Exit codes: 0 success, 1 incomplete/failed operation, 2 invalid input or setup,
130 interruption. The banner protocol also uses 3 for a missing manager.

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
package state once per run. Failed inventory probes stop the audit with an
explicit diagnostic; they must not be interpreted as an empty installation.

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
