# Dotfiles Repo
My dotfiles + macOS bootstrap (no Mackup).

## New Mac quickstart

```sh
# Recommended (one command):
curl -fsSL https://raw.githubusercontent.com/prateek/dotfiles/master/install.sh | bash

# Core-only (faster):
curl -fsSL https://raw.githubusercontent.com/prateek/dotfiles/master/install.sh | bash -s -- --core

# Or clone normally (HTTPS):
git clone https://github.com/prateek/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

This will:
- Install Homebrew (if missing) + run `brew bundle` via `Brewfile`
- Set up symlinks (zsh, nvim, Codex, etc.)
- Apply macOS + app settings via `scripts/macos/apply.sh`

If you prefer cloning via GitHub auth + SSH:

```sh
# 1) Install Xcode Command Line Tools (one-time GUI prompt)
xcode-select --install

# 2) Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 3) Install + sign in to 1Password
brew install --cask 1password

# 4) Install + auth GitHub CLI
brew install gh
gh auth login

# 5) Clone + run
gh repo clone prateek/dotfiles ~/dotfiles
cd ~/dotfiles && ./install.sh
```

Currently managed configs include: macOS defaults, Text Replacements, Alfred, iTerm2, tmux, Moom, Leader Key, Karabiner-Elements, BetterTouchTool, OrbStack (minimal), VS Code/Cursor, and Chrome policies (extension force-install).

Terminal setup notes (iTerm2 + tmux): `docs/iterm2-tmux.md`.

## Auditing what to remove / what’s tracked

- Brewfile usage report (no changes): `./scripts/audit/brewfile-usage.sh`
- Brew inventory diff (taps + formulae): `./scripts/audit/brew-inventory.sh`
- App inventory (find non-brew / unmanaged apps): `./scripts/audit/app-inventory.sh`
- Config coverage report: `./scripts/audit/settings-coverage.sh`
- macOS settings coverage (selected keys): `./scripts/audit/macos-settings-coverage.sh`

Note: Mac App Store installs require being signed in; `bootstrap.sh` will skip them if you aren’t.

## CI / tests

This repo has lightweight “don’t break bootstrap” checks on every PR.

What CI runs (GitHub Actions):
- Shellcheck on the install/OS scripts.
- macOS smoke tests (dry-run): `./install.sh --core --dry-run` and `./install.sh --full --dry-run`.
- Brewfile parsing: `brew bundle list --all` for `Brewfile` + `Brewfile.core`.
- Core Brewfile install check (formulae only; casks/mas skipped): `brew bundle install --file Brewfile.core`.

What CI does *not* run:
- A full end-to-end install in a macOS VM (too heavy/fragile for GitHub Actions).

Local verification:

```sh
# Dry-run (no changes applied):
./install.sh --full --dry-run

# End-to-end in a clean macOS VM (Tart):
brew install cirruslabs/cli/tart
./scripts/vm/test-install-tart.sh --profile core

# Helpful flags:
./scripts/vm/test-install-tart.sh --profile full          # slower
./scripts/vm/test-install-tart.sh --profile full --dry-run # plan only
./scripts/vm/test-install-tart.sh --keep-vm               # debug
```

## Pre-commit hooks (recommended)

This repo includes a local secret-scanning hook (Gitleaks) via `pre-commit`.

```sh
# Install pre-commit (pick one):
brew install pre-commit
# or:
uv tool install pre-commit

# Install the git hook:
pre-commit install

# Run all hooks manually:
pre-commit run --all-files
```

## Chrome extensions

- Chrome policies in `osx-apps/chrome/policies/` force-install: 1Password, Dark Reader, Vimium, Tampermonkey.
- Extension *settings* are **not** snapshotted from your Chrome profile (too easy to accidentally capture secrets/cookies). Prefer Chrome Sync + each extension’s own sync/export.

## Runtimes (mise)

Node/Go/Ruby are managed via `mise` using `.config/mise/config.toml`.

## Manual steps (expected on a clean Mac)

- Install Xcode Command Line Tools: a one-time GUI prompt will appear (triggered by `install.sh`).
- Sign in: 1Password, Setapp, Tailscale, etc.
- Approve permissions: Accessibility (Karabiner, BetterTouchTool), Screen Recording (CleanShot/VoiceInk), and any “Privacy & Security” prompts (e.g. Tailscale system extension).

To skip macOS defaults: `SKIP_MACOS_DEFAULTS=1 ./bootstrap.sh`.
To preinstall Neovim plugins (optional): `DOTFILES_NVIM_LAZY_SYNC=1 ./bootstrap.sh`.

## Capturing settings from an existing Mac

```sh
./scripts/macos/capture.sh
```

This captures app `defaults` exports (see `osx-apps/defaults/`), Karabiner + BetterTouchTool config, OrbStack config (minimal), and VS Code extensions.
