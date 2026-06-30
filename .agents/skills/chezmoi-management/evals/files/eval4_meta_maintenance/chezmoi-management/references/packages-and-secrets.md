# Packages and Secrets Mode (snapshot)

Minimal snapshot for the meta-maintenance eval. The real reference lives at the parent skill directory.

## Apply-time Install Env Vars

| Variable | Default | Effect |
|---|---|---|
| `DOTFILES_INSTALL_MAS_APPS` | unset | Renders MAS entries only when `true` |
| `DOTFILES_INSTALL_XCODE` | unset | Runs the Xcode install script only when `true` |
| `DOTFILES_HOMEBREW_BUNDLE_JOBS` | unset | Parallelism for `brew bundle install` |
| `DOTFILES_SKIP_PLIST_HOOKS` | unset | Disables the post-apply plist hook |

The agent's job in the eval: add a new row for `DOTFILES_INSTALL_NIX`.
