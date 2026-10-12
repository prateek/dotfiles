# shellcheck shell=zsh

# Bump when state.env or module.{txt,ansi} format changes so existing caches
# get invalidated by banner_state_is_fresh and the next refresh rewrites
# them under the new shape.
typeset -gr BANNER_CACHE_VERSION=2

# When a source returns disabled (binary missing, etc.), keep the cached row
# for at most this long so a freshly installed binary gets picked up quickly.
typeset -gr BANNER_DISABLED_TTL_SECONDS=300

# Back off for this long after a source errors. Without it an error row is
# always stale, so a source that is failing for an ambient reason - offline,
# Homebrew mid-upgrade - gets re-run by every new interactive shell.
typeset -gr BANNER_ERROR_TTL_SECONDS=300

banner_state_root() {
  print -r -- "${DOTFILES_BANNER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/shell-banner}"
}

banner_source_state_dir() {
  local source="$1"
  local root
  root="$(banner_state_root)"
  print -r -- "$root/sources/$source"
}

banner_now() {
  zmodload zsh/datetime 2>/dev/null || true
  print -r -- "${EPOCHSECONDS:-0}"
}

banner_is_uint() {
  [[ "$1" == <-> ]]
}

banner_is_token() {
  [[ -n "$1" && "$1" != *[!A-Za-z0-9_.:=-]* ]]
}

banner_load_config() {
  local root="$1"

  if [[ -r "$root/feature.env" ]]; then
    source "$root/feature.env"
  fi

  : "${DOTFILES_BANNER_ENABLED:=1}"
  : "${DOTFILES_BANNER_SOURCES:=chezmoi,brew,mise}"

  : "${DOTFILES_BANNER_CHEZMOI_ENABLED:=1}"
  : "${DOTFILES_BANNER_CHEZMOI_SCOPE:=files}"
  : "${DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS:=3600}"

  : "${DOTFILES_BANNER_BREW_ENABLED:=1}"
  : "${DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS:=86400}"

  : "${DOTFILES_BANNER_MISE_ENABLED:=1}"
  : "${DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS:=43200}"

  : "${DOTFILES_BANNER_APM_ENABLED:=1}"
  : "${DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS:=43200}"

  banner_normalize_config
}

banner_normalize_bool() {
  local value="${1:-1}"
  case "${value:l}" in
    1|true|yes|on) print -r -- 1 ;;
    *) print -r -- 0 ;;
  esac
}

banner_normalize_config() {
  DOTFILES_BANNER_ENABLED="$(banner_normalize_bool "${DOTFILES_BANNER_ENABLED:-1}")"

  DOTFILES_BANNER_CHEZMOI_ENABLED="$(banner_normalize_bool "${DOTFILES_BANNER_CHEZMOI_ENABLED:-1}")"
  DOTFILES_BANNER_BREW_ENABLED="$(banner_normalize_bool "${DOTFILES_BANNER_BREW_ENABLED:-1}")"
  DOTFILES_BANNER_MISE_ENABLED="$(banner_normalize_bool "${DOTFILES_BANNER_MISE_ENABLED:-1}")"
  DOTFILES_BANNER_APM_ENABLED="$(banner_normalize_bool "${DOTFILES_BANNER_APM_ENABLED:-1}")"

  case "${DOTFILES_BANNER_CHEZMOI_SCOPE:-files}" in
    apply) DOTFILES_BANNER_CHEZMOI_SCOPE=apply ;;
    *)     DOTFILES_BANNER_CHEZMOI_SCOPE=files ;;
  esac

  banner_is_uint "${DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS:-}" || DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS=3600
  banner_is_uint "${DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS:-}"    || DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS=86400
  banner_is_uint "${DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS:-}"    || DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS=43200
  banner_is_uint "${DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS:-}"     || DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS=43200
}

banner_load_local_config() {
  local config_file="$1"
  local line key value

  [[ -r "$config_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" && "$line" != \#* ]] || continue
    [[ "$line" == export\ * ]] && line="${line#export }"
    [[ "$line" == DOTFILES_BANNER_*=* ]] || continue

    key="${line%%=*}"
    value="${line#*=}"
    if (( ${#value} >= 2 )); then
      if [[ "$value[1]" == \" && "$value[-1]" == \" ]]; then
        value="${value[2,-2]}"
      elif [[ "$value[1]" == "'" && "$value[-1]" == "'" ]]; then
        value="${value[2,-2]}"
      fi
    fi

    # Strict identifier check: anchored regex, no shell-meta chars allowed in
    # the key. Without this, a crafted line like `DOTFILES_BANNER_X $(...)=v`
    # would slip past the line filter (which only requires `KEY=VALUE` shape)
    # and reach `eval` with a command substitution embedded in the key.
    [[ "$key" =~ '^DOTFILES_BANNER_[A-Z][A-Z0-9_]*$' ]] || continue
    # Safe: key is now a validated identifier, value is parsed-as-data.
    typeset -g "$key=$value"
  done < "$config_file"

  banner_normalize_config
}

# Per-source state schema (state.env):
#   DOTFILES_BANNER_CACHE_VERSION=2
#   DOTFILES_BANNER_SOURCE=<name>
#   DOTFILES_BANNER_RESULT=ok|error|disabled
#   DOTFILES_BANNER_OUTDATED_COUNT=<int>
#   DOTFILES_BANNER_TOTAL_COUNT=<int>
#   DOTFILES_BANNER_UPDATED_AT=<epoch>
#   DOTFILES_BANNER_CHECKED_LABEL=HH:MM|unknown
#   DOTFILES_BANNER_PARAMS=<token>
#
# Plus on disk:
#   module.txt, module.ansi, status.txt, updated_at, last_error, refresh.lock/

banner_reset_state() {
  typeset -g BANNER_STATE_CACHE_VERSION=0
  typeset -g BANNER_STATE_SOURCE=''
  typeset -g BANNER_STATE_RESULT=''
  typeset -g BANNER_STATE_OUTDATED_COUNT=0
  typeset -g BANNER_STATE_TOTAL_COUNT=0
  typeset -g BANNER_STATE_UPDATED_AT=0
  typeset -g BANNER_STATE_CHECKED_LABEL=''
  typeset -g BANNER_STATE_PARAMS=''
}

banner_load_state() {
  local state_file="$1"
  local line key value

  banner_reset_state
  [[ -r "$state_file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      DOTFILES_BANNER_CACHE_VERSION)
        banner_is_uint "$value" && BANNER_STATE_CACHE_VERSION="$value"
        ;;
      DOTFILES_BANNER_SOURCE)
        banner_is_token "$value" && BANNER_STATE_SOURCE="$value"
        ;;
      DOTFILES_BANNER_RESULT)
        case "$value" in ok|error|disabled) BANNER_STATE_RESULT="$value" ;; esac
        ;;
      DOTFILES_BANNER_OUTDATED_COUNT)
        banner_is_uint "$value" && BANNER_STATE_OUTDATED_COUNT="$value"
        ;;
      DOTFILES_BANNER_TOTAL_COUNT)
        banner_is_uint "$value" && BANNER_STATE_TOTAL_COUNT="$value"
        ;;
      DOTFILES_BANNER_UPDATED_AT)
        banner_is_uint "$value" && BANNER_STATE_UPDATED_AT="$value"
        ;;
      DOTFILES_BANNER_CHECKED_LABEL)
        case "$value" in
          unknown|[0-9][0-9]:[0-9][0-9]) BANNER_STATE_CHECKED_LABEL="$value" ;;
        esac
        ;;
      DOTFILES_BANNER_PARAMS)
        banner_is_token "$value" && BANNER_STATE_PARAMS="$value"
        ;;
    esac
  done < "$state_file"

  return 0
}

banner_state_is_fresh() {
  local now="$1"
  local ttl="$2"
  local source="$3"
  local params="${4:-}"

  banner_is_uint "$now" || return 1
  banner_is_uint "$ttl" || return 1
  (( now > 0 )) || return 1
  (( ttl > 0 )) || return 1
  [[ "$BANNER_STATE_CACHE_VERSION" == "$BANNER_CACHE_VERSION" ]] || return 1
  [[ "$BANNER_STATE_SOURCE" == "$source" ]] || return 1
  (( BANNER_STATE_UPDATED_AT > 0 )) || return 1
  (( BANNER_STATE_UPDATED_AT <= now )) || return 1
  [[ -z "$params" || "$BANNER_STATE_PARAMS" == "$params" ]] || return 1
  case "$BANNER_STATE_RESULT" in
    ok) ;;
    disabled)
      # Use the short disabled-TTL so a freshly installed binary gets picked
      # up without waiting for the per-source TTL (which can be 24h for brew).
      ttl="$BANNER_DISABLED_TTL_SECONDS"
      ;;
    error)
      ttl="$BANNER_ERROR_TTL_SECONDS"
      ;;
    *) return 1 ;;
  esac
  (( now < BANNER_STATE_UPDATED_AT + ttl ))
}

# Convenience wrapper: load <state_dir>/state.env into BANNER_STATE_*, then
# check freshness. Returns 0 if fresh, 1 otherwise.
banner_source_is_fresh() {
  local state_dir="$1"
  local source="$2"
  local ttl="$3"
  local params="$4"
  local now="$5"

  banner_reset_state
  [[ -r "$state_dir/state.env" ]] || return 1
  [[ -r "$state_dir/module.txt" && -r "$state_dir/module.ansi" ]] || return 1
  banner_load_state "$state_dir/state.env" || return 1
  banner_state_is_fresh "$now" "$ttl" "$source" "$params"
}

banner_checked_label() {
  local epoch="$1"

  if zmodload zsh/datetime 2>/dev/null && whence -w strftime >/dev/null 2>&1; then
    strftime '%H:%M' "$epoch"
    return 0
  fi

  print -r -- 'unknown'
}

banner_write_text_file() {
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

banner_write_state_env() {
  local state_dir="$1"
  local source="$2"
  local result="$3"        # ok|error|disabled
  local outdated="$4"
  local total="$5"
  local updated_at="$6"
  local checked_label="$7"
  local params="${8:-}"

  {
    print -r -- "DOTFILES_BANNER_CACHE_VERSION=$BANNER_CACHE_VERSION"
    print -r -- "DOTFILES_BANNER_SOURCE=$source"
    print -r -- "DOTFILES_BANNER_RESULT=$result"
    print -r -- "DOTFILES_BANNER_OUTDATED_COUNT=$outdated"
    print -r -- "DOTFILES_BANNER_TOTAL_COUNT=$total"
    print -r -- "DOTFILES_BANNER_UPDATED_AT=$updated_at"
    print -r -- "DOTFILES_BANNER_CHECKED_LABEL=$checked_label"
    print -r -- "DOTFILES_BANNER_PARAMS=$params"
  } >| "$state_dir/state.env.$$"
  /bin/chmod 600 "$state_dir/state.env.$$" 2>/dev/null || true
  /bin/mv -f "$state_dir/state.env.$$" "$state_dir/state.env"
}

# Keep this guard file in place: unlinking it could give contenders different
# inodes to lock. The kernel releases the guard if its owner exits or crashes.
banner_with_lock_guard() {
  local guard="$1.guard" timeout="$2" fd
  shift 2
  zmodload zsh/system || return 1
  (umask 077; : >> "$guard") || return 1
  zsystem flock -t "$timeout" -f fd "$guard" 2>/dev/null || return 1
  {
    "$@"
  } always {
    zsystem flock -u "$fd"
  }
}

# Acquire a directory-style lock with PID/token/started-at and stale recovery.
# Returns:
#   0  - lock acquired (caller must call banner_release_lock with the same token)
#   1  - lock held by an active owner; caller should exit gracefully
banner_acquire_lock() {
  banner_with_lock_guard "$1" 0 banner_claim_directory_lock "$@"
}

banner_claim_directory_lock() {
  local lock_dir="$1"
  local now="$2"
  local token="$3"
  local lock_grace_seconds=5
  local lock_max_age_seconds=600

  if [[ -d "$lock_dir" ]]; then
    local lock_pid='' lock_started_at='' lock_owner_token='' lock_mtime=0
    if [[ -r "$lock_dir/owner.pid" ]]; then
      IFS= read -r lock_pid 2>/dev/null < "$lock_dir/owner.pid" || lock_pid=''
    fi
    if [[ -r "$lock_dir/started_at" ]]; then
      IFS= read -r lock_started_at 2>/dev/null < "$lock_dir/started_at" || lock_started_at=''
    fi
    if [[ -r "$lock_dir/owner.token" ]]; then
      IFS= read -r lock_owner_token 2>/dev/null < "$lock_dir/owner.token" || lock_owner_token=''
    fi
    if zmodload zsh/stat 2>/dev/null; then
      typeset -A lock_stat
      if zstat -H lock_stat +mtime "$lock_dir" 2>/dev/null; then
        lock_mtime="$lock_stat[mtime]"
      fi
      unset lock_stat
    fi

    # Path A: metadata isn't fully written yet. The lock dir is fresh; assume
    # the writer is mid-construction and back off until the grace window passes.
    if ! banner_is_uint "$lock_pid" || ! banner_is_uint "$lock_started_at" || ! banner_is_token "$lock_owner_token"; then
      if banner_is_uint "$lock_mtime" && (( now > 0 && lock_mtime > 0 && now - lock_mtime <= lock_grace_seconds )); then
        return 1
      fi
    # Path B: metadata is intact. Treat as held until the absolute age cap.
    # PID-liveness is intentionally ignored: macOS PID reuse is fast enough
    # to falsely keep stale locks alive for hours.
    elif (( now > 0 && lock_started_at > 0 && lock_started_at <= now && now - lock_started_at <= lock_max_age_seconds )); then
      return 1
    fi

    local stale_lock_dir="${lock_dir}.stale.$$"
    if /bin/mv "$lock_dir" "$stale_lock_dir" 2>/dev/null; then
      /bin/rm -rf "$stale_lock_dir"
    else
      return 1
    fi
  fi

  # `mkdir` is atomic; if it succeeds we own the lock. The metadata-write
  # window that follows is covered by the path-A grace check in the reader
  # above (a racing reader sees an empty/incomplete metadata file and backs
  # off until lock_grace_seconds passes).
  if ! /bin/mkdir "$lock_dir" 2>/dev/null; then
    return 1
  fi
  print -r -- "$$"    >| "$lock_dir/owner.pid"
  print -r -- "$now"  >| "$lock_dir/started_at"
  print -r -- "$token" >| "$lock_dir/owner.token"
  return 0
}

banner_release_lock() {
  banner_with_lock_guard "$1" 1 banner_remove_owned_lock "$@"
}

banner_remove_owned_lock() {
  local lock_dir="$1"
  local token="$2"
  local observed_token=''

  [[ -r "$lock_dir/owner.token" ]] && IFS= read -r observed_token < "$lock_dir/owner.token" || true
  if [[ "$observed_token" == "$token" ]]; then
    /bin/rm -rf "$lock_dir" 2>/dev/null || true
  fi
}

# Format a status row body. Outputs are appended after the fastfetch key column.
#
# Args: <source> <result> <outdated> <total> <verb> <checked_label>
# verb is the noun used in the row, e.g. "outdated" / "drifted".
# Sigils are Nerd Font glyphs (Font Awesome subset). Requires a Nerd Font in
# the terminal — the dotfiles install font-hack-nerd-font / font-jetbrains-mono
# via Homebrew so this is a safe assumption on Prateek's machines.
#   $''  sync (outdated)
#   $''  check (clean)
#   $''  xmark (error)
#   $''  info-circle (disabled)

banner_format_row_plain() {
  local result="$1"
  local outdated="$2"
  local total="$3"
  local verb="$4"
  local label="${5:-}"
  local reason="${6:-}"

  case "$result" in
    disabled)
      print -r -- $''" unavailable (${reason:-not installed})"
      return 0
      ;;
    error)
      print -r -- $''" unavailable (last check failed)"
      return 0
      ;;
  esac

  local sigil
  if (( outdated > 0 )); then
    sigil=$''
  else
    sigil=$''
  fi

  local body="${sigil} ${outdated} / ${total} ${verb}"
  if [[ -n "$label" && "$label" != unknown ]]; then
    body+="  · checked ${label}"
  fi
  print -r -- "$body"
}

banner_format_row_ansi() {
  local result="$1"
  local outdated="$2"
  local total="$3"
  local verb="$4"
  local label="${5:-}"
  local reason="${6:-}"

  local reset=$'\033[0m'
  local dim=$'\033[2m'
  # 24-bit RGB; libghostty renders true color natively.
  local good=$'\033[38;2;106;176;76m'
  local warn=$'\033[38;2;232;175;52m'
  local err=$'\033[38;2;220;100;90m'

  case "$result" in
    disabled)
      print -r -- "${dim}"$''" unavailable (${reason:-not installed})${reset}"
      return 0
      ;;
    error)
      print -r -- "${err}"$''" unavailable (last check failed)${reset}"
      return 0
      ;;
  esac

  local color sigil
  if (( outdated > 0 )); then
    color="$warn"
    sigil=$''
  else
    color="$good"
    sigil=$''
  fi

  local body="${color}${sigil} ${outdated} / ${total} ${verb}${reset}"
  if [[ -n "$label" && "$label" != unknown ]]; then
    body+="${dim}  · checked ${label}${reset}"
  fi
  print -r -- "$body"
}
