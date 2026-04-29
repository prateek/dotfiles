# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Agent Guidance

- Repo-specific durable guidance lives in `AGENTS.md`.
- Use `$code-gardening` for drift handling, state sync, and intent recovery on existing codebases.
- Keep root guidance concise; when new rules recur, update `AGENTS.md` or the relevant skill instead of scattering one-off notes.

## Repository Overview

This is a personal dotfiles repository for macOS configuration, containing shell configurations, application settings, and automation scripts. The repository uses zsh with zinit plugin management and emphasizes vim keybindings and fuzzy finding workflows.

## Common Commands

### Setup and Installation
- `./install.sh` - Stage-zero macOS installer. It prepares Homebrew, Git, chezmoi, and uv, then runs `chezmoi init --apply`.
- `bin/dotfiles render brewfile --profile core|full` - Render Homebrew bundle input from `home/.chezmoidata/packages.toml`; add `--include-mas` when Mac App Store entries should be emitted.
- `bin/dotfiles apply chezmoi|packages|defaults` - Apply ongoing managed state through the dotfiles wrapper.

### Shell Management
- `sz` (alias) - Reload zsh configuration (`exec zsh`)
- `ez` (alias) - Open dotfiles in VSCode (`code ~/dotfiles`)
- `jz` (alias) - Jump to dotfiles directory (`cd ~/dotfiles`)

### Git Workflow (via aliases in `home/dot_config/zsh/lib/alias.zsh`)
- `gs` - Git status with scmpuff integration
- `gco` - Git checkout
- `gcf` - Fuzzy find git branch checkout using fzf
- `gbd` - Fuzzy delete multiple git branches using fzf
- `fgl` - Interactive git log browser with fzf
- `gl` - Git log with custom formatting
- `push`/`pull` - Push/pull current branch to/from origin

## Architecture

### Directory Structure
- `home/` - Chezmoi source state. With `.chezmoiroot = home`, entries materialize into `$HOME`.
- `home/dot_config/zsh/` - Zsh configuration modules
  - `autoload/` - Custom functions auto-loaded by zsh
  - `lib/` - Core zsh libraries (aliases, keybindings, completions, etc.)
  - `extra/` - Additional configurations loaded last (overrides)
- `home/.chezmoidata/` - Structured desired state for package profiles, app declarations, defaults, secrets, licenses, and permissions
- `home/.chezmoiscripts/` - Idempotent setup scripts run by `chezmoi apply`
- `home/Library/Application Support/Code/User/` - VS Code settings, keybindings, and snippets
- `scripts/` - Utility scripts and browser extensions
- `archive/keyboard/` - Mechanical keyboard source captures

### Configuration Loading Order
1. `home/dot_zshenv.tmpl` - Sets XDG paths, `DOTFILES`, `ZDOTDIR`, and `ZSHCONFIG`
2. `home/dot_config/zsh/dot_zprofile` - Profile-specific path and login setup
3. `home/dot_config/zsh/dot_zshrc` - Main shell configuration that sources `init.sh`
4. `home/dot_config/zsh/init.sh` - Loads zinit, autoload functions, and zsh library modules
5. `home/dot_config/zsh/zinit-init.zsh` - Plugin management and external tool setup
6. `home/dot_config/zsh/lib/*.zsh` - Core functionality
7. `home/dot_config/zsh/extra/*.zsh` - Final overrides and customizations

### Key Components
- **zinit**: Plugin manager for zsh with lazy loading
- **fzf**: Fuzzy finder integration throughout git and file workflows
- **scmpuff**: Enhanced git status display
- **pure prompt**: Minimal zsh prompt theme
- **vim keybindings**: Extensive vim-style navigation in VSCode and shell

### VSCode Configuration
- Uses vim extension with custom keybindings
- Go development optimized with gopls
- Specific configurations for different file types
- Git integration with gitlens
- Custom workspace settings for various project types

### macOS Integration
- `home/.chezmoidata/system/macos.toml` declares managed macOS defaults.
- `home/.chezmoidata/packages.toml` declares Homebrew package profiles.
- Stable app files live under their target-shaped paths in `home/`; raw captures live under XDG state.
- Custom keyboard layouts and shortcuts

## Environment Variables
- `DOTFILES` - Path to this dotfiles directory
- `ZSHCONFIG` - Points to the materialized zsh config directory, usually `~/.config/zsh`
- `GHPATH` - GitHub projects directory for ghclone function
