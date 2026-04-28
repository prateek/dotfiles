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
- Install Homebrew (if missing) and apply the selected Homebrew profile
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

## Shell helpers

- Directory jumping: `j <query>` is powered by `zoxide` (imports a legacy `~/Library/autojump/autojump.txt` once, if present).
- Dev tool overrides use mise tasks and linked prefixes. See `dev/docs/mise-tool-management-plan.md`.

## Auditing what to remove / what’s tracked

- Brewfile usage report (no changes): `./scripts/audit/brewfile-usage.sh`
- Brew inventory diff (taps + formulae): `./scripts/audit/brew-inventory.sh`
- App inventory (find non-brew / unmanaged apps): `./scripts/audit/app-inventory.sh`
- Config coverage report: `./scripts/audit/settings-coverage.sh`
- macOS settings coverage (selected keys): `./scripts/audit/macos-settings-coverage.sh`

Note: Mac App Store installs require being signed in; `bootstrap.sh` will skip them if you aren’t.

## Homebrew profiles

`Brewfile.core` is the bootstrap profile for a usable shell and the main desktop tools. It is used by `./install.sh --core`, CI, and the Tart smoke lane. CI and the smoke lane skip casks and Mac App Store entries, so they only prove the core formula install path.

`Brewfile` is the full workstation profile. It should include every core entry plus workstation-specific taps, CLIs, casks, fonts, and Mac App Store apps. When auditing a laptop, update this file first and keep `Brewfile.core` small unless a tool is needed for fresh-machine bootstrap or smoke validation.

The audit scripts default to `Brewfile`; pass `BREWFILE=Brewfile.core` when checking the core profile:

```sh
BREWFILE=Brewfile.core ./scripts/audit/brew-inventory.sh
BREWFILE=Brewfile.core ./scripts/audit/brewfile-usage.sh
```

Setapp is installed by Homebrew, but Setapp-managed apps are installed after Setapp login. CleanShot X is tracked that way, not as a Homebrew cask. For scripted Setapp installs, use `setapp-cli`: https://github.com/maximlevey/setapp-cli

## CI / tests

This repo has lightweight “don’t break bootstrap” checks on every PR.

What CI runs (GitHub Actions):
- Shellcheck on the install/OS scripts.
- macOS smoke tests (dry-run): `./install.sh --core --dry-run` and `./install.sh --full --dry-run`.
- Tart helper contract tests without booting a VM.
- Perfetto trace conversion tests for zsh xtrace, function-derived spans, merge behavior, and the local viewer helper.
- Brewfile parsing: `brew bundle list --all` for `Brewfile` + `Brewfile.core`.
- Core Brewfile install check: `brew bundle install --no-upgrade --file Brewfile.core` with core casks and Mac App Store entries skipped by environment.

What CI does *not* run:
- A full end-to-end install in a macOS VM. That is local-only because it pulls a large Tart image and mutates a guest macOS install.

Local verification:

```sh
# Dry-run (no changes applied):
./install.sh --full --dry-run

# Tart helper contract tests (no VM boot):
make test-tart-install-helper
make test-trace-perfetto

# End-to-end in a clean macOS VM (Tart):
brew install cirruslabs/cli/tart
make test-install-tart-dry-run
make test-install-tart-smoke

# Helpful flags:
make test-install-tart-full                               # slower
make test-install-tart-smoke TART_CPU=1 TART_MEMORY=3072  # smaller VM
make test-install-tart-smoke TART_FLAGS=--keep-vm         # debug
DOTFILES_TRACE=1 make test-install-tart-smoke             # Perfetto trace artifacts
```

The default Tart image is `ghcr.io/cirruslabs/macos-tahoe-base:latest`.
The smoke lane uses the core profile and skips Homebrew casks/MAS so it mirrors CI's formulae-only install shape.
When tracing is enabled in local mode, guest installer spans come from zsh function structure. The trace converter derives readable track names from function names and keeps full command details in lower lanes. Remote mode records host Tart lifecycle phases only.
Tart runs use a persistent host-backed Homebrew cache by default. Set `DOTFILES_TART_HOMEBREW_CACHE_DIR` to choose the host path, or pass `--no-homebrew-cache` through `TART_FLAGS` to disable it.
For the current `mini` over SSH workflow, see `dev/docs/tart-mini-validation.md`.

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

Node/Go/Ruby are managed via `mise` using `.config/mise/config.toml`. Ruby uses mise's signed precompiled artifacts when available, so clean installs do not compile Ruby from source unless mise has no matching artifact.

Bootstrap also links `.config/mise/tasks` into `~/.config/mise/tasks` so repo-owned mise tasks are available outside the dotfiles checkout.

Codex channel switching is a mise task:

```sh
mise run codex:use latest
mise run codex:use --local main
mise run codex:use --local pr 19776
```

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
