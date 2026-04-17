#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# Keep GRM config reasonably fresh after common git/gh actions.
# This is intentionally lightweight (best-effort, background).

zmodload -F zsh/stat b:zstat 2>/dev/null || true
zmodload zsh/datetime 2>/dev/null || true

grmrepo_refresh_bg() {
  if command -v grmrepo-refresh >/dev/null 2>&1; then
    grmrepo-refresh >/dev/null 2>&1 &!
  fi
}

_grmrepo_mtime_s() {
  local file="$1"
  REPLY=0

  if (( ${+builtins[zstat]} )); then
    local -a stat_out
    zstat -A stat_out +mtime -- "$file" 2>/dev/null || return 0
    REPLY="${stat_out[1]:-0}"
    return 0
  fi

  REPLY="$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)"
}

grmrepo_refresh_maybe_bg() {
  local max_age_s="${GRMREPO_REFRESH_MAX_AGE_S:-86400}"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/grmrepo"
  local stamp="$cache_dir/last-refresh"

  local now mtime
  now="${EPOCHSECONDS:-0}"
  _grmrepo_mtime_s "$stamp"
  mtime="$REPLY"

  if (( now != 0 && mtime != 0 && (now - mtime) < max_age_s )); then
    return 0
  fi

  mkdir -p "$cache_dir" >/dev/null 2>&1 || true
  : >| "$stamp" 2>/dev/null || true
  grmrepo_refresh_bg
}

# Only hook in interactive shells.
if [[ -o interactive ]]; then
  grmrepo_refresh_maybe_bg

  autoload -Uz add-zsh-hook

  _grmrepo_should_refresh_for_cmd() {
    local cmd="${1:-}"
    case "$cmd" in
      (git\ clone*|git\ worktree\ add*|git\ worktree\ remove*|git\ worktree\ prune*|gh\ repo\ clone*|gh\ repo\ create*|ghc\ *)
        return 0
        ;;
    esac
    return 1
  }

  typeset -g _grmrepo_last_cmd=""

  _grmrepo_preexec() {
    _grmrepo_last_cmd="${1:-}"
  }

  _grmrepo_precmd() {
    local rc=$?
    if (( rc == 0 )) && _grmrepo_should_refresh_for_cmd "$_grmrepo_last_cmd"; then
      grmrepo_refresh_bg
    fi
    _grmrepo_last_cmd=""
  }

  add-zsh-hook preexec _grmrepo_preexec
  add-zsh-hook precmd _grmrepo_precmd
fi
