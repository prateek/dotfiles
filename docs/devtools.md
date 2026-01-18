# devtools (stable vs local dev builds)

This repo includes a small system for switching individual CLI tools between:

- **stable**: whatever you already have on `PATH` (Homebrew, mise, etc.)
- **dev**: a locally-built version (e.g. from a GitHub PR)

It’s built around a generic shim plus simple config.

## How it works

1. `devtool shim <tool>` creates `~/bin/<tool>` as a symlink to `~/dotfiles/bin/devtool-shim`.
2. When you run `<tool>`, `devtool-shim` decides what to execute:
   - Local override: it walks up from `$PWD` looking for `.devtools.toml`
   - Global default: `~/.config/devtools/config.toml`
   - If nothing is configured, it falls back to `stable`

## Config (global vs directory scope)

Global config (symlinked by `bootstrap.sh`):
- `~/.config/devtools/config.toml` (tracked at `~/dotfiles/.config/devtools/config.toml`)

Directory-scoped overrides:
- `.devtools.toml` (put it at a repo root; applies to that directory + children)

Format (subset of TOML):

```toml
[tools]
codex = "stable"
ralph-tui = "pr-118"
```

Selector values:
- `stable`
- `pr-<num>` (installed by `devtool install github-pr ...`)
- `path:/absolute/path`

Tip: you probably want to add `.devtools.toml` to each project’s `.gitignore`.

## Install from a GitHub PR

Rust (Cargo) example:

```sh
devtool shim codex
devtool install github-pr codex openai/codex 9451 --type rust --use --global
```

Then to switch back:

```sh
devtool use -g codex stable
```

## Node CLIs (bun / pnpm / npm)

For Node-based CLIs, `devtool install github-pr ... --type node`:
- checks out the PR into a devtools worktree
- runs install via `--pm auto|npm|pnpm|bun` (auto detects from lockfiles)
- runs a build step automatically **only if** `package.json` has a `scripts.build`
  - otherwise pass `--build '<cmd>'`
- creates an executable wrapper under the install prefix

Example:

```sh
devtool shim my-cli
devtool install github-pr my-cli myorg/my-cli 123 --type node --pm pnpm --use --global
```

If your repo doesn’t use `scripts.build`:

```sh
devtool install github-pr my-cli myorg/my-cli 123 --type node --pm pnpm --build 'pnpm run compile'
```

## Adding support for another tool type

Everything is implemented in `bin/devtool`:
- installers should create an executable at:
  - `${DEVTOOLS_HOME:-$XDG_DATA_HOME/devtools}/installs/<tool>/<selector>/bin/<tool>`
- selectors are just strings stored in `[tools]`

To add a new type, extend `install_github_pr()` with a new `case "$type" in ...`.

