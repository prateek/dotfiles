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
