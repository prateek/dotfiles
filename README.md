# Dotfiles Repo
My dotfiles + macOS bootstrap.

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
- Install Homebrew plus Git, chezmoi, and uv if missing
- Apply chezmoi source state from `home/`
- Run package, shell, runtime, Hammerspoon, and defaults setup through `.chezmoiscripts/`

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

Managed app config includes Chrome policy, cmux, Ghostty, Hammerspoon, Ice, Kanata, Leader Key, Moom, nvALT, OrbStack, VoiceInk, VS Code, and Zed. Kanata owns keyboard remaps; the Karabiner-Elements install remains only for its macOS virtual HID driver. Moom uses a selected XML plist patch so layouts and hotkeys stay native without committing update/window/license state. Volatile state, credentials, licenses, and account databases stay local or in 1Password.

## Shell helpers

- Directory jumping: `j <query>` is powered by `zoxide` (imports a legacy `~/Library/autojump/autojump.txt` once, if present).
- Dev tool overrides use mise tasks and linked prefixes. See `dev/docs/mise-tool-management-plan.md`.
- Gemini meeting sync uses repo-owned config at `home/dot_config/gemini-meeting-sync/config.json`. The `enabled` marker is local and is created with `gemini-meeting-sync enable`.

## Auditing what to remove / what’s tracked

- Package usage report (no changes): `./scripts/audit/brewfile-usage.sh`
- Brew inventory diff (taps + formulae): `./scripts/audit/brew-inventory.sh`
- App inventory (find non-brew apps): `./scripts/audit/app-inventory.sh`
- App config report: `./scripts/audit/settings-coverage.sh`
- macOS settings coverage (selected keys): `./scripts/audit/macos-settings-coverage.sh`

`home/.chezmoidata/apps/` is apply-only. Add an app TOML there only when the repo needs an app index for defaults, generated policy, or selected plist/file ownership. Simple native config lives directly under `home/`; if it should follow package profiles, gate the target in `home/.chezmoiignore` instead of rendering `{}` for profiles that do not install the app. The app config report covers app indexes only, so native-file apps like Ghostty, Hammerspoon, VS Code, and Zed get focused tests instead. Nested preference plists should use selected readable source under `home/` or `home/.chezmoiassets/` plus a chezmoi `modify_` target instead of a whole-domain plist dump.

Secret-backed configs and license files are private chezmoi templates under `home/`. Add config target paths to `home/.chezmoidata/secrets.toml` under `secrets.paths`, add license target paths to `home/.chezmoidata/licenses.toml` under `licenses.paths`, store only obfuscated `op://` refs in `secrets.refs`, and render the template with `onepasswordRead` behind `secrets_enabled`. Apply them explicitly:

```sh
DOTFILES_SECRETS_ENABLED=true dotfiles apply chezmoi
```

App captures include a local Mackup discovery source under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/app-settings/mackup-source/`. Those files are local evidence, not committed desired state.

`bin/dotfiles` is a uv-backed Python script with an inline `requires-python` declaration, so bootstrap installs uv before handing off to chezmoi.

Note: Mac App Store entries are omitted from generated Brewfiles by default. Set `DOTFILES_INSTALL_MAS_APPS=true` or render with `--include-mas` to opt in on a signed-in machine.

## Package profiles

Homebrew package intent lives in `home/.chezmoidata/packages.toml`, not root Brewfiles. The core profile is the faster bootstrap/smoke profile. The full profile adds workstation taps, CLIs, casks, fonts, and opt-in Mac App Store entries.

The audit scripts default to the full package profile. Pass `BREWFILE_PROFILE=core` when checking the core profile:

```sh
BREWFILE_PROFILE=core ./scripts/audit/brew-inventory.sh
BREWFILE_PROFILE=core ./scripts/audit/brewfile-usage.sh
```

Setapp is installed by Homebrew, but Setapp-managed apps are installed after Setapp login. Do not add app config for Setapp-installed apps until the repo also has an install path for that app. For scripted Setapp installs, use `setapp-cli`: https://github.com/maximlevey/setapp-cli

## CI / tests

This repo has lightweight “don’t break bootstrap” checks on every PR.

What CI runs (GitHub Actions):
- Shellcheck on the install/OS scripts.
- macOS smoke tests (dry-run): `./install.sh --core --dry-run` and `./install.sh --full --dry-run`.
- Tart helper contract tests without booting a VM.
- Perfetto trace conversion tests for zsh xtrace, function-derived spans, merge behavior, and the local viewer helper.
- Package-data rendering: `bin/dotfiles render brewfile --profile core|full`.
- Core package install check (formulae only; casks/mas skipped): generated core Brewfile output passed to `brew bundle install`.

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
make test-install-tart-full                                    # slower; uses the Xcode image by default
make test-install-tart-smoke TART_CPU=1 TART_MEMORY=3072       # smaller VM
make test-install-tart-smoke TART_FLAGS=--keep-vm              # debug
make test-install-tart-full TART_FULL_IMAGE=ghcr.io/...:latest # override full image
DOTFILES_TRACE=1 make test-install-tart-smoke                  # Perfetto trace artifacts
```

The smoke and dry-run lanes default to `ghcr.io/cirruslabs/macos-tahoe-base:latest`.
The full lane defaults to `ghcr.io/cirruslabs/macos-tahoe-xcode:latest` because full package validation includes Xcode-dependent tools such as SwiftLint.
Full-profile package application updates Homebrew before `brew bundle` so prebuilt VM images do not use stale cask metadata.
Mac App Store entries are not rendered unless `DOTFILES_INSTALL_MAS_APPS=true` is set.
The smoke lane uses the core profile and skips Homebrew casks/MAS so it mirrors CI's formulae-only install shape.
Every Tart run prints a slowest-phase timing summary. Package scripts also emit `TIMING|...` lines for `brew update`, taps, `brew bundle`, `mise install`, and defaults application.
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

## Package Data

Homebrew package intent lives in `home/.chezmoidata/packages.toml`. To inspect the Homebrew bundle input that the install scripts use:

```sh
bin/dotfiles render brewfile --profile core
bin/dotfiles render brewfile --profile full
bin/dotfiles render brewfile --profile full --include-mas
```

## Chrome Extensions

- Chrome policy in `home/.chezmoidata/apps/chrome.toml` defines the force-install baseline: 1Password, Dark Reader, Vimium, Tampermonkey.
- Extension *settings* are **not** snapshotted from your Chrome profile (too easy to accidentally capture secrets/cookies). Prefer Chrome Sync + each extension’s own sync/export.

## Runtimes (mise)

Node/Go/Ruby are managed via `mise` using `home/dot_config/mise/config.toml`. Ruby uses mise's signed precompiled artifacts when available, so clean installs do not compile Ruby from source unless mise has no matching artifact.

Chezmoi materializes `home/dot_config/mise/tasks` into `~/.config/mise/tasks` so repo-owned mise tasks are available outside the dotfiles checkout.

Codex channel switching is a mise task:

```sh
mise run codex:use latest
mise run codex:use --local main
mise run codex:use --local pr 19776
```

## Manual steps (expected on a clean Mac)

- Install Xcode Command Line Tools: a one-time GUI prompt will appear (triggered by `install.sh`).
- Sign in: 1Password, Setapp, Tailscale, etc.
- Approve permissions: Input Monitoring and Accessibility for `/opt/homebrew/opt/kanata/bin/kanata`, Accessibility/Input Monitoring for BetterTouchTool, Karabiner VirtualHIDDevice, Screen Recording for VoiceInk, and any “Privacy & Security” prompts (e.g. Tailscale system extension).

To skip macOS defaults during install: `SKIP_MACOS_DEFAULTS=1 ./install.sh`.

## Capturing settings from an existing Mac

```sh
./scripts/macos/capture.sh
```

This writes machine-local captures under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`. Raw captures are not committed.
