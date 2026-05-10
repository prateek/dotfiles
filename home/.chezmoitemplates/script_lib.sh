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

dotfiles_sudo_keepalive_active() {
  local pid pid_file
  pid_file="$(dotfiles_sudo_pid_file)"
  [ -r "$pid_file" ] || return 1
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

dotfiles_sudo_start() {
  local parent_pid pid_file preexisting preexisting_file reason state_dir

  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  have sudo || die "Administrator access is required, but sudo is unavailable."

  if dotfiles_sudo_keepalive_active; then
    return 0
  fi

  reason="${1:-Dotfiles setup needs administrator access.}"
  state_dir="$(dotfiles_sudo_state_dir)"
  pid_file="$(dotfiles_sudo_pid_file)"
  preexisting_file="$(dotfiles_sudo_preexisting_file)"
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
  parent_pid="$(ps -o ppid= -p "$$" | tr -d ' ')"

  (
    while kill -0 "$parent_pid" 2>/dev/null; do
      sudo -n -v >/dev/null 2>&1 || exit
      sleep 60
    done
    if [ "$(cat "$preexisting_file" 2>/dev/null || true)" = "0" ]; then
      have sudo && sudo -k
    fi
    rm -f "$pid_file" "$preexisting_file"
  ) &

  printf '%s\n' "$!" >"$pid_file"
}

dotfiles_sudo_stop() {
  local pid pid_file preexisting preexisting_file
  pid_file="$(dotfiles_sudo_pid_file)"
  preexisting_file="$(dotfiles_sudo_preexisting_file)"

  [ -r "$pid_file" ] || return 0
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  case "$pid" in
    ''|*[!0-9]*) rm -f "$pid_file" "$preexisting_file"; return 0 ;;
  esac

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi

  preexisting="$(cat "$preexisting_file" 2>/dev/null || true)"
  rm -f "$pid_file" "$preexisting_file"
  if [ "$preexisting" = "0" ]; then
    have sudo && sudo -k
  fi
}
