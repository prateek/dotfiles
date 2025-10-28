#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# XDG Base Directory specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Set ZDOTDIR to use XDG_CONFIG_HOME
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR}/.zprofile" ]]; then
  source "${ZDOTDIR}/.zprofile"
fi