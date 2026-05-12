# Chezmoi Drift Banner

This directory owns the cached shell banner that reports managed chezmoi drift.
Shell startup only gates and prints prepared cache files. It does not run
foreground `chezmoi`, install a `precmd` hook, or invoke external renderers.

## Runtime Flow

`shell/zsh.zsh` is sourced from the zsh `extra` directory. It exits unless the
shell is interactive, stdout is a TTY, `TERM` is not `dumb`, and the feature is
enabled.

When a cached banner is present, the adapter prints `banner.ansi` unless
`NO_COLOR` is set. It prints `banner.txt` otherwise. It records the last shown
signature in the state directory so repeated shells do not spam the same drift
message.

If the cache is missing or stale, the adapter may start `bin/refresh --if-stale`
in the background. The refresh command owns the `chezmoi status` call, drift
signature, lock, display cache, and error file.

## Configuration

In the source state, defaults render from `feature.env.tmpl` into the target
`feature.env` file:

```sh
DOTFILES_CHEZMOI_DRIFT_ENABLED=1
DOTFILES_CHEZMOI_DRIFT_SCOPE=files
DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=3600
DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=21600
DOTFILES_CHEZMOI_DRIFT_RENDERER=compact
DOTFILES_CHEZMOI_DRIFT_PALETTE=amber
DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE=off
```

`DOTFILES_CHEZMOI_DRIFT_SCOPE=files` runs `chezmoi status --exclude=scripts`.
`DOTFILES_CHEZMOI_DRIFT_SCOPE=apply` runs plain `chezmoi status`, including
pending scripts.

Machine-local overrides can live in `local.env` next to `feature.env`. This file
is intentionally unmanaged and supports simple `KEY=value` lines only. Use it
for local opt-outs such as:

```sh
DOTFILES_CHEZMOI_DRIFT_ENABLED=0
```

## State

Runtime state is under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/chezmoi-drift/`:

```text
state.env
banner.txt
banner.ansi
status.txt
signature
updated_at
last_shown
last_shown_signature
last_error
refresh.lock/
```

`last_error` records refresh failures. Startup ignores it and keeps using any
existing cache.
