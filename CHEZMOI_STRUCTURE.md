# Chezmoi Directory Structure

This document explains how the dotfiles are structured for use with chezmoi.

## Chezmoi Naming Conventions

Chezmoi uses special naming conventions to handle dotfiles:

- `dot_filename` → `.filename` (e.g., `dot_zshenv` → `.zshenv`)
- `dot_config/` → `.config/` (directories with dots)
- `private_filename` → `filename` (for files with secrets, encrypted)
- `executable_filename` → `filename` (with executable permissions)

## Current Structure

```
~/.local/share/chezmoi/
├── dot_zshenv              → ~/.zshenv
├── dot_vimrc               → ~/.vimrc
├── dot_inputrc             → ~/.inputrc
├── dot_config/             → ~/.config/
│   ├── zsh/
│   │   ├── dot_zshenv      → ~/.config/zsh/.zshenv
│   │   ├── dot_zshrc       → ~/.config/zsh/.zshrc
│   │   ├── dot_zprofile    → ~/.config/zsh/.zprofile
│   │   ├── dot_zlogin      → ~/.config/zsh/.zlogin
│   │   ├── init.sh
│   │   ├── zinit-init.zsh
│   │   ├── autoload/
│   │   ├── lib/
│   │   └── extra/
│   ├── vim/
│   │   ├── vimrc
│   │   └── vimrc.orig
│   ├── less/
│   │   └── lesskey
│   ├── readline/
│   │   └── inputrc
│   └── chezmoi/
│       └── chezmoi.toml
├── .chezmoiignore
├── .gitignore
└── README.md
```

## How Files Are Deployed

When you run `chezmoi apply`, the following happens:

1. **Root dotfiles**: Files like `dot_zshenv` are created as `.zshenv` in your home directory
2. **Config directory**: The `dot_config/` directory is created as `~/.config/`
3. **Nested dotfiles**: Files like `dot_config/zsh/dot_zshrc` become `~/.config/zsh/.zshrc`

## Managing Files

### Adding new files

```bash
# Add a single file
chezmoi add ~/.gitconfig
# Creates: ~/.local/share/chezmoi/dot_gitconfig

# Add a config file
chezmoi add ~/.config/git/config
# Creates: ~/.local/share/chezmoi/dot_config/git/config
```

### Editing files

```bash
# Edit a managed file
chezmoi edit ~/.zshenv
# Or edit directly in the source
chezmoi cd
vim dot_zshenv
```

### Applying changes

```bash
# See what would change
chezmoi diff

# Apply all changes
chezmoi apply

# Apply a specific file
chezmoi apply ~/.zshenv
```

## Templates

Chezmoi supports templates for machine-specific configuration:

```bash
# Create a template file
mv dot_gitconfig dot_gitconfig.tmpl

# Use template variables
# In dot_gitconfig.tmpl:
[user]
    name = {{ .name }}
    email = {{ .email }}
```

## Encryption

For sensitive files:

```bash
# Add an encrypted file
chezmoi add --encrypt ~/.ssh/config
# Creates: private_dot_ssh/private_config
```

## Best Practices

1. **Use .chezmoiignore**: Exclude files that shouldn't be managed
2. **Keep secrets encrypted**: Use `private_` prefix for sensitive files
3. **Use templates**: For machine-specific configurations
4. **Regular commits**: Treat the chezmoi source as a git repository
5. **Test before applying**: Always run `chezmoi diff` first

## Troubleshooting

### File not updating
```bash
# Force re-apply
chezmoi apply --force ~/.config/zsh/.zshrc
```

### Wrong permissions
```bash
# Make a script executable
cd $(chezmoi source-path)
mv script executable_script
```

### See managed files
```bash
# List all managed files
chezmoi managed

# List files that would be changed
chezmoi status
```