#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# This file redirects to the XDG-compliant location
# Set ZDOTDIR before sourcing the actual .zshenv
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"