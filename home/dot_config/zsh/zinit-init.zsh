#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# https://zdharma-continuum.github.io/zinit/wiki/GALLERY/

# Load critical items first (prompt needs to be immediate)
# Load the pure theme, with zsh-async library that's bundled with it
zinit ice pick"async.zsh" src"pure.zsh" lucid
zinit light sindresorhus/pure

# fzf is loaded via custom setup in zsh/extra/fzf.zsh
# Installation handled by Brewfile during bootstrap (not zinit)
# Removed zinit pack to avoid double loading

# Defer non-critical plugins with turbo mode
# wait - defers loading (in seconds or with special value)
# lucid - skip "Loaded" message
# atinit/atload - commands to run before/after loading

# Completions must load first
zinit ice wait lucid blockf atpull'zinit creinstall -q .'
zinit light zsh-users/zsh-completions

# fzf-tab loads after completions with compinit
zinit ice wait lucid atinit"zpcompinit; zpcdreplay"
zinit light Aloxaf/fzf-tab

# Syntax highlighting loads last (no compinit needed)
zinit ice wait lucid
zinit light zdharma-continuum/fast-syntax-highlighting

# Vi motions can be deferred
zinit ice wait lucid
zinit light zsh-vi-more/vi-motions

# direnv is installed by Homebrew during bootstrap. Wire the hook directly so a
# clean first shell does not depend on zinit release-asset timing.
if (( $+commands[direnv] )); then
    _direnv_hook() {
        trap -- '' SIGINT
        eval "$("${commands[direnv]}" export zsh)"
        trap - SIGINT
    }

    typeset -ga precmd_functions chpwd_functions
    if (( ! ${precmd_functions[(I)_direnv_hook]} )); then
        precmd_functions=(_direnv_hook $precmd_functions)
    fi
    if (( ! ${chpwd_functions[(I)_direnv_hook]} )); then
        chpwd_functions=(_direnv_hook $chpwd_functions)
    fi
fi

# # ex: commands in vi mode
# zi ice wait"0" lucid
# zinit light zsh-vi-more/ex-mode
