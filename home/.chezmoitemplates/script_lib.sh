#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

die() {
  printf '[dotfiles] error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_timed() {
  local label start end rc shell_flags

  label="$1"
  shift

  start="$(date +%s)"
  shell_flags="$-"
  set +e
  "$@"
  rc="$?"
  case "$shell_flags" in
    *e*) set -e ;;
    *) set +e ;;
  esac
  end="$(date +%s)"

  log "TIMING|${label}|seconds=$(( end - start ))|rc=${rc}"
  return "$rc"
}

brew_shellenv() {
  if have brew; then
    return 0
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

dotfiles_sudo_state_dir() {
  local base
  base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
  printf '%s/dotfiles-sudo-%s' "$base" "$(id -u)"
}

dotfiles_sudo_pid_file() {
  printf '%s/keepalive.pid' "$(dotfiles_sudo_state_dir)"
}

dotfiles_sudo_preexisting_file() {
  printf '%s/preexisting' "$(dotfiles_sudo_state_dir)"
}

dotfiles_sudo_parent_pid_file() {
  printf '%s/parent.pid' "$(dotfiles_sudo_state_dir)"
}

dotfiles_sudo_parent_pid() {
  local command_name current next parent

  parent="$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ')"
  case "$parent" in
    ''|*[!0-9]*) printf '%s\n' "$$"; return 0 ;;
  esac

  current="$parent"
  while :; do
    command_name="$(ps -o comm= -p "$current" 2>/dev/null | tr -d ' ' || true)"
    command_name="${command_name##*/}"
    if [ "$command_name" = "chezmoi" ]; then
      printf '%s\n' "$current"
      return 0
    fi

    next="$(ps -o ppid= -p "$current" 2>/dev/null | tr -d ' ')"
    case "$next" in
      ''|*[!0-9]*|0|1) break ;;
    esac
    [ "$next" = "$current" ] && break
    current="$next"
  done

  printf '%s\n' "$parent"
}

dotfiles_sudo_keepalive_active() {
  local parent_pid parent_pid_file pid pid_file
  pid_file="$(dotfiles_sudo_pid_file)"
  [ -r "$pid_file" ] || return 1
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null || return 1

  parent_pid_file="$(dotfiles_sudo_parent_pid_file)"
  [ -r "$parent_pid_file" ] || return 1
  parent_pid="$(cat "$parent_pid_file" 2>/dev/null || true)"
  case "$parent_pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$parent_pid" 2>/dev/null
}

dotfiles_sudo_start() {
  local parent_pid parent_pid_file pid_file preexisting preexisting_file reason state_dir

  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  have sudo || die "Administrator access is required, but sudo is unavailable."

  if dotfiles_sudo_keepalive_active; then
    return 0
  fi
  dotfiles_sudo_stop

  reason="${1:-Dotfiles setup needs administrator access.}"
  state_dir="$(dotfiles_sudo_state_dir)"
  pid_file="$(dotfiles_sudo_pid_file)"
  preexisting_file="$(dotfiles_sudo_preexisting_file)"
  parent_pid_file="$(dotfiles_sudo_parent_pid_file)"
  mkdir -p "$state_dir"

  preexisting=0
  if sudo -n -v 2>/dev/null; then
    preexisting=1
  else
    log "$reason"
    if ! sudo -v; then
      die "Administrator access is required for this dotfiles step. Make sure this macOS user is an Administrator, or install Homebrew manually and rerun chezmoi apply."
    fi
  fi

  printf '%s\n' "$preexisting" >"$preexisting_file"
  parent_pid="$(dotfiles_sudo_parent_pid)"
  printf '%s\n' "$parent_pid" >"$parent_pid_file"

  # shellcheck disable=SC2016
  nohup "${BASH:-bash}" -c '
    set -u
    pid_file="$1"
    preexisting_file="$2"
    parent_pid_file="$3"
    parent_pid="$4"

    cleanup() {
      if [ "$(cat "$preexisting_file" 2>/dev/null || true)" = "0" ]; then
        command -v sudo >/dev/null 2>&1 && sudo -k
      fi
      rm -f "$pid_file" "$preexisting_file" "$parent_pid_file"
    }

    next_refresh=0
    while kill -0 "$parent_pid" 2>/dev/null; do
      now="$(date +%s)"
      if [ "$now" -ge "$next_refresh" ]; then
        if ! sudo -n -v >/dev/null 2>&1; then
          cleanup
          exit 0
        fi
        next_refresh=$((now + 60))
      fi
      sleep 1
    done
    cleanup
  ' dotfiles-sudo-keepalive "$pid_file" "$preexisting_file" "$parent_pid_file" "$parent_pid" >/dev/null 2>&1 &

  printf '%s\n' "$!" >"$pid_file"
}

dotfiles_sudo_stop() {
  local parent_pid_file pid pid_file preexisting preexisting_file
  pid_file="$(dotfiles_sudo_pid_file)"
  preexisting_file="$(dotfiles_sudo_preexisting_file)"
  parent_pid_file="$(dotfiles_sudo_parent_pid_file)"

  if [ ! -r "$pid_file" ]; then
    rm -f "$preexisting_file" "$parent_pid_file"
    return 0
  fi
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  case "$pid" in
    ''|*[!0-9]*) rm -f "$pid_file" "$preexisting_file" "$parent_pid_file"; return 0 ;;
  esac

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi

  preexisting="$(cat "$preexisting_file" 2>/dev/null || true)"
  rm -f "$pid_file" "$preexisting_file" "$parent_pid_file"
  if [ "$preexisting" = "0" ]; then
    have sudo && sudo -k
  fi
}
