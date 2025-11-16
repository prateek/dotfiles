#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# Locale Settings
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# NB: need to run `autoload zkbd && zkbd` to setup keycode file being sourced below
# ideally, only need to run ^ once when setting up a new computer.
# source ~/.zkbd/$TERM-${${DISPLAY:t}:-$VENDOR-$OSTYPE}

# `less` configuration
# -F: automatically exit if the entire file can be displayed on the first screen.
# -X: disable termcap (de)/init. (stops less clearing the screen).
# -R: color it up.
# -j.5: make search results appear in the center of the screen (.5 = 50%).
export LESS="-FXRj.5"
export LESSCHARSET=utf-8
export PAGER=less

# EDITOR preferences
export EDITOR="nvim" # mnemonic: c = code editor
export VISUAL="$HOME/dotfiles/scripts/c"
bindkey -v          # vim bindings for zsh

# Export existing paths.
typeset -gxU path PATH
typeset -gxU fpath FPATH
typeset -gxU manpath MANPATH

# github base path (useful for `ghc`)
export GHPATH=$HOME/code/github.com
export DOTFILES=$HOME/dotfiles

# Enable XDG for `ghcup`, via https://www.haskell.org/ghcup/guide/
export GHCUP_USE_XDG_DIRS=1

# PATH(s), relies on zsh magic (path == $PATH but in array form and sync'd)
path=(
  $HOME/bin
  $HOME/.local/bin
  /opt/homebrew/{bin,sbin}
  $GOPATH/bin
  /opt/homebrew/opt/python@3.11/libexec/bin
  $HOME/code/FlameGraph
  /opt/homebrew/share/google-cloud-sdk/bin
  $HOME/.cargo/bin
  /usr/{sbin,bin}
  /{sbin,bin}
  /usr/local/{sbin,bin}
  $path
)
path=($^path(N-/))

# Set the list of directories that man searches for manuals.
manpath=(
  /usr/local/man
  /usr/local/share/man
  /usr/share/man
)
manpath=($^manpath(N-/))

if [ -f "$HOME/.zprofile.local" ]; then
  source "$HOME/.zprofile.local"
fi
