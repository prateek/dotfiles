# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS configuration, containing shell configurations, application settings, and automation scripts. The repository uses zsh with zinit plugin management and emphasizes vim keybindings and fuzzy finding workflows.

## Common Commands

### Setup and Installation
- `./bootstrap.sh` - Initial setup script that installs homebrew packages, creates symlinks, and configures the environment
- `brew bundle install --file Brewfile` - Install all homebrew packages and applications from the Brewfile

### Shell Management
- `sz` (alias) - Reload zsh configuration (`exec zsh`)
- `ez` (alias) - Open dotfiles in VSCode (`code ~/dotfiles`)
- `jz` (alias) - Jump to dotfiles directory (`cd ~/dotfiles`)

### Git Workflow (via aliases in zsh/lib/alias.zsh)
- `gs` - Git status with scmpuff integration
- `gco` - Git checkout
- `gcf` - Fuzzy find git branch checkout using fzf
- `gbd` - Fuzzy delete multiple git branches using fzf
- `fgl` - Interactive git log browser with fzf
- `gl` - Git log with custom formatting
- `push`/`pull` - Push/pull current branch to/from origin

## Architecture

### Directory Structure
- `zsh/` - Zsh configuration modules
  - `autoload/` - Custom functions auto-loaded by zsh
  - `lib/` - Core zsh libraries (aliases, keybindings, completions, etc.)
  - `extra/` - Additional configurations loaded last (overrides)
- `vscode/` - VSCode settings, keybindings, and extensions
- `scripts/` - Utility scripts and browser extensions
- `osx-apps/` - macOS application preference files
- `keyboard/` - Mechanical keyboard configurations

### Configuration Loading Order
1. `zshenv` - Sets up environment variables and paths
2. `zprofile` - Profile-specific configurations
3. `zshrc` - Main shell configuration that sources `init.sh`
4. `init.sh` - Loads zinit, autoload functions, and zsh library modules
5. `zinit-init.zsh` - Plugin management and external tool setup
6. `zsh/lib/*.zsh` - Core functionality (aliases, completions, keybindings)
7. `zsh/extra/*.zsh` - Final overrides and customizations

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
- `macos` script contains extensive system preference customizations
- Homebrew Brewfile manages package installations
- Application-specific preference files in `osx-apps/`
- Custom keyboard layouts and shortcuts

## Environment Variables
- `DOTFILES` - Path to this dotfiles directory
- `ZSHCONFIG` - Points to `$DOTFILES` for zsh configuration
- `GHPATH` - GitHub projects directory for ghclone function