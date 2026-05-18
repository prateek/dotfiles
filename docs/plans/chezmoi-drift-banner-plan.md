---
status: archived
doc_type: plan
owner: Prateek
created: 2026-05-11
updated: 2026-05-15
closed: 2026-05-15
current_guidance:
  - ../../home/dot_config/dotfiles/chezmoi-drift/README.md
related:
  - ../../tests/chezmoi-drift-banner.zsh
status_detail: "Implemented. Current behavior and configuration live with the managed source under home/dot_config/dotfiles/chezmoi-drift/."
---

# Chezmoi Drift Banner Plan

## Goal

Show a quiet shell banner when managed dotfiles drift from chezmoi source state,
without adding foreground startup work.

## Shape

The feature is contained under
`home/dot_config/dotfiles/chezmoi-drift/`, plus one zsh extra loader at
`home/dot_config/zsh/extra/chezmoi-drift.zsh`.

The startup adapter only:

- checks whether the shell can show a banner;
- reads prepared cache files;
- prints `banner.ansi` or `banner.txt`;
- records the last shown signature;
- starts `bin/refresh --if-stale` in the background when the cache is missing
  or stale.

It does not call foreground `chezmoi`, install `precmd`, use cron or launchd, or
depend on external rendering tools.

## Runtime State

Runtime state lives under
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

## Configuration

Defaults:

```sh
DOTFILES_CHEZMOI_DRIFT_ENABLED=1
DOTFILES_CHEZMOI_DRIFT_SCOPE=files
DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=3600
DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=21600
DOTFILES_CHEZMOI_DRIFT_RENDERER=compact
DOTFILES_CHEZMOI_DRIFT_PALETTE=amber
DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE=off
```

`files` runs `chezmoi status --exclude=scripts`, which avoids script-run noise.
`apply` runs plain `chezmoi status`, including pending scripts.

## Validation

Focused regression coverage lives in `tests/chezmoi-drift-banner.zsh`.

Before handoff, run:

```sh
tests/chezmoi-drift-banner.zsh
scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$PWD"
scripts/audit/zsh-fresh-shells.zsh bench --dotfiles-root "$PWD"
chezmoi --source "$PWD/home" apply --dry-run --verbose --include=scripts
chezmoi --source "$PWD/home" apply --dry-run --verbose --include=files \
  "$HOME/.config/dotfiles/chezmoi-drift" \
  "$HOME/.config/zsh/extra/chezmoi-drift.zsh"
git diff --check
```
