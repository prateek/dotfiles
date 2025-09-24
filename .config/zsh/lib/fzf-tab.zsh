#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# Only use fzf when there are more than 10 candidates
zstyle ':fzf-tab:*' fzf-min-height 10
zstyle ':fzf-tab:complete:*' fzf-bindings 'tab:accept'
zstyle ':fzf-tab:*' switch-group ',' '.'
