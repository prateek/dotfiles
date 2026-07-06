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
make test-elevation-render
make test-zsh-prompt-host
make test-mise-install-script
make test-gh-extensions-script
make test-xcode-install-script
make test-secret-backed-files
make test-chezmoi-apply
make test-chezmoi-config
make test-karabiner-goku
make test-chezmoi-local-ignores
make test-chezmoi-script-status
make test-chezmoi-drift-banner
make test-codex-config
make test-agentsview-config
make test-claude-settings
make test-claude-statusline
make test-pi-settings
make test-pi-statusline
make test-orca-settings
make test-crit-config
make test-agent-skill-packages
make test-agent-skill-packages-native
make test-selected-app-plists
make test-tartelet-settings
make test-tartelet-softnet-wrapper
make test-plist-hooks
make test-sudo-keepalive
make test-macos-defaults-script
make test-brew-inventory
make test-brew-install-wrapper
make test-brew-bundle-script
make test-fork-reconcile
make test-trace-perfetto
make test-vm-install-log-scan
make test-vm-postflight-macos
```

`make test-trace-perfetto` covers the zsh xtrace converter, function-derived span layout, trace merge behavior, private artifact permissions, conversion failure handling, and the local Perfetto viewer URL helper.

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

Run native Claude Code plugin validation for generated local plugins:

```sh
make test-agent-skill-packages-native
```

Run `repo-index` canonical clone discovery tests:

```sh
make test-repo-index
```
