# Tests

Harness comparison report:

```sh
open ~/dotfiles/dev/docs/zsh-harness-comparison.html
```

Run `ghc` URL handling tests:

```sh
make test-ghc
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

Run Tart install-helper contract tests without booting a VM:

```sh
make test-tart-install-helper
make test-dotfiles-cli
make test-mise-install-script
make test-settings-coverage
make test-secret-backed-files
make test-pending-app-plists
make test-trace-perfetto
make test-vm-install-log-scan
make test-vm-postflight-macos
```

`make test-trace-perfetto` covers the zsh xtrace converter, function-derived span layout, trace merge behavior, private artifact permissions, conversion failure handling, and the local Perfetto viewer URL helper.

Run Tart VM install checks locally:

```sh
make test-install-tart-dry-run
make test-install-tart-smoke
make test-install-tart-full
```

Smoke uses the Tahoe base image. Full uses the Tahoe Xcode image because the full package profile includes Xcode-dependent tools.

The current `mini` validation workflow is documented in `dev/docs/tart-mini-validation.md`.

Run managed macOS defaults coverage regression tests:

```sh
make test-macos-settings
```

Run `repo-index` canonical clone discovery tests:

```sh
make test-repo-index
```

Run `grmrepo-refresh` config-generation tests:

```sh
make test-grmrepo-refresh
```

Run E2E worktree tests:

```sh
make test-worktrees
```
