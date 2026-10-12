# Shell Banner

Cached, multi-source banner that fastfetch renders on every interactive
non-SSH shell. Each row reflects a separate source — chezmoi drift, Homebrew
formulae and casks, mise tools, and apm agent skill packages — backed by a
small per-source cache so the shell never blocks on the underlying check.

## Runtime flow

1. `home/dot_config/zsh/extra/shell-banner.zsh` sources `shell/zsh.zsh`.
2. The adapter exits unless the shell is interactive, stdout is a TTY, `TERM`
   is set and not `dumb`, no `SSH_TTY` / `SSH_CONNECTION` is present, and the
   feature is enabled.
3. The adapter invokes `fastfetch --config ~/.config/fastfetch/config.jsonc`
   (or its own one-line drift fallback when fastfetch isn't on `PATH` yet).
4. The fastfetch config has one `command` module per source, each calling
   `bin/module <source>` to print a tiny pre-rendered row from cache.
5. After fastfetch returns the adapter starts `bin/refresh --if-stale` in the
   background. That walks every enabled source, reruns the underlying check
   when its TTL has passed or either rendered row is missing, and rewrites that source's `module.txt` /
   `module.ansi` / `state.env` / `updated_at`.

## Sources

| Source  | Outdated check                                                                | Total                                       | Default TTL |
|---------|-------------------------------------------------------------------------------|---------------------------------------------|-------------|
| chezmoi | `chezmoi status [--exclude=scripts]`                                          | `chezmoi managed --include=dirs,files,symlinks` | 1h      |
| brew    | `dotpkgs summary --manager brew` | shared package inventory | 24h |
| mise    | `dotpkgs summary --manager mise` | shared package inventory | 12h |

Package checks belong to `dotpkgs`, installed in `~/.local/bin`. Brew compares
its catalog and receipts; mise checks both permitted versions and newer releases
beyond pins. Rows include pinned-outdated and unknown counts when present.
The helper runs machine operations from the home directory. The banner keeps
its own display cache, TTLs, locks, and background refresh.

APM remains opt-in. Its adapter now uses `dotpkgs` to read the repository's shared
root lock and compare upstream commits; it does not use the retired per-package
lock layout. Enable it in both `DOTFILES_BANNER_SOURCES` and fastfetch's module
configuration when wanted. `DOTFILES_BANNER_DOTPKGS_BIN` can override the helper
path, including for isolated tests.

See `dotpkgs --help` and `docs/references/dotpkgs.md` in the source repository for
operations, JSON output, and provider limits.

If a source's binary isn't on `PATH`, that row reads `unavailable (… not
installed)` and the source skips its underlying check until the binary appears.

Example render in libghostty (Nerd Font icons, 24-bit RGB, acenoster-style
tree grouping with per-section accent color). Four sections, 13 rows:

```text
prungta@host
────────────
 ╭─    os         macOS Sequoia 15.5
 ├─    shell      zsh 5.9
 ╰─    terminal   ghostty

 ╭─    host       MacBook Pro 16-inch
 ├─  󰍛  cpu        Apple M4 Pro (14)
 ├─  󰍹  gpu        Apple M4 Pro (20)
 ╰─    memory     31 / 48 GiB (65%)

 ╭─    display    7680x2160 @ 60 Hz
 ├─    disk       137 / 460 GiB (30%)
 ├─  󰁹  battery    100% [AC Connected]
 ├─  󰄉  uptime     12 days, 12 hours
 ╰─    processes  845

 ╭─    chezmoi     0 / 1255 drifted   · checked 09:42
 ├─    brew        12 / 440 outdated  · checked 09:42
 ╰─    mise        1 / 15 outdated    · checked 09:42
```

Section accent colors: system green, hardware yellow, state blue,
drift magenta. Row keys are hand-padded in `~/.config/fastfetch/config.jsonc`;
adjust there if you add or rename a row.

## Configuration

Defaults live in `feature.env`:

```sh
DOTFILES_BANNER_ENABLED=1
DOTFILES_BANNER_SOURCES=chezmoi,brew,mise   # apm deferred — see Sources note above
DOTFILES_BANNER_CHEZMOI_ENABLED=1
DOTFILES_BANNER_CHEZMOI_SCOPE=files
DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS=3600
DOTFILES_BANNER_BREW_ENABLED=1
DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS=86400
DOTFILES_BANNER_MISE_ENABLED=1
DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS=43200
DOTFILES_BANNER_APM_ENABLED=1
DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS=43200
```

`DOTFILES_BANNER_CHEZMOI_SCOPE=files` runs `chezmoi status --exclude=scripts`.
`apply` runs plain `chezmoi status`, including pending scripts.

Machine-local overrides go in `local.env` next to `feature.env`. The file is
intentionally unmanaged (gated by `home/.chezmoiignore`) and supports simple
`KEY=value` lines only:

```sh
DOTFILES_BANNER_ENABLED=0
DOTFILES_BANNER_SOURCES=chezmoi,brew
```

## Runtime state

```text
${XDG_STATE_HOME:-~/.local/state}/dotfiles/shell-banner/
  sources/
    chezmoi/{state.env, module.txt, module.ansi, status.txt, updated_at, last_error, refresh.lock/}
    brew/...
    mise/...
    apm/...
```

That tree is written under `umask 077` so cached status output stays private.
Each source's underlying check runs under the caller's umask instead: chezmoi
derives its target file modes from the umask, so probing under 077 makes it
report every managed entry as drifted.

The old `chezmoi-drift` feature was superseded by this one. Applying this branch removes the old loader and the known deployed feature
files through `.chezmoiremove`, preserving `local.env` and user-added files.
Old machine-local state can be removed with:

```sh
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/chezmoi-drift"
```

## Manual operations

```sh
# Refresh every enabled source now (foreground).
~/.config/dotfiles/shell-banner/bin/refresh

# Refresh just one.
~/.config/dotfiles/shell-banner/bin/refresh --source brew

# Preview the banner exactly as a new shell would render it.
~/.config/dotfiles/shell-banner/bin/preview

# Inspect what's currently cached for one source (what fastfetch would print).
~/.config/dotfiles/shell-banner/bin/module brew
```

The module reader and refresh both load `feature.env` and `local.env`, including
`DOTFILES_BANNER_STATE_DIR`. Fastfetch command paths honor `XDG_CONFIG_HOME` and
`DOTFILES_BANNER_ROOT`, including paths with spaces. Deselected or disabled
sources display `disabled`; disabling every source leaves system information
available and makes automatic refresh a no-op.

`bin/refresh` is safe to run concurrently — each source has its own lock with
mtime-based grace and an absolute age cap. A persistent `refresh.lock.guard`
file uses zsh's kernel advisory lock to serialize directory-lock acquisition,
stale recovery, and owner-checked release. The guard is never unlinked and is
released automatically if the process dies. Contending refreshers skip their
check; a normal refresh holds the guard only during lock bookkeeping.

The age cap is 10 minutes and is deliberately absolute: PID liveness is not
consulted, because macOS recycles PIDs fast enough to keep a dead owner's lock
alive for hours. A check still running after 10 minutes therefore loses its
lock and can be started a second time.

The shell adapter (`shell/zsh.zsh`) runs the whole flow inside a subshell so
the helper functions (`banner_*`) and config variables (`BANNER_*`,
`DOTFILES_BANNER_*`) never leak into the user's interactive shell.
