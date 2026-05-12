# shellcheck shell=zsh

chezmoi_drift_adapter="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/chezmoi-drift/shell/zsh.zsh"
if [[ -r "$chezmoi_drift_adapter" ]]; then
  source "$chezmoi_drift_adapter"
fi
unset chezmoi_drift_adapter
