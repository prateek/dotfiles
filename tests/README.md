# Tests

Shell commands and hooks use Bats; structured checks use native Python
discovery, and the Raycast extension retains Node's native runner. `make test`
and `make test-ci` compose the same local macOS lane.

Read the [archived test refactoring plan](../docs/plans/test-suite-rebuild-plan.md)
for migration evidence and the completed CI receipt.
For alternatives and decision history, read the [framework comparison](../docs/research/shell-testing-framework-comparison.md).

## Choosing useful checks

Use independently worked examples or documented literals for expected behavior.
Desired configuration can prove that a merge applies its input; it cannot decide
which keys the repo should own. Pair idempotence with a concrete transformation,
and retain independent ownership, preservation, native-type, and security checks.

External call counts and ordering belong in tests when they express a contract,
such as avoiding an unnecessary rebuild or installing a dependency before its
consumer. Preference rosters, arbitrary counts, private helpers, and repeated
snapshots should use a cheaper render/parse check when they protect no distinct
behavior. Explain that tradeoff when removing an existing assertion.

For each migration, inventory the old assertions and map retained guarantees to
observable seams and independent expectations before replacing their entrypoint.
Record baseline failures separately. For a regression fix, take one intended
failing behavior to green at a time. Match `.github/workflows` locally where
practical and report host, CI, Linux, and VM evidence separately.

## Shell test authoring

Trust the checkout with `mise trust`, then run `make test-tools` once to install Bats 1.14.0 through mise and checksum-verified
bats-support 0.3.0 / bats-assert 2.1.0 under ignored `build/test-libraries/`.
Mise also selects Node 24.12.0, Python 3.14.6, and uv 0.11.26, so temporary homes do not depend
on a caller's runtime shims. Shellcheck 0.11.0 is shared with the Linux CI job.
The macOS lane requires chezmoi, ripgrep, and jq alongside its system tools.
Bats requires Bash 5 or newer and zsh. Select Bash explicitly with
`TEST_BASH=/path/to/bash` or an ignored `mise.local.toml` path override. The
compatibility gate used Bash 5.3.15 and macOS `/bin/zsh` 5.9.

`make test-shell` selects the pinned tools and discovers
`tests/bats/**/*.bats`. `make test-ci` selects that environment once for all
suites; focused recipes reuse it, including validation inside temporary copies. Use `make test-ghc` for the
checkout commands, `BATS_PATH=tests/bats/<subsystem>` for a group, or
`BATS_ARGS='--filter <pattern>'` to select cases. No selection, missing tools,
an entirely skipped suite, and any failing case return a failure status.
Use scenario-owned deadlines for process and PTY waits. The tested Bats/Bash
combination leaves its optional global timeout watchdog alive after an assertion
failure, so the suite does not enable `BATS_TEST_TIMEOUT` by default.
Tags `host`, `network`, and `vm` are excluded by default. A manual lane requires
an explicit selection such as `BATS_TAGS=host make test-shell` and documented
prerequisites beside its cases.

Load [support/common.bash](support/common.bash), call `setup_fixture`, and execute
real repo entrypoints. The fixture supplies temporary home/XDG directories and
isolates Git configuration and routing variables. Substitute external commands
in its `bin/` directory. Tool interpreters are resolved before changing home so
mise shims do not consult an empty fixture's configuration.

For example, the [checkout suite](bats/programs/github-checkout.bats) asserts the
SSH URL independently and observes the resulting directory in the same zsh
process through [its scenario](scenarios/programs/github-checkout.zsh):

```bash
load '../../support/common'

setup() { setup_fixture; }

@test "ohc explains a missing repository" {
  run_zsh 2 "$DOTFILES_ROOT/tests/scenarios/programs/github-checkout.zsh" ohc
  assert_failure 2
  assert_output ''
  assert_regex "$stderr" 'usage: ohc'
}
```

`run_zsh <expected-status> <scenario> [args...]` uses an explicit noninteractive
zsh, forwards arguments literally, separates stdout/stderr, and closes inherited
reporting descriptors before exec. Assert status and the behavior that matters.
`run_bash <expected-status> <scenario> [args...]` uses the selected Bash with
the same process and capture boundary.
Use files plus `cmp` when trailing newlines or binary bytes are part of the
contract. Startup tests must explicitly choose their startup mode and exercise
both inherited and unset `ZDOTDIR` with the target variable cleared.

[pty-dialogue.zsh](support/pty-dialogue.zsh) owns one terminal for a one-prompt
interaction: `<transcript> <prompt> <response> <command> [args...]`. It waits for
the prompt before sending a response, records command status separately, applies
bounded waits, and retains the transcript on failure. The owning process closes
the PTY on exit, interruption, or termination. It leaves the authoritative
fresh-shell validator and its host/benchmark lanes in place.

Load [support/chezmoi.bash](support/chezmoi.bash) for
`render_template <repo-relative-path> <machine-type> [override-json]`. It renders
to stdout using the temporary fixture's empty config, destination, cache, state,
and neutral hostname. State host facts explicitly when a case needs them.

## Current subsystem commands

`make test` delegates to `make test-ci`, the macOS CI entrypoint. It composes
static/docs checks, Bats discovery, native Python and Node discovery, and chezmoi
dry-runs for `ci`, `personal`, and `work`.
`make test-python` discovers the shared plist suite under `tests/config_merge/`,
migrated config, package, docs, storage, trace, and agent checks under `tests/python/`,
and the iOS audit's source-owned test root. Empty or entirely skipped Python
selections fail.
Every migrated shell harness has been retired. Raycast build hooks, macOS
defaults, secret-backed files, and retired-package cleanup participate in
ordinary Bats discovery. `make test-node` discovers the Raycast extension's
source-owned `tests/*.test.mjs` with Node 24.12.0. Its TAP reporter requires a
passing registered test: Node's automatic success for an empty file does not
count. Empty, skipped-only, missing-file, and failing selections are checked
through Bats.
Existing host, benchmark, installation, and Tart commands remain explicit lanes.
The Linux shellcheck job and macOS package-install checks remain separate.

## Checks by changed area

Use `mise exec -- make <focused-target>` for the pinned runtime environment used
by `test-ci`. Make and CI define the executable lanes; this index maps a change
to the distinct guarantees it can affect.

### App-config checks

| Changed surface | Check |
| --- | --- |
| Plist merge engine or ownership | `make test-config-merge`; [plist guidance](#plist-merge-verification) describes app selection, ownership, native types, preservation, and unchanged bytes. |
| Apply-time plist guard and relaunch | `make test-plist-hooks`; Bats drives actual hook code and terminal prompts with external app commands substituted. |
| Codex TOML / Claude JSON / Cursor JSON | `make test-codex-config`, `make test-claude-settings`, or `make test-cursor-config`; preserve credentials, approvals, and unrelated application state. |
| Agentsview TOML / Pi JSON / Orca JSON / crit JSON | `make test-agentsview-config`, `make test-pi-settings`, `make test-orca-settings`, or `make test-crit-config`; format-specific merging and launch contracts. |
| macOS defaults and app/package gates | `make test-macos-defaults-script test-package-gated-configs` for the affected behavior. |

An ordinary preference edit needs the lightest meaningful render/parse check and
a target diff preview. Render the changed template with an explicit worktree
source; parse its native format. Add merge checks when ownership, deletion,
preservation, or security changes. Apply-time hooks have their own PTY lane.

`make test-tartelet-settings test-tartelet-softnet-wrapper` uses fake external
app commands and a temporary Homebrew tree to check settings convergence,
credential exclusion, and network flag forwarding. `make test-finder-copy-path`
also requires macOS's native plist and service tools. `make test-kanata-config`
selects an explicit host case and requires an installed Kanata parser.
`make test-karabiner-goku` likewise selects the installed Goku compiler, using
a temporary Default profile and checking its mapping semantics without writing
the live Karabiner config.

Agentsview's comparison with the separate wiki producer is explicit:
`BATS_TAGS=host make test-shell BATS_PATH=tests/bats/agents/agentsview-parity.bats`.
It requires the local wiki checkout's `sync-sessions` script, or an explicit
`WIKI_SESSION_SYNC_SCRIPT` path. Ordinary discovery covers the modifier's own
ownership and archive reconciliation behavior.

### Chezmoi workflow checks

`make test-chezmoi-config test-chezmoi-local-ignores` covers initialization and
source exclusions. `make test-chezmoi-script-status` applies to a temporary home,
substitutes service commands, and verifies clean status. Use
`make test-plist-hooks test-sudo-keepalive` for app prompts and privileged-phase
lifecycle; these substitute external app and sudo commands. For drift reporting,
use `make test-chezmoi-drift-banner`. Its real PTY cases cover startup gating and
cached output; a controlled external-status handshake verifies that background
refresh does not block the prompt. The refresh CLI cases cover cache privacy,
locking, invalidation, and failure cooldown.

Keep script-aware diff/dry-run and rendered shellcheck checks for changed apply
scripts. `make test-chezmoi-apply` previews `ci`, `personal`, and `work`; Tart
installation and live-machine apply remain explicit operator lanes.

### Package and secret checks

| Change | Focused checks |
| --- | --- |
| Package data / Brewfile / install trust | `make test-render-brewfile test-brew-bundle-script test-brew-inventory test-package-gated-configs` |
| Machine layers / elevation | `make test-machines-features test-elevation-render test-chezmoi-config` |
| Secret references / licenses | `make test-secret-backed-files` |
| Fork reconciliation / adoption | `make test-fork-reconcile test-fork-lifecycle-entry test-retired-packages` |
| mise / GitHub extensions / Xcode scripts | `make test-mise-install-script test-gh-extensions-script test-xcode-install-script` for the changed installer. |

Inspect `scripts/packages/render-brewfile --machine-type <type>` for affected
types and the `--include-mas` opt-in. Tests use fake install commands; the macOS
CI formula installation step and Tart lanes validate actual installation.

### Agent-package checks

The portable project owns packaging tests: `make -C agent-marketplace check`
validates cached inputs, patches/overlays, skill entrypoints, cache exclusion, paths, critical content scanning,
versions, invocation pairs, native publication, repeatability, and export.
`make test-agent-marketplace` delegates to it; `make test-vendor-skill-patches`
remains a compatibility alias. `make test-tools` provisions its frozen APM 0.29.1
environment, and the project check runs in the required macOS CI lane.

Consumer changes use `make test-agent-skill-packages`, covering explicit policy,
artifact materialization/rollback, legacy-source ownership, and native CLI
reconciliation through subprocess fixtures. Its combined isolated chezmoi apply
covers scripts 35/36, managed symlinks, all four client configs, runtime skill
preservation, and an unchanged repeat apply. Run `make test-claude-settings
test-codex-config test-cursor-config test-pi-settings` for the four independent
config merges. `make test-skill-console` covers budget/frontmatter examples,
inventory, validation, staging, guarded edits, imported patch/overlay ownership,
paired policy/version changes, deletion, CLI behavior, and Node execution of the
shipped browser functions. Imported description/frontmatter edits refuse changed
marketplace inputs before any write, including with the dirty-write override.
Temporary Git repositories disable automatic
maintenance and carry the pinned assertion libraries for staged validation.

The [assertion migration record](../docs/research/apm-marketplace-migration-verification.md#replaced-assertions)
accounts for retired renderer and vendoring tests. SOURCE metadata generation,
chezmoi filename escaping, upstream-shaped patch paths, and catalog filtering by
local eligibility changed deliberately; their old assertions do not apply.

`make test-agent-skill-packages-native` is a separate host lane requiring both
installed clients. It builds first, then exercises all ten plugins through real
materialization/native CLI installation, versioned updates, stale-file removal,
relocation, disabled-state restoration, rollback, and artifact-root Git
consumption over local smart HTTP. It reads every Codex plugin and checks cached
payloads in both clients, with isolated HOME/CODEX_HOME/CLAUDE_CONFIG_DIR and no
model calls. Verified versions: Claude 2.1.261 and Codex 0.153.4.

Console producer verification uses `BATS_TAGS=host make test-shell
BATS_PATH=tests/bats/agents/console-native.bats` and requires the exact Claude
2.1.258 build recorded by the console. A different build fails that check;
packaging success does not certify it. `make test-crit-evals` needs authenticated
agents and network and consumes tokens. Neither is implied by fixture success.

Claude and Pi footer payloads use `make test-claude-statusline` and
`make test-pi-statusline`. The additional installed-Dash check is explicit:
`BATS_TAGS=host make test-shell BATS_PATH=tests/bats/agents/statusline-posix.bats`.

### Zsh behavior checks

Use Bats command cases and same-process scenarios for functions and wrappers.
For startup correctness, read [shell authoring](#shell-test-authoring) and run
`make verify-zsh-fresh-shells`; `make test-zsh-fresh-shells` adds the validator's
selftests and benchmark leg. `make bench-zsh-startup` remains the explicit
benchmark lane. The native host `/bin/zsh` PTY implementation in
`scripts/audit/zsh-fresh-shells.zsh` retains authority for those checks.

Run docs lifecycle checks:

```sh
make test-docs-lifecycle
```

That command runs the validator's native fixture suite and validates this
checkout. `make check-docs-lifecycle` validates only the checkout. CI discovers
the fixture cases with the other Python tests and runs the checkout check in
its static lane, so the fixtures execute once.

Run `ghc`/`ohc` URL handling tests:

```sh
make test-ghc
```

Run Raycast Orca worktree extension core tests:

```sh
make test-raycast-orca-worktree
```

Run the Raycast extension build-hook contract tests:

```sh
make test-raycast-extensions-script
```

Run the full fresh-shell selftest:

```sh
make test-zsh-fresh-shells
```

Run the authoritative fresh-shell correctness checks without the benchmark leg:

```sh
make verify-zsh-fresh-shells
```

Run the authoritative startup benchmark via `zsh-bench`:

```sh
make bench-zsh-startup
```

If `zsh-bench` is missing, bootstrap the pinned checkout:

```sh
git clone https://github.com/romkatv/zsh-bench ~/.cache/dotfiles-zsh-startup-bench/zsh-bench
git -C ~/.cache/dotfiles-zsh-startup-bench/zsh-bench checkout a3c48d65b9078ee1f8bbd4da8631a8fbc885c52a
```

Run focused repo regression tests without booting a VM:

```sh
make test-tart-install-helper
make test-render-brewfile
make test-machines-features
make test-host-mounts
make test-elevation-render
make test-zsh-prompt-host
make test-mise-install-script
make test-gh-extensions-script
make test-xcode-install-script
make test-secret-backed-files
make test-chezmoi-apply
make test-finder-copy-path
make test-chezmoi-config
make test-karabiner-goku
make test-chezmoi-local-ignores
make test-chezmoi-script-status
make test-chezmoi-drift-banner
make test-agents-doc-pointers
make test-codex-config
make test-agentsview-config
make test-reconcile-wiki-clone
make test-claude-settings
make test-claude-statusline
make test-pi-settings
make test-pi-statusline
make test-orca-settings
make test-crit-config
make test-acpx-model-drift
make test-acpx-poll-stream
make test-agent-skill-packages
make test-agent-skill-packages-native
make test-ios-audit
make test-config-merge
make test-tartelet-settings
make test-tartelet-softnet-wrapper
make test-plist-hooks
make test-sudo-keepalive
make test-macos-defaults-script
make test-brew-inventory
make test-brew-install-wrapper
make test-brew-bundle-script
make test-fork-reconcile
make test-retired-packages
make test-trace-perfetto
make test-vm-install-log-scan
make test-vm-postflight-macos
```

`make test-host-mounts` uses simulated macOS disk commands and fstab probes,
plus real isolated chezmoi applies, to verify mount recovery, data preservation,
and failure before modifiers or package setup. It also covers attached option
values, preview flags outside JSON data, and both zsh startup paths with an
absent configured SSD directory. It does
not mount or unmount a physical disk.

`make test-chezmoi-script-status` applies into a temporary home and uses test
executables for `launchctl` and Orca. A temporary home alone does not isolate
the caller's launchd services or app runtime.

`make test-trace-perfetto` covers the zsh xtrace converter, function-derived span layout, trace merge behavior, private artifact permissions, conversion failure handling, and the local Perfetto viewer URL helper.

## Plist merge verification

`make test-config-merge` checks the real merge executable, all rendered plist modifiers and scenario coverage. It requires uv, chezmoi and macOS `plutil`. The suite uses Python's standard library and temporary files; it does not read or write live preferences or invoke apply hooks.

Each entry in [config_merge/scenarios.py](config_merge/scenarios.py) supplies a bundle ID, managed input `overrides`, app-owned `local` values and independently `expected` values. A `check` callback can inspect structured app payloads or a rendered path. To add an app, add a scenario there and run the shared target. Use deliberately different current values to exercise replacement. Put local keys only in `local`: the shared check verifies they survive existing input and are absent when starting from empty input. VoiceInk's `KeyboardShortcuts_toggleEnhancement` is one such app-owned key.

The common checks render the actual adapter and desired fragment, execute the adapter with empty/XML/binary input, and verify desired values plus local state. They also assert exact bytes on a second merge and on equivalent, reordered binary input. Independent expected values and callbacks protect app intent; desired-derived checks alone cannot detect an incorrect managed preference.

Use `test.assert_typed_equal(actual, expected)` for structured app assertions. It compares types throughout dictionaries and lists, so booleans, integers and reals remain distinct; failures name the nested value. cmux shortcuts and VoiceInk prompts also independently require plist data blobs before decoding their JSON. The engine cases protect numeric type replacement, shared binary container references and unchanged NaN values. Finder's separate workflow test checks native plist types with `plutil -expect` before comparing extracted values.

[config_merge/test_discovery.py](config_merge/test_discovery.py) discovers plist modifiers under `home/`. Missing scenarios, stale entries and duplicate bundle IDs fail the suite. An exceptional modifier needs a repository-relative path and a non-empty ownership reason in `EXCEPTIONS`; there are currently no exceptions. A new app requires no Make or CI roster edit.

Existing `test-moom-plist`, `test-thaw-plist`, `test-cmux-plist`, `test-orbstack-plist`, `test-nvalt-plist`, `test-voiceink-plist` and `test-selected-app-plists` targets delegate to the same checks. `make test-tuna-plist` runs Tuna alone. For any scenario selection:

```sh
uv run --quiet --python '>=3.14' python -B tests/config_merge/run.py --app voiceink tuna
```

Run `make test-plist-hooks test-package-gated-configs` when hook or package ownership is also in scope. The separate `make test-nvalt-colors` suite protects nvALT's color archive format.

## Other validation lanes

`make test-agent-skill-packages-native` selects host cases for Claude's
`plugin validate` and Codex's app-server `plugin/read`. Each case reports a
missing CLI explicitly; a skipped producer is not validated. Use a Bats filter
to focus on either producer.

Audit tracked Orca settings against the installed app's current defaults (run
after upgrading Orca or a settings spree; refreshes the committed defaults
snapshot, and its git diff shows what an Orca upgrade moved):

```sh
make audit-orca-settings
```

Run Tart VM install checks locally:

```sh
make test-install-tart-dry-run
make test-install-tart-smoke
make test-install-tart-full
```

Smoke uses the Tahoe base image. Full uses the Tahoe Xcode image so routine validation does not spend the run downloading Xcode.

The current Tart install validation workflow is documented in `docs/runbooks/tart-mini-validation.md`.

Run focused-helper tests for the package renderer:

```sh
make test-render-brewfile
make test-machines-features
make test-elevation-render
```

Run agent skill package projection checks:

```sh
make test-agent-skill-packages
```

Run the `ios-audit` skill's source-tree unit tests:

```sh
make test-ios-audit
```

Run native Claude Code plugin validation for generated local plugins:

```sh
make test-agent-skill-packages-native
```

Run `repo-index` canonical clone discovery tests:

```sh
make test-repo-index
```
