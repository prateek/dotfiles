#!/bin/zsh
set -euo pipefail
fpath=("$FIXTURE/autoload" "$DOTFILES_ROOT/home/dot_config/zsh/autoload")
autoload -Uz +X brew:install
claude() { return 99; }
mode="$1"
shift
case "$mode" in
  defined) source "$FIXTURE/autoload/w" ;;
  autoload) ;;
  missing) fpath=("$FIXTURE/empty-autoload") ;;
  *) print -u2 -- "unknown wrapper fixture mode: $mode"; exit 2 ;;
esac
brew:install "$@"
