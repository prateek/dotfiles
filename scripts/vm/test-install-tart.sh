#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_SMOKE_IMAGE="ghcr.io/cirruslabs/macos-tahoe-base:latest"
DEFAULT_FULL_IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
IMAGE=""
LANE="smoke"
PROFILE="core"
MODE="local"
DRY_RUN=0
KEEP_VM=0
VM_NAME=""
LOG_FILE="${LOG_FILE:-}"
REQUESTED_TRACE_FILE="${DOTFILES_TART_TRACE_FILE:-}"
USE_HOMEBREW_CACHE=1
HOST_HOMEBREW_CACHE_DIR="${DOTFILES_TART_HOMEBREW_CACHE_DIR:-${TART_HOMEBREW_CACHE_DIR:-}}"
GUEST_HOMEBREW_CACHE_DIR="/Volumes/My Shared Files/homebrew-cache"
TRACE_ENABLED=0
TRACE_ROOT=""
HOST_TRACE_FILE=""
MERGED_TRACE_FILE=""
GUEST_TRACE_ROOT=""
GUEST_TRACE_COLLECTED=0
VM_CPU=2
VM_MEMORY=4096

TRACE_FILE=""
TRACE_CATEGORY="tart"
TRACE_PROCESS_NAME="VM lifecycle"
TRACE_THREAD_NAME="Tart phases"
TRACE_PID=1
TRACE_TID=1
TRACE_SORT_INDEX=0
export TRACE_FILE TRACE_CATEGORY TRACE_PROCESS_NAME TRACE_THREAD_NAME TRACE_PID TRACE_TID TRACE_SORT_INDEX
# shellcheck source=scripts/trace/perfetto-trace.bash
source "$REPO_ROOT/scripts/trace/perfetto-trace.bash"
RUN_STARTED_US="$(trace_now_us)"
TIMING_NAMES=()
TIMING_MS=()
TIMING_RCS=()

if [ "${DOTFILES_TRACE:-0}" = "1" ] || [ -n "$REQUESTED_TRACE_FILE" ]; then
  TRACE_ENABLED=1
fi

usage() {
  cat <<'USAGE'
Usage: scripts/vm/test-install-tart.sh [options]

Boots a fresh macOS VM using Tart, runs this repo's install flow, and then
deletes the VM (unless --keep-vm is set).

Options:
  --image <oci-image>     Tart image to clone (default: smoke uses ghcr.io/cirruslabs/macos-tahoe-base:latest;
                          full uses ghcr.io/cirruslabs/macos-tahoe-xcode:latest)
  --lane <smoke|full>     Test lane to run (default: smoke)
                          smoke: core profile, skip Homebrew casks/MAS
                          full: full profile, include casks; MAS requires opt-in
  --cpu <count>           VM CPU count (default: 2)
  --memory <mb>           VM memory in MB (default: 4096)
  --mode <local|remote>   local: mount current repo into VM (default)
                          remote: chezmoi one-liner inside VM (tests public bootstrap)
  --dry-run               Do not install; just print what would happen
  --vm-name <name>        VM name (default: dotfiles-install-test-<timestamp>)
  --keep-vm               Do not delete the VM on exit (useful for debugging)
  --homebrew-cache-dir <path>
                          Host directory mounted as the guest HOMEBREW_CACHE
  --no-homebrew-cache     Disable the persistent host-backed Homebrew cache
  -h, --help              Show help

Environment (remote mode):
  REPO_URL                Reserved for remote-mode override (currently chezmoi clones github.com/prateek/dotfiles)

Environment (tracing):
  DOTFILES_TRACE=1        Enable Perfetto trace artifacts. Local mode also
                          captures guest zsh spans; remote mode records host
                          Tart lifecycle phases only.
  DOTFILES_TART_TRACE_FILE
                          Optional merged Chrome/Perfetto trace JSON output path

Environment (Homebrew cache):
  DOTFILES_TART_HOMEBREW_CACHE_DIR
                          Host directory for the VM Homebrew cache
                          (default: sibling of TART_HOME when set, otherwise
                          ~/.cache/dotfiles-tart-homebrew)

Environment (debugging):
  DOTFILES_TART_VNC=1     Boot the VM with --vnc-experimental instead of
                          --no-graphics. Tart prints a vnc:// URL to the
                          per-run log (path shown in script output) once
                          the guest is up; connect with Screen Sharing.app
                          or any VNC client. Useful for live monitoring
                          of long-running installs.
USAGE
}

# shellcheck source=scripts/vm/lib.sh
source "$REPO_ROOT/scripts/vm/lib.sh"

trace_record_timing() {
  local name="$1"
  local start_us="$2"
  local end_us="$3"
  local rc="$4"
  local duration_ms="$(( (end_us - start_us) / 1000 ))"

  if [ "$duration_ms" -lt 0 ]; then
    duration_ms=0
  fi

  TIMING_NAMES+=("$name")
  TIMING_MS+=("$duration_ms")
  TIMING_RCS+=("$rc")
}

format_ms() {
  local ms="$1"
  printf '%d.%03ds' "$(( ms / 1000 ))" "$(( ms % 1000 ))"
}

emit_timing_summary() {
  local now_us total_ms count index ms rc name

  count="${#TIMING_NAMES[@]}"
  if [ "$count" -eq 0 ]; then
    return 0
  fi

  now_us="$(trace_now_us)"
  total_ms="$(( (now_us - RUN_STARTED_US) / 1000 ))"
  log "Timing summary: total=$(format_ms "$total_ms"), phases=$count"
  {
    for (( index = 0; index < count; index++ )); do
      printf '%s\t%s\t%s\n' "${TIMING_MS[$index]}" "${TIMING_RCS[$index]}" "${TIMING_NAMES[$index]}"
    done
  } | sort -rn | head -15 | while IFS=$'\t' read -r ms rc name; do
    log "Timing: $(format_ms "$ms") rc=$rc $name"
  done
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
    --homebrew-cache-dir)
      require_value "$1" "${2:-}"
      HOST_HOMEBREW_CACHE_DIR="$2"
      USE_HOMEBREW_CACHE=1
      shift 2
      ;;
    --no-homebrew-cache)
      USE_HOMEBREW_CACHE=0
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

case "$LANE" in
  smoke)
    PROFILE="core"
    IMAGE="${IMAGE:-$DEFAULT_SMOKE_IMAGE}"
    ;;
  full)
    PROFILE="full"
    IMAGE="${IMAGE:-$DEFAULT_FULL_IMAGE}"
    ;;
  *) die "--lane must be 'smoke' or 'full' (got: $LANE)" ;;
esac

require_integer_at_least --cpu "$VM_CPU" 1
require_integer_at_least --memory "$VM_MEMORY" 2048 MB

if [ "$MODE" != "local" ] && [ "$MODE" != "remote" ]; then
  die "--mode must be 'local' or 'remote' (got: $MODE)"
fi

if ! command -v tart >/dev/null 2>&1; then
  die "tart is not installed. Install it first: brew install cirruslabs/cli/tart"
fi

if [ -z "$VM_NAME" ]; then
  VM_NAME="dotfiles-install-test-$(date '+%Y%m%d-%H%M%S')"
fi

if [ "$USE_HOMEBREW_CACHE" = "1" ] && [ -z "$HOST_HOMEBREW_CACHE_DIR" ]; then
  if [ -n "${TART_HOME:-}" ]; then
    HOST_HOMEBREW_CACHE_DIR="$(dirname "$TART_HOME")/homebrew-cache"
  else
    HOST_HOMEBREW_CACHE_DIR="$HOME/.cache/dotfiles-tart-homebrew"
  fi
fi

LOG_FILE="${LOG_FILE:-/tmp/${VM_NAME}.log}"
touch "$LOG_FILE"

VM_SUDO_PASSWORD="${DOTFILES_TART_SUDO_PASSWORD:-admin}"

RUN_PID=""
VM_CREATED=0
POSTFLIGHT_DOTFILES_ROOT=""
HOST_PROFILE_BREWFILE=""

configure_trace() {
  [ "$TRACE_ENABLED" = "1" ] || return 0

  # Raw xtrace captures command text. Keep trace artifacts private by default.
  umask 077

  if [ -n "$REQUESTED_TRACE_FILE" ]; then
    MERGED_TRACE_FILE="$REQUESTED_TRACE_FILE"
    TRACE_ROOT="${REQUESTED_TRACE_FILE%.json}.artifacts"
  else
    TRACE_ROOT="${DOTFILES_TART_TRACE_DIR:-${LOG_FILE%.log}.trace}"
    MERGED_TRACE_FILE="$TRACE_ROOT/tart-install.perfetto.json"
  fi

  HOST_TRACE_FILE="$TRACE_ROOT/host.perfetto.json"
  GUEST_TRACE_ROOT="$TRACE_ROOT/guest"
  mkdir -p "$TRACE_ROOT" "$GUEST_TRACE_ROOT"
  chmod 700 "$TRACE_ROOT" "$GUEST_TRACE_ROOT"

  TRACE_FILE="$HOST_TRACE_FILE"
  export TRACE_FILE
  trace_init
}

copy_guest_trace_file() {
  local guest_rel_path="$1"
  local host_path="$2"

  # shellcheck disable=SC2016
  if ! tart exec "$VM_NAME" env DOTFILES_TRACE_REL_PATH="$guest_rel_path" sh -lc 'test -f "$HOME/$DOTFILES_TRACE_REL_PATH"' >/dev/null 2>&1; then
    return 0
  fi

  # shellcheck disable=SC2016
  if tart exec "$VM_NAME" env DOTFILES_TRACE_REL_PATH="$guest_rel_path" sh -lc 'cat "$HOME/$DOTFILES_TRACE_REL_PATH"' >"$host_path" 2>>"$LOG_FILE"; then
    chmod 600 "$host_path" 2>/dev/null || true
  else
    rm -f "$host_path"
  fi
}

collect_guest_trace_artifacts() {
  [ "$TRACE_ENABLED" = "1" ] || return 0
  [ "$VM_CREATED" = "1" ] || return 0
  [ "$GUEST_TRACE_COLLECTED" = "0" ] || return 0
  GUEST_TRACE_COLLECTED=1

  if ! vm_exists; then
    return 0
  fi

  local guest_trace_dir="dotfiles-trace/install"
  local guest_trace_files=(
    stdout.log
    stderr.log
    manifest.json
    trace.perfetto.json
    summary.json
  )
  local host_trace_dir="$GUEST_TRACE_ROOT/$guest_trace_dir"

  mkdir -p "$host_trace_dir"
  chmod 700 "$GUEST_TRACE_ROOT" "$GUEST_TRACE_ROOT/dotfiles-trace" "$host_trace_dir" 2>/dev/null || true
  # shellcheck disable=SC2016
  if tart exec "$VM_NAME" sh -lc 'test -d "$HOME/dotfiles-trace/install"' >/dev/null 2>&1; then
    log "Collecting guest trace artifacts…"
    local trace_file
    for trace_file in "${guest_trace_files[@]}"; do
      copy_guest_trace_file "$guest_trace_dir/$trace_file" "$host_trace_dir/$trace_file"
    done
  fi
}

finish_trace() {
  [ "$TRACE_ENABLED" = "1" ] || return 0
  trace_finish

  local trace_inputs=()
  if [ -f "$HOST_TRACE_FILE" ]; then
    trace_inputs+=("$HOST_TRACE_FILE")
  fi
  if [ -d "$GUEST_TRACE_ROOT" ]; then
    while IFS= read -r -d '' trace_path; do
      trace_inputs+=("$trace_path")
    done < <(find "$GUEST_TRACE_ROOT" -type f -name '*.perfetto.json' -print0 2>/dev/null)
  fi

  if [ "${#trace_inputs[@]}" -gt 0 ]; then
    if "$REPO_ROOT/scripts/trace/merge-perfetto" --output "$MERGED_TRACE_FILE" "${trace_inputs[@]}" >>"$LOG_FILE" 2>&1; then
      chmod 600 "$MERGED_TRACE_FILE" 2>/dev/null || true
      log "Trace written: $MERGED_TRACE_FILE"
    else
      log "Warning: failed to merge trace artifacts; raw artifacts are in $TRACE_ROOT"
      return 1
    fi
  else
    log "Warning: no trace inputs found; raw artifacts are in $TRACE_ROOT"
    return 1
  fi
}

configure_trace

brewfile_entries() {
  local kind="$1"
  local brewfile="$2"

  awk -v kind="$kind" -F'"' '$1 ~ "^" kind " " { print $2 }' "$brewfile" | xargs
}

render_profile_brewfile() {
  local profile="$1"
  local output="$2"

  "$REPO_ROOT/scripts/packages/render-brewfile" --profile "$profile" --output "$output"
}

cleanup() {
  local original_rc="$?"
  local trace_rc=0
  local cleanup_rc=0
  local stop_rc=0
  local delete_rc=0

  set +e
  if [ -n "$HOST_PROFILE_BREWFILE" ]; then
    rm -f "$HOST_PROFILE_BREWFILE"
  fi
  collect_guest_trace_artifacts
  if [ "$KEEP_VM" = "1" ]; then
    log "Keeping VM '$VM_NAME' (log: $LOG_FILE)"
  elif [ "$VM_CREATED" = "1" ] && vm_exists; then
    log "Stopping VM '$VM_NAME'…"
    trace_start_us="$(trace_now_us)"
    tart stop "$VM_NAME" >/dev/null 2>&1
    stop_rc="$?"
    trace_end_us="$(trace_now_us)"
    trace_emit "stop VM" "$trace_start_us" "$trace_end_us" "$stop_rc"
    trace_record_timing "stop VM" "$trace_start_us" "$trace_end_us" "$stop_rc"
    if [ "$stop_rc" -ne 0 ]; then
      log "Warning: tart stop failed for '$VM_NAME' (rc=$stop_rc); attempting delete anyway."
    fi
    if [ -n "${RUN_PID:-}" ] && kill -0 "$RUN_PID" >/dev/null 2>&1; then
      kill "$RUN_PID" >/dev/null 2>&1 || true
    fi
    log "Deleting VM '$VM_NAME'…"
    trace_start_us="$(trace_now_us)"
    tart delete "$VM_NAME" >/dev/null 2>&1
    delete_rc="$?"
    trace_end_us="$(trace_now_us)"
    trace_emit "delete VM" "$trace_start_us" "$trace_end_us" "$delete_rc"
    trace_record_timing "delete VM" "$trace_start_us" "$trace_end_us" "$delete_rc"
    if [ "$delete_rc" -ne 0 ]; then
      log "Warning: tart delete failed for '$VM_NAME' (rc=$delete_rc)."
      cleanup_rc="$delete_rc"
    fi
  fi

  emit_timing_summary
  finish_trace || trace_rc=$?
  if [ "$original_rc" -eq 0 ] && [ "$cleanup_rc" -ne 0 ]; then
    original_rc="$cleanup_rc"
  fi
  if [ "$original_rc" -eq 0 ] && [ "$trace_rc" -ne 0 ]; then
    original_rc="$trace_rc"
  fi
  trap - EXIT
  exit "$original_rc"
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
if [ "$USE_HOMEBREW_CACHE" = "1" ]; then
  mkdir -p "$HOST_HOMEBREW_CACHE_DIR"
  HOST_HOMEBREW_CACHE_DIR="$(cd "$HOST_HOMEBREW_CACHE_DIR" && pwd -P)"
  chmod 700 "$HOST_HOMEBREW_CACHE_DIR" 2>/dev/null || true
  log "Homebrew cache: $HOST_HOMEBREW_CACHE_DIR"
fi
if [ "$TRACE_ENABLED" = "1" ]; then
  log "Trace: $MERGED_TRACE_FILE"
  log "Trace artifacts: $TRACE_ROOT"
  if [ "$MODE" = "remote" ]; then
    log "Trace note: remote mode records host Tart lifecycle phases only; guest zsh spans require local mode."
  fi
fi

if vm_exists; then
  die "VM '$VM_NAME' already exists; choose a different --vm-name or delete it first."
fi

log "Cloning image → VM…"
if ! run_traced_logged "clone image" tart clone "$IMAGE" "$VM_NAME"; then
  if vm_exists; then
    VM_CREATED=1
  fi
  die "Failed to clone image into VM '$VM_NAME'."
fi
VM_CREATED=1

log "Configuring VM resources…"
run_traced_logged "configure VM resources" tart set "$VM_NAME" --cpu "$VM_CPU" --memory "$VM_MEMORY"

# DOTFILES_TART_VNC=1 swaps --no-graphics for --vnc-experimental so a VNC
# client (e.g. Screen Sharing.app) can attach for live GUI monitoring.
# Tart prints the `vnc://…` connection URL to stdout once the guest is up
# — `grep -F vnc:// $LOG_FILE` to find it.
if [ "${DOTFILES_TART_VNC:-0}" = "1" ]; then
  RUN_ARGS=(--vnc-experimental --no-audio --no-clipboard)
else
  RUN_ARGS=(--no-graphics --no-audio --no-clipboard)
fi
if [ "$MODE" = "local" ]; then
  RUN_ARGS+=(--dir "dotfiles:${REPO_ROOT}:ro")
fi
if [ "$USE_HOMEBREW_CACHE" = "1" ]; then
  RUN_ARGS+=(--dir "homebrew-cache:${HOST_HOMEBREW_CACHE_DIR}")
fi

log "Starting VM…"
trace_start_us="$(trace_now_us)"
tart run "${RUN_ARGS[@]}" "$VM_NAME" >>"$LOG_FILE" 2>&1 &
RUN_PID="$!"
trace_end_us="$(trace_now_us)"
trace_emit "launch VM process" "$trace_start_us" "$trace_end_us" "0"
trace_record_timing "launch VM process" "$trace_start_us" "$trace_end_us" "0"

log "Waiting for VM guest agent…"
trace_start_us="$(trace_now_us)"
deadline="$(( $(date +%s) + 600 ))"
until tart exec "$VM_NAME" true >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    trace_end_us="$(trace_now_us)"
    trace_emit "wait for guest agent" "$trace_start_us" "$trace_end_us" "1"
    trace_record_timing "wait for guest agent" "$trace_start_us" "$trace_end_us" "1"
    die "Timed out waiting for VM to boot / guest agent to come up."
  fi
  sleep 5
done
trace_end_us="$(trace_now_us)"
trace_emit "wait for guest agent" "$trace_start_us" "$trace_end_us" "0"
trace_record_timing "wait for guest agent" "$trace_start_us" "$trace_end_us" "0"

log "Checking VM basics…"
run_traced_tee "guest uname" tart exec "$VM_NAME" uname -a
run_traced_tee "guest sw_vers" tart exec "$VM_NAME" sw_vers
run_traced_tee "guest identity" tart exec "$VM_NAME" sh -lc 'whoami; id'

if [ "$USE_HOMEBREW_CACHE" = "1" ]; then
  # shellcheck disable=SC2016
  run_traced_tee "check Homebrew cache mount" tart exec "$VM_NAME" sh -lc '
    set -e
    cache="/Volumes/My Shared Files/homebrew-cache"
    test -d "$cache"
    test -w "$cache"
    mkdir -p "$cache/api" "$cache/bundle"
    printf "Homebrew cache mount: %s\n" "$cache"
  '
fi

if ! run_traced_logged "check Xcode CLT" tart exec "$VM_NAME" sh -lc 'xcode-select -p >/dev/null 2>&1'; then
  if [ "$DRY_RUN" = "1" ]; then
    log "Dry-run mode: Xcode Command Line Tools not present; continuing into chezmoi dry-run apply."
  else
    die "Xcode Command Line Tools not present in VM image; chezmoi init would fail at git clone (CLT bundles git). Use an image with CLT preinstalled."
  fi
fi

INSTALL_ENV=(DOTFILES_SUDO_PASSWORD="$VM_SUDO_PASSWORD")
# Forward the chezmoi.toml.tmpl gates from host env so a full-coverage
# E2E lane can exercise privileged + secrets + MAS branches without
# hand-editing this script. Each is a passthrough; chezmoi reads them
# via promptStringOnce/promptBoolOnce env-var fallback.
for var in \
  DOTFILES_INSTALL_MAS_APPS \
  DOTFILES_RUN_INSTALL_SCRIPTS \
  DOTFILES_APPLY_DEFAULTS \
  DOTFILES_APPLY_PRIVILEGED_APP_ASSETS \
  DOTFILES_SECRETS_ENABLED \
  DOTFILES_MANAGE_ZINIT_EXTERNAL \
  DOTFILES_SKIP_LSREGISTER \
  DOTFILES_SKIP_REINDEX \
  DOTFILES_SKIP_APP_RESTART \
  DOTFILES_SKIP_PLIST_HOOKS \
  DOTFILES_RELAUNCH_AFTER_APPLY \
; do
  if [ -n "${!var:-}" ]; then
    INSTALL_ENV+=("$var=${!var}")
  fi
done
if [ "$USE_HOMEBREW_CACHE" = "1" ]; then
  INSTALL_ENV+=(
    HOMEBREW_CACHE="$GUEST_HOMEBREW_CACHE_DIR"
    HOMEBREW_BUNDLE_USER_CACHE="$GUEST_HOMEBREW_CACHE_DIR/bundle"
  )
fi
if [ "$LANE" = "smoke" ]; then
  HOST_PROFILE_BREWFILE="$(mktemp "${TMPDIR:-/tmp}/dotfiles-brewfile-core.XXXXXX")"
  render_profile_brewfile core "$HOST_PROFILE_BREWFILE"
  SMOKE_CASK_SKIP="$(brewfile_entries cask "$HOST_PROFILE_BREWFILE")"
  INSTALL_ENV+=(
    HOMEBREW_BUNDLE_CASK_SKIP="$SMOKE_CASK_SKIP"
  )
fi

# Bootstrap inside the VM via the chezmoi-blessed pattern:
#   1. Download chezmoi via get.chezmoi.io (no permanent install — chezmoi
#      itself comes in via brew bundle later). Lands in $HOME/.local/bin.
#   2. chezmoi init --apply --no-tty --promptDefaults reads
#      home/.chezmoi.toml.tmpl prompts (DOTFILES_* env overrides applied
#      by INSTALL_ENV via promptDefaults fallback).
# DRY_RUN=1 splits init from apply so we can pass --dry-run.
INSTALL_ENV+=(DOTFILES_INSTALL_PROFILE="$PROFILE")

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

    log "Bootstrapping chezmoi inside VM (local source)…"
    if [ "$DRY_RUN" = "1" ]; then
      # Dry-run validates bootstrap path: install chezmoi, init reads the
      # template + clones into source state, status reports what would
      # change. Avoid `apply --dry-run --verbose` because it streams every
      # file's diff and overruns Tart's gRPC transport.
      bootstrap_cmd='
        set -e
        export PATH="$HOME/.local/bin:$PATH"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        chezmoi --no-tty init --promptDefaults --source "$HOME/dotfiles"
        chezmoi --no-tty status | head -50
      '
    else
      bootstrap_cmd='
        set -e
        export PATH="$HOME/.local/bin:$PATH"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        chezmoi --no-tty init --promptDefaults --apply --source "$HOME/dotfiles"
      '
    fi
    if [ "$TRACE_ENABLED" = "1" ]; then
      run_traced_tee "install local" tart exec "$VM_NAME" env "${INSTALL_ENV[@]}" sh -lc "
        $bootstrap_cmd
      "
    else
      run_traced_tee "install local" tart exec "$VM_NAME" env "${INSTALL_ENV[@]}" sh -lc "
        $bootstrap_cmd
      "
    fi
    ;;
  remote)
    log "Bootstrapping chezmoi inside VM (remote / github.com/prateek/dotfiles)…"
    POSTFLIGHT_DOTFILES_ROOT="${INSTALL_DIR:-}"
    if [ "$DRY_RUN" = "1" ]; then
      remote_cmd='
        set -e
        export PATH="$HOME/.local/bin:$PATH"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        chezmoi --no-tty init --promptDefaults prateek
        chezmoi --no-tty status | head -50
      '
    else
      remote_cmd='
        set -e
        export PATH="$HOME/.local/bin:$PATH"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        chezmoi --no-tty init --promptDefaults --apply prateek
      '
    fi
    run_traced_tee "install remote" tart exec "$VM_NAME" env "${INSTALL_ENV[@]}" sh -lc "$remote_cmd"
    ;;
esac

run_traced_tee "install log scan" "$REPO_ROOT/scripts/vm/check-install-log.sh" "$LOG_FILE"

log "Postflight checks…"
if [ "$DRY_RUN" = "1" ]; then
  log "Dry-run mode: skipping postflight tool and shell checks."
else
  # shellcheck disable=SC2016
  run_traced_tee "postflight macOS settings" tart exec "$VM_NAME" env DOTFILES_TART_POSTFLIGHT_ROOT="$POSTFLIGHT_DOTFILES_ROOT" sh -lc '
    set -e
    # The chezmoi binary lives at $HOME/.local/bin/chezmoi after the
    # get.chezmoi.io bootstrap; postflight asserts `chezmoi status`.
    export PATH="$HOME/.local/bin:$PATH"
    dotfiles_root="${DOTFILES_TART_POSTFLIGHT_ROOT:-$HOME/dotfiles}"
    cd "$dotfiles_root"
    ./scripts/vm/postflight-macos.sh
  '
  run_traced_tee "postflight tool checks" tart exec "$VM_NAME" zsh -lc 'command -v brew && command -v mise && command -v uv && command -v llm'
  # shellcheck disable=SC2016
  run_traced_tee "postflight chezmoi zsh files" tart exec "$VM_NAME" zsh -lc 'test -f "$HOME/.zshenv" && test -f "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc" && echo "chezmoi zsh files materialized (ok)"'
  # shellcheck disable=SC2016
  run_traced_tee "postflight fresh-shell verify" tart exec "$VM_NAME" env DOTFILES_SKIP_LAUNCHCTL_SYNC=1 DOTFILES_TART_POSTFLIGHT_ROOT="$POSTFLIGHT_DOTFILES_ROOT" zsh -lc '
    set -e
    dotfiles_root="${DOTFILES_TART_POSTFLIGHT_ROOT:-$HOME/dotfiles}"
    cd "$dotfiles_root"
    ./scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$dotfiles_root"
  '
fi

log "Install finished successfully."
