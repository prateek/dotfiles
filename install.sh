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

request_sudo_keepalive() {
  if [ "${DOTFILES_SUDO_KEEPALIVE_STARTED:-0}" = "1" ]; then
    return 0
  fi

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "DRY RUN: would request sudo + keep it alive for the install."
    return 0
  fi

  echo "Requesting sudo (used for macOS settings + app installs)…"
  if [ -t 0 ]; then
    sudo -v
  elif sudo -n true >/dev/null 2>&1; then
    # No password required (e.g. NOPASSWD sudoers). Avoid `sudo -v` which can
    # fail under non-interactive exec environments.
    :
  elif [ -n "${DOTFILES_SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$DOTFILES_SUDO_PASSWORD" | sudo -S -v
  else
    echo "Error: sudo requires a password but no TTY is available."
    echo "Run this script from a real terminal, or set DOTFILES_SUDO_PASSWORD for non-interactive runs."
    exit 1
  fi

  SUDO_PID="$$"
  while true; do sudo -n true; sleep 60; kill -0 "$SUDO_PID" || exit; done 2>/dev/null &
  export DOTFILES_SUDO_KEEPALIVE_STARTED=1
}

ensure_xcode_clt() {
  local timeout="${DOTFILES_XCODE_CLT_TIMEOUT_SEC:-1800}"
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "DRY RUN: Xcode Command Line Tools not installed; would trigger the GUI prompt via 'xcode-select --install' and wait (timeout: ${timeout}s)."
    return 2
  fi

  echo "Installing Xcode Command Line Tools…"
  # This triggers a GUI prompt; user must click Install once.
  xcode-select --install 2>/dev/null || true

  echo "Waiting for Command Line Tools install to complete (timeout: ${timeout}s)…"
  local start
  start="$(date +%s)"
  until xcode-select -p >/dev/null 2>&1; do
    if [ "$(( $(date +%s) - start ))" -ge "$timeout" ]; then
      echo "Error: timed out waiting for Xcode Command Line Tools."
      echo "Finish the install (System Settings → General → Software Update) and rerun this script."
      exit 1
    fi
    sleep 10
  done
}

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [--core|--full] [--dry-run] [--brewfile PATH]

Remote mode (also works via curl | bash):
  REPO_URL=... INSTALL_DIR=... ./install.sh --remote [--core|--full] [--dry-run]

Notes:
  - In remote mode, the repo is cloned (or updated) into INSTALL_DIR and then the local install runs.
USAGE
}

if [ "$(uname -s)" != "Darwin" ]; then
  echo "install.sh is macOS-only."
  exit 1
fi

MODE="auto"
REPO_URL="${REPO_URL:-https://github.com/prateek/dotfiles.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/dotfiles}"
DRY_RUN=0
FORWARD_ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --core|--full)
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --brewfile)
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --brewfile=*)
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    --repo-url=*)
      REPO_URL="${1#*=}"
      shift
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --install-dir=*)
      INSTALL_DIR="${1#*=}"
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
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

SCRIPT_DIR="$(script_dir)"

if [ "$MODE" = "auto" ]; then
  if [ -f "$SCRIPT_DIR/bootstrap.sh" ]; then
    MODE="local"
  else
    MODE="remote"
  fi
fi

case "$MODE" in
  local)
    # Keep password prompts to a minimum by requesting sudo once, early.
    request_sudo_keepalive

    ensure_xcode_clt || true
    exec "$SCRIPT_DIR/bootstrap.sh" "${FORWARD_ARGS[@]}"
    ;;
  remote)
    if ! ensure_xcode_clt; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "DRY RUN: skipping git clone because Xcode Command Line Tools are not installed."
        echo "Install them with: xcode-select --install"
        exit 0
      fi
    fi

    if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR/.git" ]; then
      echo "Error: $INSTALL_DIR exists but is not a git repo."
      exit 1
    fi

    if [ -d "$INSTALL_DIR/.git" ]; then
      echo "Updating existing repo at ${INSTALL_DIR}..."
      git -C "$INSTALL_DIR" pull --ff-only || true
    else
      echo "Cloning ${REPO_URL} -> ${INSTALL_DIR}..."
      git clone "$REPO_URL" "$INSTALL_DIR"
    fi

    # Keep password prompts to a minimum by requesting sudo once, early.
    request_sudo_keepalive

    cd "$INSTALL_DIR"
    chmod +x ./install.sh ./bootstrap.sh
    exec ./install.sh "${FORWARD_ARGS[@]}"
    ;;
  *)
    echo "Error: unknown mode '$MODE' (expected: local, remote, auto)"
    exit 2
    ;;
esac
