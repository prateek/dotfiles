#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

open https://discord.com/channels/460571766901964801/676992289327022111

#-----------------------------------------------------
# Cache homebrew prefix early (before plugins need it)
#-----------------------------------------------------
if [[ -z ${HOMEBREW_PREFIX:-} ]] && command -v brew >/dev/null 2>&1; then
    export HOMEBREW_PREFIX="$(brew --prefix)"
fi

#-----------------------------------------------------
# bootstrap zinit script
#-----------------------------------------------------
source "$HOME/.zinit/bin/zinit.zsh"

#-----------------------------------------------------
# load zinit plugins
#-----------------------------------------------------
source "$DOTFILES/zinit-init.zsh"

#-----------------------------------------------------
# Setting autoloaded functions
#-----------------------------------------------------
zsh_fns=${ZSHCONFIG}/zsh/autoload
fpath=($zsh_fns $fpath)
if [[ -d "$zsh_fns" ]]; then
    for func in $zsh_fns/*; do
        autoload -Uz ${func:t}
    done
fi
unset zsh_fns

#-----------------------------------------------------
# Load all utility scripts
#-----------------------------------------------------
zsh_libs=${ZSHCONFIG}/zsh/lib
if [[ -d "$zsh_libs" ]]; then
   for file in $zsh_libs/*.zsh; do
      source $file
   done
fi
unset zsh_libs

#-----------------------------------------------------
# Load all extras from ${ZSHCONFIG}/extra/*.zsh
# NB: these are to be loaded after everything else,
# as they overwrite behaviour of stuff.
#-----------------------------------------------------
extras=${ZSHCONFIG}/zsh/extra
if [[ -d "$extras" ]]; then
   for file in $extras/*.zsh; do
      source $file
   done
fi
unset extras

# Set PATH for macOS (only for interactive login shells)
if [[ -x /bin/launchctl && -o interactive && -o login ]]; then
    /bin/launchctl setenv PATH "$PATH"
fi