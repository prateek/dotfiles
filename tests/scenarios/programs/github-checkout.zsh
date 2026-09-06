#!/bin/zsh
set -euo pipefail
fpath=("$DOTFILES_ROOT/home/dot_config/zsh/autoload")
autoload -Uz ghc ohc
helper="$1"
shift
case "$helper" in
  ghc|ohc) "$helper" "$@" ;;
  *) print -u2 -- "unknown checkout helper: $helper"; exit 2 ;;
esac
print -r -- "${PWD:A}" > "$FIXTURE/pwd"
