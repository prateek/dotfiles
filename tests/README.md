# Tests

Run docs lifecycle checks:

```sh
make test-docs-lifecycle
```

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

`make test-agent-skill-packages-native` requires Claude Code's `claude`
command because it validates the generated local plugin marketplace with
`claude plugin validate`.

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
