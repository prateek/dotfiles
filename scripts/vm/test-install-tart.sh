#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_IMAGE="ghcr.io/cirruslabs/macos-sequoia-base:latest"
IMAGE="$DEFAULT_IMAGE"
PROFILE="core"
MODE="local"
DRY_RUN=0
KEEP_VM=0
VM_NAME=""
LOG_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/vm/test-install-tart.sh [options]

Boots a fresh macOS VM using Tart, runs this repo's install flow, and then
deletes the VM (unless --keep-vm is set).

Options:
  --image <oci-image>     Tart image to clone (default: ghcr.io/cirruslabs/macos-sequoia-base:latest)
  --profile <core|full>   Which bootstrap profile to run (default: core)
  --mode <local|remote>   local: mount current repo into VM (default)
                          remote: curl install.sh inside VM (tests public HTTPS install)
  --dry-run               Do not install; just print what would happen
  --vm-name <name>        VM name (default: dotfiles-install-test-<timestamp>)
  --keep-vm               Do not delete the VM on exit (useful for debugging)
  -h, --help              Show help

Environment (remote mode):
  REPO_URL                Repo URL used by install.sh (defaults to its internal default)
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --vm-name)
      VM_NAME="$2"
      shift 2
      ;;
    --keep-vm)
      KEEP_VM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "Unknown arg: $1"
      ;;
  esac
done

if [ "$PROFILE" != "core" ] && [ "$PROFILE" != "full" ]; then
  die "--profile must be 'core' or 'full' (got: $PROFILE)"
fi

if [ "$MODE" != "local" ] && [ "$MODE" != "remote" ]; then
  die "--mode must be 'local' or 'remote' (got: $MODE)"
fi

if ! command -v tart >/dev/null 2>&1; then
  die "tart is not installed. Install it first: brew install cirruslabs/cli/tart"
fi

if [ -z "$VM_NAME" ]; then
  VM_NAME="dotfiles-install-test-$(date '+%Y%m%d-%H%M%S')"
fi

LOG_FILE="${LOG_FILE:-/tmp/${VM_NAME}.log}"
touch "$LOG_FILE"

VM_SUDO_PASSWORD="${DOTFILES_TART_SUDO_PASSWORD:-admin}"

RUN_PID=""

cleanup() {
  set +e
  if [ "$KEEP_VM" = "1" ]; then
    log "Keeping VM '$VM_NAME' (log: $LOG_FILE)"
    return 0
  fi

  if tart list --quiet --source local 2>/dev/null | grep -qx "$VM_NAME"; then
    log "Stopping VM '$VM_NAME'…"
    tart stop "$VM_NAME" >/dev/null 2>&1 || true
    if [ -n "${RUN_PID:-}" ] && kill -0 "$RUN_PID" >/dev/null 2>&1; then
      kill "$RUN_PID" >/dev/null 2>&1 || true
    fi
    log "Deleting VM '$VM_NAME'…"
    tart delete "$VM_NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log "Repo: $REPO_ROOT"
log "VM: $VM_NAME"
log "Image: $IMAGE"
log "Mode: $MODE"
log "Profile: $PROFILE"
log "Dry-run: $DRY_RUN"
log "Log: $LOG_FILE"

log "Cloning image → VM…"
tart clone "$IMAGE" "$VM_NAME" >>"$LOG_FILE" 2>&1

RUN_ARGS=(--no-graphics --no-audio --no-clipboard)
if [ "$MODE" = "local" ]; then
  RUN_ARGS+=(--dir "dotfiles:${REPO_ROOT}:ro")
fi

log "Starting VM…"
tart run "${RUN_ARGS[@]}" "$VM_NAME" >>"$LOG_FILE" 2>&1 &
RUN_PID="$!"

log "Waiting for VM guest agent…"
deadline="$(( $(date +%s) + 600 ))"
until tart exec "$VM_NAME" true >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    die "Timed out waiting for VM to boot / guest agent to come up."
  fi
  sleep 5
done

log "Checking VM basics…"
tart exec "$VM_NAME" uname -a | tee -a "$LOG_FILE"
tart exec "$VM_NAME" sw_vers | tee -a "$LOG_FILE"
tart exec "$VM_NAME" sh -lc 'whoami; id' | tee -a "$LOG_FILE"

if ! tart exec "$VM_NAME" sh -lc 'xcode-select -p >/dev/null 2>&1'; then
  die "Xcode Command Line Tools not present in VM image; install.sh would block on GUI prompt. Use an image with CLT preinstalled."
fi

case "$MODE" in
  local)
    log "Copying repo into VM home directory…"
    # shellcheck disable=SC2016
    tart exec "$VM_NAME" sh -lc '
      set -e
      SRC="$(/usr/bin/find /Volumes -maxdepth 3 -type d -name dotfiles -print -quit 2>/dev/null || true)"
      if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
        echo "Could not find mounted dotfiles directory under /Volumes"
        exit 2
      fi
      rm -rf "$HOME/dotfiles"
      mkdir -p "$HOME/dotfiles"
      /usr/bin/rsync -a --delete "$SRC"/ "$HOME/dotfiles"/
    ' >>"$LOG_FILE" 2>&1

    log "Running install.sh inside VM…"
    extra_args=()
    if [ "$DRY_RUN" = "1" ]; then
      extra_args+=(--dry-run)
    fi
    tart exec "$VM_NAME" env DOTFILES_SUDO_PASSWORD="$VM_SUDO_PASSWORD" sh -lc "
      set -e
      cd \"\$HOME/dotfiles\"
      chmod +x ./install.sh ./bootstrap.sh
      ./install.sh --${PROFILE} ${extra_args[*]}
    " | tee -a "$LOG_FILE"
    ;;
  remote)
    log "Running install.sh (remote) inside VM…"
    remote_args=(--"$PROFILE")
    if [ "$DRY_RUN" = "1" ]; then
      remote_args+=(--dry-run)
    fi
    tart exec "$VM_NAME" env DOTFILES_SUDO_PASSWORD="$VM_SUDO_PASSWORD" sh -lc "
      set -e
      REPO_URL=\"\${REPO_URL:-}\"
      export REPO_URL
      curl -fsSL https://raw.githubusercontent.com/prateek/dotfiles/master/install.sh | bash -s -- ${remote_args[*]}
    " | tee -a "$LOG_FILE"
    ;;
esac

log "Postflight checks…"
if [ "$DRY_RUN" = "1" ]; then
  log "Dry-run mode: skipping postflight tool presence checks."
else
  tart exec "$VM_NAME" zsh -lc 'command -v brew && command -v mise && command -v uv && command -v llm' | tee -a "$LOG_FILE"
  # shellcheck disable=SC2016
  tart exec "$VM_NAME" zsh -lc 'test -L "$HOME/.zshrc" && echo "~/.zshrc is a symlink (ok)"' | tee -a "$LOG_FILE"
fi

log "Install finished successfully."
