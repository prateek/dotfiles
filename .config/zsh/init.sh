#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

#-----------------------------------------------------
# Cache homebrew prefix early (before plugins need it)
#-----------------------------------------------------
if [[ -z ${HOMEBREW_PREFIX:-} ]] && command -v brew >/dev/null 2>&1; then
    export HOMEBREW_PREFIX="$(brew --prefix)"
fi

#-----------------------------------------------------
# bootstrap zinit script
#-----------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

#-----------------------------------------------------
# load zinit plugins
#-----------------------------------------------------
source "${XDG_CONFIG_HOME}/zsh/zinit-init.zsh"

#-----------------------------------------------------
# Setting autoloaded functions
#-----------------------------------------------------
zsh_fns=${XDG_CONFIG_HOME}/zsh/autoload
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
zsh_libs=${XDG_CONFIG_HOME}/zsh/lib
if [[ -d "$zsh_libs" ]]; then
   for file in $zsh_libs/*.zsh; do
      source $file
   done
fi
unset zsh_libs

#-----------------------------------------------------
# Load all extras from ${XDG_CONFIG_HOME}/zsh/extra/*.zsh
# NB: these are to be loaded after everything else,
# as they overwrite behaviour of stuff.
#-----------------------------------------------------
extras=${XDG_CONFIG_HOME}/zsh/extra
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