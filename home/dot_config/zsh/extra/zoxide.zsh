#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

if command -v zoxide >/dev/null 2>&1; then
  # Keep zoxide learning from plain `cd` usage without paying full init on startup.
  function __zoxide_hook() {
    command zoxide add -- "$PWD"
  }

  typeset -ga chpwd_functions
  chpwd_functions=("${(@)chpwd_functions:#__zoxide_hook}")
  chpwd_functions+=(__zoxide_hook)

  autoload -Uz add-zsh-hook

  _dotfiles_register_z_completion() {
    if (( ${+_comps} )); then
      _comps[z]=_z
    fi

    if (( ${+functions[compdef]} )); then
      compdef _z z
    fi

    if (( ${+_comps} || ${+functions[compdef]} )); then
      add-zsh-hook -d precmd _dotfiles_register_z_completion
    fi
  }

  add-zsh-hook precmd _dotfiles_register_z_completion
fi
