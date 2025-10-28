# dots - XDG-Compliant Dotfiles with Chezmoi

> Personal dotfiles following XDG Base Directory specification and managed with chezmoi

My dotfiles, now fully compliant with the XDG Base Directory specification and managed using [chezmoi](https://www.chezmoi.io/) for easy deployment and version control.

## Features

- ✅ **XDG Base Directory Compliant**: Clean home directory with configs in `~/.config/`
- 🚀 **Chezmoi Integration**: Easy dotfile management and deployment
- 🔧 **Zsh with Zinit**: Fast, modular shell configuration
- 📝 **Vim Configuration**: Optimized vim setup with plugin management
- 🖥️ **macOS Optimized**: Homebrew integration and macOS-specific settings
- 🔄 **Backward Compatible**: Symlinks for apps that don't support XDG

## Quick Start

### New Installation

```bash
# Install chezmoi and apply dotfiles in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-github-username>
```

### Manual Installation

```bash
# Clone this repository
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the XDG-compliant bootstrap
./bootstrap-xdg.sh

# Install and initialize chezmoi
./install-chezmoi.sh
./init-chezmoi-v2.sh  # Use v2 for proper dot_ structure
```

## Directory Structure

```
~/.config/
├── zsh/          # Zsh configuration
├── vim/          # Vim configuration  
├── less/         # Less pager config
├── readline/     # Readline config
└── chezmoi/      # Chezmoi config

~/.local/share/
├── zinit/        # Zsh plugin manager
├── vim/          # Vim plugins and data
└── chezmoi/      # Chezmoi source directory
```

## Migration Guide

If you're migrating from the old dotfile structure, see [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

## Key Components

### Zsh Configuration
- Plugin management with [zinit](https://github.com/zdharma-continuum/zinit)
- Custom prompt and completions
- Extensive aliases and functions
- XDG-compliant with `ZDOTDIR` set to `~/.config/zsh`

### Vim Configuration
- Plugin management with [vim-plug](https://github.com/junegunn/vim-plug)
- XDG paths for config, data, and cache
- Sensible defaults and key mappings

### Chezmoi Integration
- Manages all dotfiles in `~/.local/share/chezmoi`
- Easy updates with `chezmoi update`
- Template support for machine-specific configs

## Customization

1. Edit chezmoi-managed files:
   ```bash
   chezmoi edit ~/.config/zsh/.zshrc
   ```

2. Apply changes:
   ```bash
   chezmoi apply
   ```

3. Commit changes:
   ```bash
   chezmoi cd
   git add .
   git commit -m "Your changes"
   git push
   ```

## Original Structure

The original (non-XDG) dotfiles structure is preserved in the git history. Key files have been migrated as follows:

- `.zshrc` → `.config/zsh/.zshrc`
- `.vimrc` → `.config/vim/vimrc`
- `.inputrc` → `.config/readline/inputrc`
- `lesskey` → `.config/less/lesskey`

## License

MIT