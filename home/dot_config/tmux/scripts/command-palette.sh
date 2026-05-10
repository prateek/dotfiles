#!/usr/bin/env bash
set -euo pipefail

palette_file="${TMUX_PALETTE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux/palette.tsv}"

if ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

if ! command -v fzf >/dev/null 2>&1; then
  tmux display-message "tmux palette: fzf not found"
  exit 0
fi

if [ ! -f "$palette_file" ]; then
  tmux display-message "tmux palette: missing $palette_file"
  exit 0
fi

list_palette() {
  if command -v rg >/dev/null 2>&1; then
    rg -v '^[[:space:]]*($|#)' "$palette_file"
  else
    grep -Ev '^[[:space:]]*($|#)' "$palette_file" || true
  fi
}

selection="$(
  list_palette \
    | fzf --no-multi --prompt='tmux> ' --delimiter=$'\t' --with-nth=1
)"

if [ -z "${selection:-}" ]; then
  exit 0
fi

command="${selection#*$'\t'}"
if [ -z "${command:-}" ] || [ "$command" = "$selection" ]; then
  tmux display-message "tmux palette: invalid entry (expected: label<TAB>command)"
  exit 1
fi

bash -c "$command"
