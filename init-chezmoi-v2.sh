#!/usr/bin/env bash
# Initialize chezmoi with proper XDG-compliant dotfiles structure

set -e

# Ensure chezmoi is installed
if ! command -v chezmoi &> /dev/null; then
    echo "chezmoi is not installed. Please run ./install-chezmoi.sh first"
    exit 1
fi

# Set XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

echo "Initializing chezmoi repository..."

# Check if we're setting up from the workspace or need to create fresh
if [ -d "/workspace/.local/share/chezmoi" ]; then
    echo "Using prepared chezmoi source directory..."
    
    # If chezmoi is already initialized, back it up
    if [ -d "$HOME/.local/share/chezmoi" ] && [ "$HOME" != "/workspace" ]; then
        echo "Backing up existing chezmoi directory..."
        mv "$HOME/.local/share/chezmoi" "$HOME/.local/share/chezmoi.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy the prepared chezmoi source
    cp -r /workspace/.local/share/chezmoi "$HOME/.local/share/"
    
    echo "Chezmoi source directory prepared successfully!"
else
    echo "Setting up chezmoi from current dotfiles..."
    
    # Initialize chezmoi (this creates ~/.local/share/chezmoi)
    chezmoi init --apply=false
    
    # Now we need to properly structure the files in chezmoi source
    CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
    
    # Create dot files in chezmoi source
    cp "$HOME/.zshenv" "$CHEZMOI_SOURCE/dot_zshenv" 2>/dev/null || true
    cp "$HOME/.vimrc" "$CHEZMOI_SOURCE/dot_vimrc" 2>/dev/null || true
    cp "$HOME/.inputrc" "$CHEZMOI_SOURCE/dot_inputrc" 2>/dev/null || true
    
    # Create dot_config directory structure
    mkdir -p "$CHEZMOI_SOURCE/dot_config"
    
    # Copy config directories
    for dir in zsh vim less readline chezmoi; do
        if [ -d "$XDG_CONFIG_HOME/$dir" ]; then
            cp -r "$XDG_CONFIG_HOME/$dir" "$CHEZMOI_SOURCE/dot_config/"
            
            # Rename any dotfiles in the zsh directory
            if [ "$dir" = "zsh" ] && [ -d "$CHEZMOI_SOURCE/dot_config/zsh" ]; then
                cd "$CHEZMOI_SOURCE/dot_config/zsh"
                for f in .z*; do
                    [ -f "$f" ] && mv "$f" "dot_${f#.}"
                done
                cd - >/dev/null
            fi
        fi
    done
    
    # Copy .chezmoiignore if it exists
    if [ -f "/workspace/.local/share/chezmoi/.chezmoiignore" ]; then
        cp "/workspace/.local/share/chezmoi/.chezmoiignore" "$CHEZMOI_SOURCE/"
    fi
fi

# Create a README for the chezmoi repository
cat > "$HOME/.local/share/chezmoi/README.md" << 'EOF'
# Dotfiles managed by chezmoi

This repository contains my personal dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Structure

The dotfiles follow the XDG Base Directory specification with chezmoi naming conventions:

- `dot_*` files become `.*` in the home directory
- `dot_config/` becomes `~/.config/`
- Configuration files are organized by application

## Installation

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize chezmoi with this repo
chezmoi init <your-github-username>

# Preview changes
chezmoi diff

# Apply the dotfiles
chezmoi apply
```

## Directory Structure

```
~/
├── .zshenv         (from dot_zshenv)
├── .vimrc          (from dot_vimrc)
├── .inputrc        (from dot_inputrc)
└── .config/        (from dot_config/)
    ├── zsh/
    ├── vim/
    ├── less/
    ├── readline/
    └── chezmoi/
```

## Key Features

- XDG Base Directory compliant
- Zsh configuration with zinit plugin manager
- Vim configuration with vim-plug
- Less and readline configurations
- Backward compatibility symlinks for applications that don't support XDG

## Managing Dotfiles

```bash
# See what files are managed
chezmoi managed

# Add a new file
chezmoi add ~/.config/newapp/config

# Edit a managed file
chezmoi edit ~/.config/zsh/dot_zshrc

# Apply changes after editing
chezmoi apply

# Update from git repository
chezmoi update
```
EOF

echo ""
echo "Chezmoi initialization complete!"
echo ""
echo "Next steps:"
echo "1. Review the source files: ls -la ~/.local/share/chezmoi/"
echo "2. See what would be applied: chezmoi diff"
echo "3. Apply the dotfiles: chezmoi apply"
echo "4. Set up a git repository:"
echo "   cd ~/.local/share/chezmoi"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit with XDG-compliant dotfiles'"
echo "   git remote add origin <your-repo-url>"
echo "   git push -u origin main"