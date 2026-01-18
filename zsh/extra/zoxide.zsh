#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

() {
  if ! command -v zoxide >/dev/null 2>&1; then
    return 0
  fi

  # One-time migration: seed zoxide with your existing autojump history.
  # Note: zoxide only imports paths (not scores), since the algorithms differ.
  local autojump_db="$HOME/Library/autojump/autojump.txt"
  local import_marker_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
  local import_marker_file="$import_marker_dir/zoxide.imported_autojump"
  if [[ -f "$autojump_db" && ! -f "$import_marker_file" ]]; then
    mkdir -p "$import_marker_dir"
    if zoxide import --from autojump --merge "$autojump_db" >/dev/null 2>&1; then
      : >| "$import_marker_file"
    fi
  fi

  # Defines `j` + `ji`, and installs completion + shell hooks.
  local init
  init="$(zoxide init zsh --cmd j)" || return 0
  eval "$init" || return 0
}
