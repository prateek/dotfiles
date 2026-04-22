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
