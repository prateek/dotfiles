# XDG Base Directory Migration Guide

This guide documents the migration to XDG Base Directory specification and chezmoi integration.

## Overview

The dotfiles have been migrated to follow the XDG Base Directory specification:

- **Configuration files**: `$XDG_CONFIG_HOME` (default: `~/.config/`)
- **Data files**: `$XDG_DATA_HOME` (default: `~/.local/share/`)
- **Cache files**: `$XDG_CACHE_HOME` (default: `~/.cache/`)
- **State files**: `$XDG_STATE_HOME` (default: `~/.local/state/`)

## What Changed

### Directory Structure

```
Old Structure:
~/
├── .zshrc
├── .zshenv
├── .zprofile
├── .zlogin
├── .vimrc
├── .inputrc
├── .lesskey
└── dotfiles/
    ├── zsh/
    ├── vimrc
    └── ...

New Structure:
~/
├── .zshenv (symlink for compatibility)
├── .vimrc (symlink for compatibility)
├── .inputrc (symlink for compatibility)
└── .config/
    ├── zsh/
    │   ├── .zshenv
    │   ├── .zshrc
    │   ├── .zprofile
    │   ├── .zlogin
    │   ├── init.sh
    │   ├── zinit-init.zsh
    │   ├── autoload/
    │   ├── lib/
    │   └── extra/
    ├── vim/
    │   ├── vimrc
    │   └── vimrc.orig
    ├── less/
    │   └── lesskey
    ├── readline/
    │   └── inputrc
    └── chezmoi/
        └── chezmoi.toml
```

### Key Changes

1. **Zsh Configuration**:
   - Main zsh configs moved to `~/.config/zsh/`
   - `ZDOTDIR` is set to `$XDG_CONFIG_HOME/zsh`
   - Zinit data moved to `~/.local/share/zinit/`
   - `.zshenv` in home directory redirects to XDG location

2. **Vim Configuration**:
   - Config moved to `~/.config/vim/`
   - Data/plugins stored in `~/.local/share/vim/`
   - Cache files in `~/.cache/vim/`
   - `.vimrc` in home directory sets up XDG paths

3. **Other Configurations**:
   - Less config: `~/.config/less/lesskey`
   - Readline: `~/.config/readline/inputrc`
   - Git config: `~/.config/git/config` (when migrated)

## Migration Steps

### 1. Backup Existing Configuration

```bash
# Create a backup of your current dotfiles
cp -r ~/dotfiles ~/dotfiles.backup
cp ~/.zsh* ~/.vim* ~/.inputrc ~/.lesskey ~/dotfiles.backup/
```

### 2. Run the Migration

```bash
# Clone or update the repository
cd ~/dotfiles

# Run the XDG-compliant bootstrap
./bootstrap-xdg.sh

# Install chezmoi
./install-chezmoi.sh

# Initialize chezmoi with your dotfiles
./init-chezmoi.sh
```

### 3. Verify the Migration

```bash
# Check that configs are loaded correctly
echo $ZDOTDIR  # Should show ~/.config/zsh
echo $XDG_CONFIG_HOME  # Should show ~/.config

# Test zsh
zsh -c 'echo "Zsh works!"'

# Test vim
vim -c 'echo "Vim works!" | q'
```

## Using Chezmoi

### Basic Commands

```bash
# See what files are managed
chezmoi managed

# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Add a new file
chezmoi add ~/.config/new-app/config

# Edit a managed file
chezmoi edit ~/.config/zsh/.zshrc

# Update from the source directory
chezmoi update
```

### Setting Up Git Repository

```bash
cd ~/.local/share/chezmoi
git init
git add .
git commit -m "Initial commit with XDG migration"
git remote add origin https://github.com/yourusername/dotfiles.git
git push -u origin main
```

### Installing on a New Machine

```bash
# Install chezmoi and apply dotfiles in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply yourusername

# Or step by step:
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Initialize from your repo
chezmoi init https://github.com/yourusername/dotfiles.git

# 3. See what would be changed
chezmoi diff

# 4. Apply the changes
chezmoi apply
```

## Troubleshooting

### Zsh not finding config

If zsh doesn't load your config:
1. Ensure `~/.zshenv` exists and contains the ZDOTDIR export
2. Check that `~/.config/zsh/.zshenv` exists
3. Try sourcing manually: `source ~/.zshenv`

### Vim not finding config

If vim doesn't load your config:
1. Ensure `~/.vimrc` exists and sets XDG paths
2. Check vim's runtimepath: `:set runtimepath?`
3. Verify directories exist: `ls -la ~/.config/vim ~/.local/share/vim`

### Permission Issues

```bash
# Fix permissions on config directories
chmod -R 755 ~/.config
chmod -R 755 ~/.local/share/chezmoi
```

## Benefits of This Setup

1. **Cleaner Home Directory**: Fewer dotfiles cluttering `~/`
2. **Better Organization**: Configs grouped by application
3. **Easier Backups**: All configs in standard locations
4. **Chezmoi Management**: Version control and templating
5. **Portability**: Easy to replicate on new machines

## Rollback

If you need to rollback:

```bash
# Restore from backup
cp -r ~/dotfiles.backup/.zsh* ~/
cp -r ~/dotfiles.backup/.vim* ~/
cp ~/dotfiles.backup/.inputrc ~/
cp ~/dotfiles.backup/.lesskey ~/

# Remove XDG directories
rm -rf ~/.config/zsh ~/.config/vim ~/.config/less ~/.config/readline

# Remove chezmoi
chezmoi purge
rm -rf ~/.local/share/chezmoi
```