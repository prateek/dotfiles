# shellcheck shell=zsh

__dotfiles_chezmoi_drift() {
  emulate -L zsh
  setopt no_nomatch typeset_silent

  [[ -o interactive ]] || return 0
  [[ -t 1 ]] || return 0
  [[ -n "${TERM:-}" && "${TERM:-}" != dumb ]] || return 0
  [[ -z "${SSH_TTY:-}${SSH_CONNECTION:-}" ]] || return 0

  local root="${DOTFILES_CHEZMOI_DRIFT_ROOT:-${${(%):-%x}:A:h:h}}"
  [[ -r "$root/lib/cache.sh" ]] || return 0
  source "$root/lib/cache.sh"

  drift_load_config "$root"
  if [[ -r "$root/local.env" ]]; then
    drift_load_local_config "$root/local.env"
  fi

  case "${DOTFILES_CHEZMOI_DRIFT_ENABLED:-1}" in
    1) ;;
    *) return 0 ;;
  esac

  zmodload zsh/datetime 2>/dev/null || true

  local state_dir="${DOTFILES_CHEZMOI_DRIFT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/chezmoi-drift}"
  local state_file="$state_dir/state.env"
  local now="${EPOCHSECONDS:-0}"

  if [[ -r "$state_file" ]]; then
    drift_load_state "$state_file" || true
  else
    drift_reset_state
  fi

  local configured_renderer configured_palette
  configured_renderer="$(drift_effective_renderer)"
  configured_palette="$(drift_effective_palette)"

  if ! drift_state_is_fresh "$now" "${DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS:-3600}" "${DOTFILES_CHEZMOI_DRIFT_SCOPE:-files}" "$state_dir" "$configured_renderer" "$configured_palette"; then
    local refresh_bin=''
    if [[ -x "$root/bin/refresh" ]]; then
      refresh_bin="$root/bin/refresh"
    elif [[ -x "$root/bin/executable_refresh" ]]; then
      refresh_bin="$root/bin/executable_refresh"
    fi
    if [[ -n "$refresh_bin" ]]; then
      "$refresh_bin" --if-stale </dev/null >/dev/null 2>&1 &!
    fi
  fi

  local count="${DRIFT_STATE_STATUS_COUNT:-0}"
  (( count > 0 )) || return 0

  local signature="${DRIFT_STATE_SIGNATURE:-}"
  [[ -n "$signature" ]] || return 0

  local display_lock_fd=''
  local display_lock_active=0
  if zmodload zsh/system 2>/dev/null; then
    : >> "$state_dir/display.lock" 2>/dev/null || true
    if [[ -e "$state_dir/display.lock" ]] && zsystem flock -f display_lock_fd -t 0 "$state_dir/display.lock" 2>/dev/null; then
      display_lock_active=1
    elif [[ -e "$state_dir/display.lock" ]]; then
      return 0
    fi
  fi

  local last_signature=''
  local last_shown=0
  if [[ -r "$state_dir/last_shown_signature" ]]; then
    IFS= read -r last_signature < "$state_dir/last_shown_signature" || true
  fi
  if [[ -r "$state_dir/last_shown" ]]; then
    IFS= read -r last_shown < "$state_dir/last_shown" || true
  fi
  drift_is_uint "$last_shown" || last_shown=0

  local banner_ttl="${DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS:-21600}"
  drift_is_uint "$banner_ttl" || banner_ttl=21600
  local should_show=0
  if [[ "$signature" != "$last_signature" ]]; then
    should_show=1
  elif (( now == 0 || last_shown <= 0 || now - last_shown >= banner_ttl )); then
    should_show=1
  fi
  if (( ! should_show )); then
    (( display_lock_active )) && zsystem flock -u "$display_lock_fd" 2>/dev/null || true
    return 0
  fi

  local banner_file="$state_dir/banner.txt"
  if [[ -z "${NO_COLOR:-}" && -r "$state_dir/banner.ansi" ]]; then
    banner_file="$state_dir/banner.ansi"
  fi
  if [[ ! -r "$banner_file" ]]; then
    (( display_lock_active )) && zsystem flock -u "$display_lock_fd" 2>/dev/null || true
    return 0
  fi

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    print -r -- "$line"
  done < "$banner_file"

  print -r -- "$now" >| "$state_dir/last_shown" 2>/dev/null || true
  print -r -- "$signature" >| "$state_dir/last_shown_signature" 2>/dev/null || true
  (( display_lock_active )) && zsystem flock -u "$display_lock_fd" 2>/dev/null || true
}

typeset -A __dotfiles_chezmoi_drift_saved_functions
typeset __dotfiles_chezmoi_drift_function_name
for __dotfiles_chezmoi_drift_function_name in ${(k)functions[(I)drift_*]}; do
  __dotfiles_chezmoi_drift_saved_functions[$__dotfiles_chezmoi_drift_function_name]="${functions[$__dotfiles_chezmoi_drift_function_name]}"
done

__dotfiles_chezmoi_drift

for __dotfiles_chezmoi_drift_function_name in ${(k)functions[(I)drift_*]}; do
  if (( ${+__dotfiles_chezmoi_drift_saved_functions[$__dotfiles_chezmoi_drift_function_name]} )); then
    functions[$__dotfiles_chezmoi_drift_function_name]="${__dotfiles_chezmoi_drift_saved_functions[$__dotfiles_chezmoi_drift_function_name]}"
  else
    unfunction "$__dotfiles_chezmoi_drift_function_name" 2>/dev/null || true
  fi
done
unfunction __dotfiles_chezmoi_drift 2>/dev/null || true
unset __dotfiles_chezmoi_drift_saved_functions __dotfiles_chezmoi_drift_function_name
