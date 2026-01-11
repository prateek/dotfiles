#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# https://github.com/sorin-ionescu/prezto/blob/master/runcoms/zshenv
# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# Ensure common dotfiles vars exist even when ~/.zprofile isn't sourced
# (e.g. nested shells, non-interactive shells, or partial setups).
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"
export ZSHCONFIG="${ZSHCONFIG:-$DOTFILES}"
