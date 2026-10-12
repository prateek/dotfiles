# shellcheck shell=zsh

shell_banner_adapter="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/shell-banner/shell/zsh.zsh"
if [[ -r "$shell_banner_adapter" ]]; then
  source "$shell_banner_adapter"
fi
unset shell_banner_adapter
