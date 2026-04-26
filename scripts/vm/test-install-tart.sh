#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_IMAGE="ghcr.io/cirruslabs/macos-tahoe-base:latest"
IMAGE="$DEFAULT_IMAGE"
LANE="smoke"
PROFILE="core"
MODE="local"
DRY_RUN=0
KEEP_VM=0
VM_NAME=""
LOG_FILE="${LOG_FILE:-}"
TRACE_FILE="${DOTFILES_TART_TRACE_FILE:-}"
VM_CPU=2
VM_MEMORY=4096

usage() {
  cat <<'USAGE'
Usage: scripts/vm/test-install-tart.sh [options]

Boots a fresh macOS VM using Tart, runs this repo's install flow, and then
deletes the VM (unless --keep-vm is set).

Options:
  --image <oci-image>     Tart image to clone (default: ghcr.io/cirruslabs/macos-tahoe-base:latest)
  --lane <smoke|full>     Test lane to run (default: smoke)
                          smoke: core profile, skip Homebrew casks/MAS
                          full: full profile, include casks/MAS
  --cpu <count>           VM CPU count (default: 2)
  --memory <mb>           VM memory in MB (default: 4096)
  --mode <local|remote>   local: mount current repo into VM (default)
                          remote: curl install.sh inside VM (tests public HTTPS install)
  --dry-run               Do not install; just print what would happen
  --vm-name <name>        VM name (default: dotfiles-install-test-<timestamp>)
  --keep-vm               Do not delete the VM on exit (useful for debugging)
  -h, --help              Show help

Environment (remote mode):
  REPO_URL                Repo URL used by install.sh (defaults to its internal default)
  DOTFILES_TART_TRACE_FILE
                          Optional Chrome/Perfetto trace JSON output path
USAGE
}

log() {
  if [ -n "${LOG_FILE:-}" ]; then
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
  else
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  fi
}

die() {
  log "ERROR: $*"
  exit 1
}

trace_now_us() {
  python3 - <<'PY' 2>/dev/null || printf '%s000000\n' "$(date +%s)"
import time
print(time.time_ns() // 1000)
PY
}

trace_json() {
  python3 - "$1" <<'PY' 2>/dev/null || printf '"%s"' "$1"
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

TRACE_OPEN=0
TRACE_EVENT_WRITTEN=0
BOOTSTRAP_TRACE_FILE=""

trace_init() {
  [ -n "$TRACE_FILE" ] || return 0
  mkdir -p "$(dirname "$TRACE_FILE")"
  printf '{"traceEvents":[\n' >"$TRACE_FILE"
  TRACE_OPEN=1
  TRACE_EVENT_WRITTEN=0
}

trace_emit() {
  [ "$TRACE_OPEN" = "1" ] || return 0

  local name="$1"
  local start_us="$2"
  local end_us="$3"
  local rc="${4:-0}"
  local duration_us="$(( end_us - start_us ))"
  local comma=""

  if [ "$TRACE_EVENT_WRITTEN" = "1" ]; then
    comma=","
  fi

  printf '%s{"name":%s,"cat":"tart","ph":"X","ts":%s,"dur":%s,"pid":1,"tid":1,"args":{"rc":%s}}\n' \
    "$comma" "$(trace_json "$name")" "$start_us" "$duration_us" "$rc" >>"$TRACE_FILE"
  TRACE_EVENT_WRITTEN=1
}

trace_finish() {
  [ "$TRACE_OPEN" = "1" ] || return 0
  printf ']}\n' >>"$TRACE_FILE"
  TRACE_OPEN=0
}

run_traced_logged() {
  local name="$1"
  shift

  local start_us end_us rc
  start_us="$(trace_now_us)"
  set +e
  "$@" >>"$LOG_FILE" 2>&1
  rc=$?
  set -e
  end_us="$(trace_now_us)"
  trace_emit "$name" "$start_us" "$end_us" "$rc"
  return "$rc"
}

run_traced_tee() {
  local name="$1"
  shift

  local start_us end_us rc
  start_us="$(trace_now_us)"
  set +e
  "$@" 2>&1 | tee -a "$LOG_FILE"
  rc="${PIPESTATUS[0]}"
  set -e
  end_us="$(trace_now_us)"
  trace_emit "$name" "$start_us" "$end_us" "$rc"
  return "$rc"
}

require_value() {
  local flag="$1"
  local value="${2:-}"

  if [ -z "$value" ]; then
    usage
    die "missing value for $flag"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image)
      require_value "$1" "${2:-}"
      IMAGE="$2"
      shift 2
      ;;
    --lane)
      require_value "$1" "${2:-}"
      LANE="$2"
      shift 2
      ;;
    --cpu)
      require_value "$1" "${2:-}"
      VM_CPU="$2"
      shift 2
      ;;
    --memory)
      require_value "$1" "${2:-}"
      VM_MEMORY="$2"
      shift 2
      ;;
    --mode)
      require_value "$1" "${2:-}"
      MODE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --vm-name)
      require_value "$1" "${2:-}"
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

if [ "$LANE" != "smoke" ] && [ "$LANE" != "full" ]; then
  die "--lane must be 'smoke' or 'full' (got: $LANE)"
fi

case "$LANE" in
  smoke) PROFILE="core" ;;
  full) PROFILE="full" ;;
esac

case "$VM_CPU" in
  ''|*[!0-9]*)
    die "--cpu must be a positive integer (got: $VM_CPU)"
    ;;
  *)
    if [ "$VM_CPU" -lt 1 ]; then
      die "--cpu must be >= 1 (got: $VM_CPU)"
    fi
    ;;
esac

case "$VM_MEMORY" in
  ''|*[!0-9]*)
    die "--memory must be a positive integer in MB (got: $VM_MEMORY)"
    ;;
  *)
    if [ "$VM_MEMORY" -lt 2048 ]; then
      die "--memory must be >= 2048 MB (got: $VM_MEMORY)"
    fi
    ;;
esac

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
trace_init

VM_SUDO_PASSWORD="${DOTFILES_TART_SUDO_PASSWORD:-admin}"

RUN_PID=""
VM_CREATED=0
POSTFLIGHT_DOTFILES_ROOT=""

brewfile_entries() {
  local kind="$1"
  local brewfile="$2"

  awk -v kind="$kind" -F'"' '$1 ~ "^" kind " " { print $2 }' "$brewfile" | xargs
}

cleanup() {
  set +e
  if [ "$KEEP_VM" = "1" ]; then
    log "Keeping VM '$VM_NAME' (log: $LOG_FILE)"
    trace_finish
    return 0
  fi

  if [ "$VM_CREATED" != "1" ]; then
    trace_finish
    return 0
  fi

  if tart list --quiet --source local 2>/dev/null | grep -qx "$VM_NAME"; then
    log "Stopping VM '$VM_NAME'…"
    trace_start_us="$(trace_now_us)"
    tart stop "$VM_NAME" >/dev/null 2>&1 || true
    trace_emit "stop VM" "$trace_start_us" "$(trace_now_us)" "0"
    if [ -n "${RUN_PID:-}" ] && kill -0 "$RUN_PID" >/dev/null 2>&1; then
      kill "$RUN_PID" >/dev/null 2>&1 || true
    fi
    log "Deleting VM '$VM_NAME'…"
    trace_start_us="$(trace_now_us)"
    tart delete "$VM_NAME" >/dev/null 2>&1 || true
    trace_emit "delete VM" "$trace_start_us" "$(trace_now_us)" "0"
  fi
  trace_finish
}
trap cleanup EXIT

log "Repo: $REPO_ROOT"
log "VM: $VM_NAME"
log "Image: $IMAGE"
log "Lane: $LANE"
log "Mode: $MODE"
log "Profile: $PROFILE"
log "CPU: $VM_CPU"
log "Memory MB: $VM_MEMORY"
log "Dry-run: $DRY_RUN"
log "Log: $LOG_FILE"
if [ -n "$TRACE_FILE" ]; then
  log "Trace: $TRACE_FILE"
  BOOTSTRAP_TRACE_FILE="${TRACE_FILE%.json}.bootstrap.json"
  log "Bootstrap trace: $BOOTSTRAP_TRACE_FILE"
fi

existing_vms="$(tart list --quiet --source local 2>>"$LOG_FILE")" || die "Unable to list local Tart VMs before clone."
if printf '%s\n' "$existing_vms" | grep -qx "$VM_NAME"; then
  die "VM '$VM_NAME' already exists; choose a different --vm-name or delete it first."
fi

log "Cloning image → VM…"
run_traced_logged "clone image" tart clone "$IMAGE" "$VM_NAME"
VM_CREATED=1

log "Configuring VM resources…"
run_traced_logged "configure VM resources" tart set "$VM_NAME" --cpu "$VM_CPU" --memory "$VM_MEMORY"

RUN_ARGS=(--no-graphics --no-audio --no-clipboard)
if [ "$MODE" = "local" ]; then
  RUN_ARGS+=(--dir "dotfiles:${REPO_ROOT}:ro")
fi

log "Starting VM…"
trace_start_us="$(trace_now_us)"
tart run "${RUN_ARGS[@]}" "$VM_NAME" >>"$LOG_FILE" 2>&1 &
RUN_PID="$!"
trace_emit "launch VM process" "$trace_start_us" "$(trace_now_us)" "0"

log "Waiting for VM guest agent…"
trace_start_us="$(trace_now_us)"
deadline="$(( $(date +%s) + 600 ))"
until tart exec "$VM_NAME" true >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    trace_emit "wait for guest agent" "$trace_start_us" "$(trace_now_us)" "1"
    die "Timed out waiting for VM to boot / guest agent to come up."
  fi
  sleep 5
done
trace_emit "wait for guest agent" "$trace_start_us" "$(trace_now_us)" "0"

log "Checking VM basics…"
run_traced_tee "guest uname" tart exec "$VM_NAME" uname -a
run_traced_tee "guest sw_vers" tart exec "$VM_NAME" sw_vers
run_traced_tee "guest identity" tart exec "$VM_NAME" sh -lc 'whoami; id'

if ! run_traced_logged "check Xcode CLT" tart exec "$VM_NAME" sh -lc 'xcode-select -p >/dev/null 2>&1'; then
  if [ "$DRY_RUN" = "1" ]; then
    log "Dry-run mode: Xcode Command Line Tools not present; continuing into install.sh --dry-run."
  else
    die "Xcode Command Line Tools not present in VM image; install.sh would block on GUI prompt. Use an image with CLT preinstalled."
  fi
fi

INSTALL_ENV=(DOTFILES_SUDO_PASSWORD="$VM_SUDO_PASSWORD")
if [ "$LANE" = "smoke" ]; then
  SMOKE_CASK_SKIP="$(brewfile_entries cask "$REPO_ROOT/Brewfile.core")"
  SMOKE_MAS_SKIP="$(brewfile_entries mas "$REPO_ROOT/Brewfile.core")"
  INSTALL_ENV+=(
    HOMEBREW_BUNDLE_CASK_SKIP="$SMOKE_CASK_SKIP"
    HOMEBREW_BUNDLE_MAS_SKIP="$SMOKE_MAS_SKIP"
  )
fi

case "$MODE" in
  local)
    log "Copying repo into VM home directory…"
    # shellcheck disable=SC2016
    run_traced_logged "copy repo into guest" tart exec "$VM_NAME" sh -lc '
      set -e
      SRC="$(/usr/bin/find /Volumes -maxdepth 3 -type d -name dotfiles -print -quit 2>/dev/null || true)"
      if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
        echo "Could not find mounted dotfiles directory under /Volumes"
        exit 2
      fi
      rm -rf "$HOME/dotfiles"
      mkdir -p "$HOME/dotfiles"
      /usr/bin/rsync -a --delete "$SRC"/ "$HOME/dotfiles"/
    '

    log "Running install.sh inside VM…"
    extra_args=()
    if [ "$DRY_RUN" = "1" ]; then
      extra_args+=(--dry-run)
    fi
    run_traced_tee "install local" tart exec "$VM_NAME" env "${INSTALL_ENV[@]}" sh -lc "
      set -e
      cd \"\$HOME/dotfiles\"
      export DOTFILES_BOOTSTRAP_TRACE_FILE=\"\$HOME/dotfiles-bootstrap.trace.json\"
      chmod +x ./install.sh ./bootstrap.sh
      ./install.sh --${PROFILE} ${extra_args[*]}
    "
    ;;
  remote)
    log "Running install.sh (remote) inside VM…"
    remote_args=(--"$PROFILE")
    if [ "$DRY_RUN" = "1" ]; then
      remote_args+=(--dry-run)
    fi
    POSTFLIGHT_DOTFILES_ROOT="${INSTALL_DIR:-}"
    run_traced_tee "install remote" tart exec "$VM_NAME" env "${INSTALL_ENV[@]}" REPO_URL="${REPO_URL:-}" INSTALL_DIR="${INSTALL_DIR:-}" sh -lc "
      set -e
      export REPO_URL
      export INSTALL_DIR
      export DOTFILES_BOOTSTRAP_TRACE_FILE=\"\$HOME/dotfiles-bootstrap.trace.json\"
      curl -fsSL https://raw.githubusercontent.com/prateek/dotfiles/master/install.sh | bash -s -- ${remote_args[*]}
    "
    ;;
esac

if [ -n "$BOOTSTRAP_TRACE_FILE" ]; then
  # shellcheck disable=SC2016
  if tart exec "$VM_NAME" sh -lc 'test -f "$HOME/dotfiles-bootstrap.trace.json"' >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    tart exec "$VM_NAME" sh -lc 'cat "$HOME/dotfiles-bootstrap.trace.json"' >"$BOOTSTRAP_TRACE_FILE" 2>>"$LOG_FILE" || true
  fi
fi

run_traced_tee "install log scan" "$REPO_ROOT/scripts/vm/check-install-log.sh" "$LOG_FILE"

log "Postflight checks…"
if [ "$DRY_RUN" = "1" ]; then
  log "Dry-run mode: skipping postflight tool and shell checks."
else
  # shellcheck disable=SC2016
  run_traced_tee "postflight macOS settings" tart exec "$VM_NAME" env DOTFILES_TART_POSTFLIGHT_ROOT="$POSTFLIGHT_DOTFILES_ROOT" sh -lc '
    set -e
    dotfiles_root="${DOTFILES_TART_POSTFLIGHT_ROOT:-$HOME/dotfiles}"
    cd "$dotfiles_root"
    ./scripts/vm/postflight-macos.sh
  '
  run_traced_tee "postflight tool checks" tart exec "$VM_NAME" zsh -lc 'command -v brew && command -v mise && command -v uv && command -v llm'
  # shellcheck disable=SC2016
  run_traced_tee "postflight zshrc symlink" tart exec "$VM_NAME" zsh -lc 'test -L "$HOME/.zshrc" && echo "~/.zshrc is a symlink (ok)"'
  # shellcheck disable=SC2016
  run_traced_tee "postflight fresh-shell verify" tart exec "$VM_NAME" env DOTFILES_SKIP_LAUNCHCTL_SYNC=1 DOTFILES_TART_POSTFLIGHT_ROOT="$POSTFLIGHT_DOTFILES_ROOT" zsh -lc '
    set -e
    dotfiles_root="${DOTFILES_TART_POSTFLIGHT_ROOT:-$HOME/dotfiles}"
    cd "$dotfiles_root"
    ./scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$dotfiles_root"
  '
fi

log "Install finished successfully."
