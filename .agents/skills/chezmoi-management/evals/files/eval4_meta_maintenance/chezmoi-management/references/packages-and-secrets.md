# Packages and Secrets Mode (snapshot)

Minimal snapshot for the meta-maintenance eval. The real reference lives at the parent skill directory.

## Profile And Install Env Vars

| Variable | Default | Effect |
|---|---|---|
| `DOTFILES_INSTALL_PROFILE` | `core` | Selects which profile from `packages.toml` activates |
| `DOTFILES_INSTALL_MAS_APPS` | unset | Renders MAS entries only when `true` |
| `DOTFILES_SECRETS_ENABLED` | unset | Renders secret-backed templates only when `true` |
| `DOTFILES_INSTALL_XCODE` | unset | Runs the Xcode install script only when `true` |

The agent's job in the eval: add a new row for `DOTFILES_INSTALL_NIX`.
