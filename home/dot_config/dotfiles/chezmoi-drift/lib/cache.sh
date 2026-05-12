# shellcheck shell=zsh

drift_state_dir() {
  print -r -- "${DOTFILES_CHEZMOI_DRIFT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/chezmoi-drift}"
}

drift_load_config() {
  local root="$1"

  if [[ -r "$root/feature.env" ]]; then
    source "$root/feature.env"
  elif [[ -r "$root/feature.env.tmpl" ]]; then
    source "$root/feature.env.tmpl"
  fi

  : "${DOTFILES_CHEZMOI_DRIFT_ENABLED:=1}"
  : "${DOTFILES_CHEZMOI_DRIFT_SCOPE:=files}"
  : "${DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS:=3600}"
  : "${DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS:=21600}"
  : "${DOTFILES_CHEZMOI_DRIFT_RENDERER:=compact}"
  : "${DOTFILES_CHEZMOI_DRIFT_PALETTE:=amber}"
  : "${DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE:=off}"

  drift_normalize_config
}

drift_now() {
  zmodload zsh/datetime 2>/dev/null || true
  print -r -- "${EPOCHSECONDS:-0}"
}

drift_reset_state() {
  typeset -g DRIFT_STATE_CACHE_VERSION=0
  typeset -g DRIFT_STATE_STATUS_COUNT=0
  typeset -g DRIFT_STATE_SIGNATURE=''
  typeset -g DRIFT_STATE_UPDATED_AT=0
  typeset -g DRIFT_STATE_NEXT_REFRESH_AFTER=0
  typeset -g DRIFT_STATE_BANNER_TTL_SECONDS=0
  typeset -g DRIFT_STATE_SCOPE=''
  typeset -g DRIFT_STATE_RENDERER_EFFECTIVE=''
  typeset -g DRIFT_STATE_PALETTE_EFFECTIVE=''
  typeset -g DRIFT_STATE_CHECKED_LABEL=''
  typeset -g DRIFT_STATE_RESULT=''
}

drift_is_uint() {
  [[ "$1" == <-> ]]
}

drift_is_token() {
  [[ -n "$1" && "$1" != *[!A-Za-z0-9_.:-]* ]]
}

drift_normalize_config() {
  local enabled="${${DOTFILES_CHEZMOI_DRIFT_ENABLED:-1}:l}"

  case "$enabled" in
    1|true|yes|on)
      DOTFILES_CHEZMOI_DRIFT_ENABLED=1
      ;;
    0|false|no|off)
      DOTFILES_CHEZMOI_DRIFT_ENABLED=0
      ;;
    *)
      DOTFILES_CHEZMOI_DRIFT_ENABLED=0
      ;;
  esac

  case "${DOTFILES_CHEZMOI_DRIFT_SCOPE:-files}" in
    apply)
      DOTFILES_CHEZMOI_DRIFT_SCOPE=apply
      ;;
    *)
      DOTFILES_CHEZMOI_DRIFT_SCOPE=files
      ;;
  esac

  drift_is_uint "${DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS:-}" || DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=3600
  drift_is_uint "${DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS:-}" || DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=21600

  case "${DOTFILES_CHEZMOI_DRIFT_RENDERER:-compact}" in
    compact|ascii|box|alert|image) ;;
    *) DOTFILES_CHEZMOI_DRIFT_RENDERER=compact ;;
  esac

  case "${DOTFILES_CHEZMOI_DRIFT_PALETTE:-amber}" in
    amber|cyan) ;;
    *) DOTFILES_CHEZMOI_DRIFT_PALETTE=amber ;;
  esac

  case "${DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE:-off}" in
    off) ;;
    *) DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE=off ;;
  esac
}

drift_load_local_config() {
  local config_file="$1"
  local line key value

  [[ -r "$config_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" && "$line" != \#* ]] || continue
    [[ "$line" == export\ * ]] && line="${line#export }"
    [[ "$line" == DOTFILES_CHEZMOI_DRIFT_*=* ]] || continue

    key="${line%%=*}"
    value="${line#*=}"
    if (( ${#value} >= 2 )); then
      if [[ "$value[1]" == \" && "$value[-1]" == \" ]]; then
        value="${value[2,-2]}"
      elif [[ "$value[1]" == "'" && "$value[-1]" == "'" ]]; then
        value="${value[2,-2]}"
      fi
    fi

    case "$key" in
      DOTFILES_CHEZMOI_DRIFT_ENABLED)
        DOTFILES_CHEZMOI_DRIFT_ENABLED="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_SCOPE)
        DOTFILES_CHEZMOI_DRIFT_SCOPE="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS)
        DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS)
        DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_RENDERER)
        DOTFILES_CHEZMOI_DRIFT_RENDERER="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_PALETTE)
        DOTFILES_CHEZMOI_DRIFT_PALETTE="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE)
        DOTFILES_CHEZMOI_DRIFT_IMAGE_MODE="$value"
        ;;
    esac
  done < "$config_file"

  drift_normalize_config
}

drift_load_state() {
  local state_file="$1"
  local line key value

  drift_reset_state
  [[ -r "$state_file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      DOTFILES_CHEZMOI_DRIFT_CACHE_VERSION)
        drift_is_uint "$value" && DRIFT_STATE_CACHE_VERSION="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT)
        drift_is_uint "$value" && DRIFT_STATE_STATUS_COUNT="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_SIGNATURE)
        drift_is_token "$value" && DRIFT_STATE_SIGNATURE="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_UPDATED_AT)
        drift_is_uint "$value" && DRIFT_STATE_UPDATED_AT="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_NEXT_REFRESH_AFTER)
        drift_is_uint "$value" && DRIFT_STATE_NEXT_REFRESH_AFTER="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS)
        drift_is_uint "$value" && DRIFT_STATE_BANNER_TTL_SECONDS="$value"
        ;;
      DOTFILES_CHEZMOI_DRIFT_SCOPE)
        case "$value" in
          files|apply) DRIFT_STATE_SCOPE="$value" ;;
        esac
        ;;
      DOTFILES_CHEZMOI_DRIFT_RENDERER_EFFECTIVE)
        case "$value" in
          compact|box|alert) DRIFT_STATE_RENDERER_EFFECTIVE="$value" ;;
        esac
        ;;
      DOTFILES_CHEZMOI_DRIFT_PALETTE_EFFECTIVE)
        case "$value" in
          amber|cyan) DRIFT_STATE_PALETTE_EFFECTIVE="$value" ;;
        esac
        ;;
      DOTFILES_CHEZMOI_DRIFT_CHECKED_LABEL)
        case "$value" in
          unknown|[0-9][0-9]:[0-9][0-9]) DRIFT_STATE_CHECKED_LABEL="$value" ;;
        esac
        ;;
      DOTFILES_CHEZMOI_DRIFT_RESULT)
        case "$value" in
          ok|error) DRIFT_STATE_RESULT="$value" ;;
        esac
        ;;
    esac
  done < "$state_file"

  return 0
}

drift_state_is_fresh() {
  local now="$1"
  local ttl="$2"
  local scope="$3"
  local state_dir="${4:-}"
  local renderer="${5:-}"
  local palette="${6:-}"

  drift_is_uint "$now" || return 1
  drift_is_uint "$ttl" || return 1
  (( now > 0 )) || return 1
  (( ttl > 0 )) || return 1
  [[ "$DRIFT_STATE_CACHE_VERSION" == 1 ]] || return 1
  (( DRIFT_STATE_UPDATED_AT > 0 )) || return 1
  (( DRIFT_STATE_UPDATED_AT <= now )) || return 1
  [[ "$DRIFT_STATE_SCOPE" == "$scope" ]] || return 1
  [[ -z "$renderer" || "$DRIFT_STATE_RENDERER_EFFECTIVE" == "$renderer" ]] || return 1
  [[ -z "$palette" || "$DRIFT_STATE_PALETTE_EFFECTIVE" == "$palette" ]] || return 1
  case "$DRIFT_STATE_RESULT" in
    ok)
      if (( DRIFT_STATE_STATUS_COUNT > 0 )); then
        [[ -n "$DRIFT_STATE_SIGNATURE" && "$DRIFT_STATE_SIGNATURE" != clean && "$DRIFT_STATE_SIGNATURE" != error ]] || return 1
        if [[ -n "$state_dir" ]]; then
          [[ -s "$state_dir/banner.txt" && -s "$state_dir/banner.ansi" ]] || return 1
        fi
      else
        [[ "$DRIFT_STATE_SIGNATURE" == clean ]] || return 1
      fi
      ;;
    error)
      (( DRIFT_STATE_STATUS_COUNT == 0 )) || return 1
      [[ "$DRIFT_STATE_SIGNATURE" == error ]] || return 1
      ;;
    *)
      return 1
      ;;
  esac
  (( now < DRIFT_STATE_UPDATED_AT + ttl ))
}

drift_state_cache_is_usable() {
  local scope="$1"
  local state_dir="$2"
  local renderer="${3:-}"
  local palette="${4:-}"

  [[ "$DRIFT_STATE_SCOPE" == "$scope" ]] || return 1
  [[ -z "$renderer" || "$DRIFT_STATE_RENDERER_EFFECTIVE" == "$renderer" ]] || return 1
  [[ -z "$palette" || "$DRIFT_STATE_PALETTE_EFFECTIVE" == "$palette" ]] || return 1
  case "$DRIFT_STATE_RESULT" in
    ''|ok) ;;
    *) return 1 ;;
  esac

  if (( DRIFT_STATE_STATUS_COUNT > 0 )); then
    [[ -n "$DRIFT_STATE_SIGNATURE" && "$DRIFT_STATE_SIGNATURE" != clean && "$DRIFT_STATE_SIGNATURE" != error ]] || return 1
    [[ -s "$state_dir/banner.txt" && -s "$state_dir/banner.ansi" ]] || return 1
  else
    [[ "$DRIFT_STATE_SIGNATURE" == clean ]] || return 1
  fi
}

drift_checked_label() {
  local epoch="$1"

  if zmodload zsh/datetime 2>/dev/null && whence -w strftime >/dev/null 2>&1; then
    strftime '%H:%M' "$epoch"
    return 0
  fi

  print -r -- 'unknown'
}

drift_effective_renderer() {
  case "${DOTFILES_CHEZMOI_DRIFT_RENDERER:-compact}" in
    compact)
      print -r -- 'compact'
      ;;
    ascii|box)
      print -r -- 'box'
      ;;
    alert)
      print -r -- 'alert'
      ;;
    image)
      print -r -- 'box'
      ;;
    *)
      print -r -- 'compact'
      ;;
  esac
}

drift_effective_palette() {
  case "${DOTFILES_CHEZMOI_DRIFT_PALETTE:-amber}" in
    cyan)
      print -r -- 'cyan'
      ;;
    amber|*)
      print -r -- 'amber'
      ;;
  esac
}

drift_scope_status_args() {
  case "${DOTFILES_CHEZMOI_DRIFT_SCOPE:-files}" in
    apply)
      print -r -- 'status'
      ;;
    files|*)
      print -r -- 'status --exclude=scripts'
      ;;
  esac
}

drift_scope_diff_label() {
  case "${DOTFILES_CHEZMOI_DRIFT_SCOPE:-files}" in
    apply)
      print -r -- 'chezmoi diff'
      ;;
    files|*)
      print -r -- 'chezmoi diff --exclude=scripts'
      ;;
  esac
}

drift_status_count() {
  local status_output="$1"
  local count=0
  local line

  for line in "${(@f)status_output}"; do
    [[ -n "$line" ]] && (( count += 1 ))
  done

  print -r -- "$count"
}

drift_status_phrase() {
  local count="$1"

  if (( count == 1 )); then
    print -r -- '1 file differs'
    return 0
  fi

  print -r -- "$count files differ"
}

drift_managed_phrase() {
  local count="$1"

  if (( count == 1 )); then
    print -r -- '1 managed file differs from chezmoi source'
    return 0
  fi

  print -r -- "$count managed files differ from chezmoi source"
}

drift_box_line() {
  local text="$1"
  local width=52

  if (( ${#text} > width )); then
    text="${text[1,width-3]}..."
  fi

  print -r -- "| ${(r:${width}:: :)text} |"
}

drift_render_plain() {
  local renderer="$1"
  local count="$2"
  local checked_label="$3"
  local status_phrase managed_phrase status_args diff_label

  status_phrase="$(drift_status_phrase "$count")"
  managed_phrase="$(drift_managed_phrase "$count")"
  status_args="$(drift_scope_status_args)"
  diff_label="$(drift_scope_diff_label)"

  case "$renderer" in
    box)
      print -r -- '+-- dotfiles drift ---------------------------------------+'
      drift_box_line "$managed_phrase"
      drift_box_line "checked $checked_label"
      drift_box_line "run: chezmoi $status_args"
      drift_box_line "details: $diff_label"
      print -r -- '+---------------------------------------------------------+'
      ;;
    alert)
      print -r -- ' /\   dotfiles drift'
      print -r -- "/!!\\  $status_phrase"
      print -r -- "----  checked $checked_label"
      print -r -- "      run: chezmoi $status_args"
      ;;
    compact|*)
      print -r -- "dotfiles drift | $status_phrase | checked $checked_label"
      print -r -- "run: chezmoi $status_args    details: $diff_label"
      ;;
  esac
}

drift_render_ansi() {
  local renderer="$1"
  local count="$2"
  local checked_label="$3"
  local accent reset dim line line_number=0

  case "$(drift_effective_palette)" in
    cyan)
      accent=$'\033[38;5;45m'
      ;;
    amber|*)
      accent=$'\033[38;5;214m'
      ;;
  esac
  reset=$'\033[0m'
  dim=$'\033[2m'

  drift_render_plain "$renderer" "$count" "$checked_label" | while IFS= read -r line; do
    (( line_number += 1 ))
    if (( line_number == 1 )); then
      print -r -- "${accent}${line}${reset}"
    else
      print -r -- "${dim}${line}${reset}"
    fi
  done
}

drift_write_text_file() {
  local path="$1"
  local text="$2"
  local tmp="${path}.$$"

  if [[ -n "$text" ]]; then
    print -r -- "$text" >| "$tmp"
  else
    : >| "$tmp"
  fi
  /bin/chmod 600 "$tmp" 2>/dev/null || true
  /bin/mv -f "$tmp" "$path"
}

drift_write_state_env() {
  local state_dir="$1"
  local count="$2"
  local signature="$3"
  local updated_at="$4"
  local checked_label="$5"
  local renderer="$6"
  local result="${7:-ok}"
  local next_refresh_after=$(( updated_at + ${DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS:-3600} ))

  {
    print -r -- 'DOTFILES_CHEZMOI_DRIFT_CACHE_VERSION=1'
    print -r -- "DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=$count"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_SIGNATURE=$signature"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_UPDATED_AT=$updated_at"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_NEXT_REFRESH_AFTER=$next_refresh_after"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=${DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS:-21600}"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_SCOPE=${DOTFILES_CHEZMOI_DRIFT_SCOPE:-files}"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_RENDERER_EFFECTIVE=$renderer"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_PALETTE_EFFECTIVE=$(drift_effective_palette)"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_CHECKED_LABEL=$checked_label"
    print -r -- "DOTFILES_CHEZMOI_DRIFT_RESULT=$result"
  } >| "$state_dir/state.env.$$"
  /bin/chmod 600 "$state_dir/state.env.$$" 2>/dev/null || true
  /bin/mv -f "$state_dir/state.env.$$" "$state_dir/state.env"
}
