#!/usr/bin/env bash
# Initialize chezmoi with XDG-compliant dotfiles

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

# Initialize chezmoi (this creates ~/.local/share/chezmoi)
chezmoi init

# Add configuration files to chezmoi
echo "Adding dotfiles to chezmoi..."

# Add XDG config files
chezmoi add "$XDG_CONFIG_HOME/zsh"
chezmoi add "$XDG_CONFIG_HOME/vim"
chezmoi add "$XDG_CONFIG_HOME/less"
chezmoi add "$XDG_CONFIG_HOME/readline"
chezmoi add "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"

# Add compatibility symlinks
chezmoi add ~/.zshenv
chezmoi add ~/.vimrc
chezmoi add ~/.inputrc

# Add other important files
if [ -f ~/.gitconfig ]; then
    chezmoi add ~/.gitconfig
fi

# Create a template for the README
cat > "$HOME/.local/share/chezmoi/README.md" << 'EOF'
# Dotfiles managed by chezmoi

This repository contains my personal dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Structure

The dotfiles follow the XDG Base Directory specification:

- Configuration files: `~/.config/`
- Data files: `~/.local/share/`
- Cache files: `~/.cache/`

## Installation

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize chezmoi with this repo
chezmoi init <your-github-username>

# Apply the dotfiles
chezmoi apply
```

## Key Features

- XDG Base Directory compliant
- Zsh configuration with zinit plugin manager
- Vim configuration with vim-plug
- Less and readline configurations
- Backward compatibility symlinks for applications that don't support XDG

## Files and Directories

- `.config/zsh/` - Zsh configuration
- `.config/vim/` - Vim configuration
- `.config/less/` - Less pager configuration
- `.config/readline/` - Readline configuration
- `.zshenv` - Symlink for backward compatibility
- `.vimrc` - Symlink for backward compatibility
- `.inputrc` - Symlink for backward compatibility
EOF

echo "Chezmoi initialization complete!"
echo ""
echo "Next steps:"
echo "1. Review the managed files: chezmoi managed"
echo "2. See what changes would be made: chezmoi diff"
echo "3. Apply changes: chezmoi apply"
echo "4. Set up a git repository:"
echo "   cd ~/.local/share/chezmoi"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git remote add origin <your-repo-url>"
echo "   git push -u origin main"