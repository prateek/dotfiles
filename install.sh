#!/usr/bin/env bash
set -euo pipefail

is_file() { [ -e "$1" ] && [ -f "$1" ]; }

script_dir() {
  local src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && is_file "$src"; then
    cd -- "$(dirname -- "$src")" && pwd
    return 0
  fi
  pwd
}

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf '[install] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [--core|--full] [--dry-run] [--source URL_OR_PATH]

Environment:
  REPO_URL                 Repo URL/path for curl-piped installs.
  INSTALL_DIR              Checkout path (default: ~/dotfiles).
  DOTFILES_SUDO_PASSWORD   Password for non-interactive sudo in Tart.

Compatibility aliases:
  --repo-url URL_OR_PATH   Same as --source.
  --install-dir PATH       Same as INSTALL_DIR.
USAGE
}

request_sudo_keepalive() {
  if [ "${DOTFILES_SUDO_KEEPALIVE_STARTED:-0}" = "1" ]; then
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would request sudo keepalive."
    return 0
  fi

  if [ -t 0 ]; then
    sudo -v
  elif sudo -n true >/dev/null 2>&1; then
    :
  elif [ -n "${DOTFILES_SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$DOTFILES_SUDO_PASSWORD" | sudo -S -v
  else
    die "sudo requires a password but no TTY is available."
  fi

  local sudo_pid="$$"
  while true; do sudo -n true; sleep 60; kill -0 "$sudo_pid" || exit; done 2>/dev/null &
  export DOTFILES_SUDO_KEEPALIVE_STARTED=1
}

ensure_xcode_clt() {
  local timeout="${DOTFILES_XCODE_CLT_TIMEOUT_SEC:-1800}"
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: Xcode Command Line Tools are missing; would run xcode-select --install."
    return 0
  fi

  log "Installing Xcode Command Line Tools."
  xcode-select --install 2>/dev/null || true

  log "Waiting for Command Line Tools install to finish."
  local start
  start="$(date +%s)"
  until xcode-select -p >/dev/null 2>&1; do
    if [ "$(( $(date +%s) - start ))" -ge "$timeout" ]; then
      die "timed out waiting for Xcode Command Line Tools; finish the GUI install and rerun install.sh."
    fi
    sleep 10
  done
}

brew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_homebrew() {
  brew_shellenv
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would install Homebrew."
    return 0
  fi

  log "Installing Homebrew."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_shellenv
  command -v brew >/dev/null 2>&1 || die "Homebrew install finished but brew is not on PATH."
}

ensure_core_tools() {
  local missing=()
  for tool in git chezmoi uv; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would install core tools: ${missing[*]}"
    return 0
  fi

  brew_shellenv
  command -v brew >/dev/null 2>&1 || die "Homebrew is required to install: ${missing[*]}"
  brew install "${missing[@]}"
}

checkout_repo() {
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would clone or update $REPO_URL at $DOTFILES_DIR."
    return 0
  fi

  if [ -e "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR/.git" ] && [ ! -f "$DOTFILES_DIR/.git" ]; then
    die "$DOTFILES_DIR exists but is not a git checkout."
  fi

  if [ -d "$DOTFILES_DIR/.git" ] || [ -f "$DOTFILES_DIR/.git" ]; then
    log "Updating existing checkout at $DOTFILES_DIR."
    git -C "$DOTFILES_DIR" pull --ff-only || true
  else
    log "Cloning $REPO_URL to $DOTFILES_DIR."
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
}

run_chezmoi() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  local xdg_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local config_file="$xdg_config_home/chezmoi/chezmoi.toml"
  local cache_dir="$xdg_cache_home/chezmoi"
  local state_file="$xdg_state_home/chezmoi/state.boltdb"

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would run chezmoi init --apply from $DOTFILES_DIR to $HOME."
    return 0
  fi

  mkdir -p "$(dirname "$config_file")" "$cache_dir" "$(dirname "$state_file")"

  export DOTFILES_DIR
  export DOTFILES_INSTALL_PROFILE="$PROFILE"
  export DOTFILES_SECRETS_ENABLED="${DOTFILES_SECRETS_ENABLED:-false}"
  export DOTFILES_RUN_INSTALL_SCRIPTS="${DOTFILES_RUN_INSTALL_SCRIPTS:-true}"
  if [ "${SKIP_MACOS_DEFAULTS:-0}" = "1" ]; then
    export DOTFILES_APPLY_DEFAULTS=false
  else
    export DOTFILES_APPLY_DEFAULTS="${DOTFILES_APPLY_DEFAULTS:-true}"
  fi

  log "Applying chezmoi source state."
  chezmoi \
    --config "$config_file" \
    --source "$DOTFILES_DIR" \
    --destination "$HOME" \
    --cache "$cache_dir" \
    --persistent-state "$state_file" \
    --no-tty \
    init --apply
}

if [ "$(uname -s)" != "Darwin" ]; then
  die "install.sh is macOS-only."
fi

PROFILE="full"
DRY_RUN=0
MODE="auto"
REPO_URL="${REPO_URL:-https://github.com/prateek/dotfiles.git}"
DOTFILES_DIR="${INSTALL_DIR:-$HOME/dotfiles}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --core)
      PROFILE="core"
      shift
      ;;
    --full)
      PROFILE="full"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --source|--repo-url)
      [ -n "${2:-}" ] || die "missing value for $1"
      REPO_URL="$2"
      shift 2
      ;;
    --source=*|--repo-url=*)
      REPO_URL="${1#*=}"
      shift
      ;;
    --install-dir)
      [ -n "${2:-}" ] || die "missing value for $1"
      DOTFILES_DIR="$2"
      shift 2
      ;;
    --install-dir=*)
      DOTFILES_DIR="${1#*=}"
      shift
      ;;
    --remote)
      MODE="remote"
      shift
      ;;
    --local)
      MODE="local"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown arg: $1"
      ;;
  esac
done

SCRIPT_DIR="$(script_dir)"
if [ "$MODE" = "auto" ]; then
  if [ -f "$SCRIPT_DIR/home/.chezmoi.toml.tmpl" ]; then
    MODE="local"
  else
    MODE="remote"
  fi
fi

ensure_xcode_clt
ensure_homebrew
ensure_core_tools

case "$MODE" in
  local)
    DOTFILES_DIR="$SCRIPT_DIR"
    ;;
  remote)
    checkout_repo
    ;;
  *)
    die "unknown mode: $MODE"
    ;;
esac

request_sudo_keepalive
run_chezmoi
