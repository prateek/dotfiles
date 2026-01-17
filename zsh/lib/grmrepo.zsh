#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# Keep GRM config reasonably fresh after common git/gh actions.
# This is intentionally lightweight (best-effort, background).

grmrepo_refresh_bg() {
  if command -v grmrepo-refresh >/dev/null 2>&1; then
    grmrepo-refresh >/dev/null 2>&1 &!
  fi
}

_grmrepo_mtime_s() {
  local file="$1"
  stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0
}

grmrepo_refresh_maybe_bg() {
  local max_age_s="${GRMREPO_REFRESH_MAX_AGE_S:-86400}"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/grmrepo"
  local stamp="$cache_dir/last-refresh"

  local now mtime
  now="$(date +%s 2>/dev/null || echo 0)"
  mtime="$(_grmrepo_mtime_s "$stamp")"

  if [[ "$now" != 0 && "$mtime" != 0 ]]; then
    if (( (now - mtime) < max_age_s )); then
      return 0
    fi
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
