# mise Conventions

Use this document when installing a global CLI, selecting a tool version for a
worktree, or editing machine-wide mise configuration.

mise reads the materialized target under `~/.config/mise/`. Durable
machine-wide configuration lives under `home/dot_config/mise/` in the
dotfiles source. When inside a dotfiles worktree, edit that active checkout.
Outside one, resolve the configured source with `chezmoi source-path` or use
`chezmoi edit`; do not hand-edit the target or assume `~/dotfiles` is the
checkout being changed.

## Defaults

- Install ecosystem CLIs through mise when an `npm:`, `cargo:`, `pipx:`, `go:`,
  or similar backend exists. Use Homebrew for native binaries that do not fit a
  mise backend.
- Prefer mise selection with `mise use`, `mise link`, or a repo-owned
  `mise run <tool>:use` task over replacing an installation through Homebrew,
  npm, cargo, or pipx.
- For a worktree-local experiment, select or link the version with mise and
  keep the choice in ignored `mise.local.toml`.
- When a repo-owned `mise run <tool>:use` task provides a global lane, use it
  for host-local channel selection. The current `codex:use` task writes the
  target-only `~/.config/mise/conf.d/zz-local.toml`; do not add that file to
  the source tree or commit its selections.
- Commit durable machine-wide selections under `home/dot_config/mise/` in the
  active dotfiles checkout.
- Check whether an existing managed tool already satisfies the need before
  adding another one.

## Configuration layout

- Keep language runtimes and their ecosystem package managers in the source
  file `home/dot_config/mise/conf.d/runtimes.toml`.
- Keep other CLIs in `home/dot_config/mise/conf.d/clis.toml`, grouped by
  purpose rather than install backend.
- Sort full keys alphabetically inside each purpose section.
- Add an inline comment when the binary name, install source, or paired skill is
  not obvious.
- Keep a tool-owned environment setting in `clis.toml` when it is a single line.
  Move roughly three or more related settings, hooks, or environment values to
  `conf.d/<name>.toml`.
- Leave the source `home/dot_config/mise/config.toml` empty; `conf.d/` owns
  managed entries.

The architectural reason for this split lives at
`docs/adr/0005-mise-tool-management.md` in the same dotfiles checkout.

## Completion

- Confirm the edited TOML parses and the selected tool resolves through mise.
- Keep experimental selections local and durable selections in the appropriate
  committed dotfiles `conf.d/` file.
