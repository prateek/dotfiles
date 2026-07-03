#!/usr/bin/env bash
#
# Build (or refresh) the golden Tartelet runner VM. Clones a cirruslabs Xcode
# base image into a named local VM, selects the pinned Xcode, and shuts it down.
# Tartelet then re-clones this VM per job, so provisioning done here is inherited
# by every ephemeral runner.
#
# Idempotent: a marker under TART_HOME records the Xcode pin the VM was built
# against. Re-running is a no-op until the pin (ios-triple.json) changes or
# --force is passed. Guards the boot disk via scripts/vm/lib.sh, same as the
# install-validation lane.
#
# The cirruslabs *-xcode images ship Xcode preinstalled and log in as admin/admin,
# so there is no interactive Apple ID download and no separate SSH user to create;
# configure Tartelet's guest SSH credentials as admin/admin to match.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/vm/lib.sh
source "$REPO_ROOT/scripts/vm/lib.sh"

BASE_IMAGE="${DOTFILES_RUNNER_BASE_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-xcode:latest}"
VM_NAME="${DOTFILES_RUNNER_VM_NAME:-tartelet-runner}"
VM_CPU="${DOTFILES_RUNNER_VM_CPU:-4}"
VM_MEMORY="${DOTFILES_RUNNER_VM_MEMORY:-8192}"
TRIPLE_FILE="${DOTFILES_IOS_TRIPLE_FILE:-$HOME/.agents/state/ios-triple.json}"
FORCE=0
RUN_PID=""

usage() {
  cat <<EOF
Usage: build-runner-image.sh [options]

Build or refresh the golden Tartelet runner VM ('$VM_NAME').

Options:
  --force               Rebuild even if the VM already matches the Xcode pin.
  --vm-name NAME        VM name to build (default: $VM_NAME).
  --image REF           Base image to clone (default: $BASE_IMAGE).
  --cpu N               vCPUs for the VM (default: $VM_CPU).
  --memory MB           Memory in MiB (default: $VM_MEMORY).
  -h, --help            Show this help.

Environment:
  DOTFILES_TART_ALLOW_BOOT_DISK=1   Override the external-SSD boot-disk guard.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --vm-name) require_value "$1" "${2:-}"; VM_NAME="$2"; shift ;;
    --image) require_value "$1" "${2:-}"; BASE_IMAGE="$2"; shift ;;
    --cpu) require_value "$1" "${2:-}"; VM_CPU="$2"; shift ;;
    --memory) require_value "$1" "${2:-}"; VM_MEMORY="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown argument: $1" ;;
  esac
  shift
done

command -v tart >/dev/null 2>&1 || die "tart is required (brew install cirruslabs/cli/tart)."
command -v jq >/dev/null 2>&1 || die "jq is required to read the Xcode pin."
[ -r "$TRIPLE_FILE" ] || die "missing Xcode version pin: $TRIPLE_FILE"

xcode_version="$(jq -r '.xcode_version // empty' "$TRIPLE_FILE")"
[ -n "$xcode_version" ] || die "missing .xcode_version in $TRIPLE_FILE"

require_integer_at_least "--cpu" "$VM_CPU" 1
require_integer_at_least "--memory" "$VM_MEMORY" 1024 "MiB"

check_tart_home_external || die "aborting to protect the boot disk (mount the external SSD or set DOTFILES_TART_ALLOW_BOOT_DISK=1)."

tart_home="${TART_HOME:-$HOME/.tart}"
marker="$tart_home/.${VM_NAME}.provisioned"
want_marker="xcode=$xcode_version"

if [ "$FORCE" != "1" ] && vm_exists && [ -r "$marker" ] && [ "$(cat "$marker")" = "$want_marker" ]; then
  log "Golden runner VM '$VM_NAME' already matches the pin ($want_marker); nothing to do."
  exit 0
fi

cleanup() {
  if [ -n "$RUN_PID" ] && kill -0 "$RUN_PID" 2>/dev/null; then
    tart stop "$VM_NAME" >/dev/null 2>&1 || true
    wait "$RUN_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Reuse an existing VM when possible: a failed provision should not force another
# multi-GB pull. --force re-clones from scratch.
need_clone=1
if vm_exists; then
  if [ "$FORCE" = "1" ]; then
    log "Removing existing '$VM_NAME' before a forced rebuild."
    tart delete "$VM_NAME"
  else
    log "Reusing existing '$VM_NAME' (re-provisioning in place; pass --force to re-clone)."
    need_clone=0
  fi
fi

if [ "$need_clone" = "1" ]; then
  log "Cloning '$BASE_IMAGE' into '$VM_NAME' (this pulls several GB on first use)…"
  tart clone "$BASE_IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$VM_CPU" --memory "$VM_MEMORY"
fi

log "Booting '$VM_NAME' headless…"
tart run --no-graphics --no-audio --no-clipboard "$VM_NAME" >/dev/null 2>&1 &
RUN_PID="$!"

log "Waiting for the guest agent…"
deadline="$(( $(date +%s) + 600 ))"
until tart exec "$VM_NAME" true >/dev/null 2>&1; do
  [ "$(date +%s)" -ge "$deadline" ] && die "timed out waiting for '$VM_NAME' to boot."
  sleep 5
done

# Select the pinned Xcode only if the image actually ships it; otherwise keep the
# image's default (a fresh cirruslabs image is often ahead of the pin). `xcodes
# select` prompts interactively for an absent version, so gate on `xcodes installed`
# to stay non-interactive under `tart exec`.
if tart exec "$VM_NAME" xcodes installed "$xcode_version" >/dev/null 2>&1; then
  log "Selecting Xcode $xcode_version in the guest…"
  tart exec "$VM_NAME" sudo xcodes select "$xcode_version" ||
    warn "could not select Xcode $xcode_version despite it being installed."
else
  effective="$(tart exec "$VM_NAME" sh -lc 'xcodebuild -version 2>/dev/null | head -n1 | cut -d" " -f2' 2>/dev/null || true)"
  warn "base image does not ship Xcode $xcode_version (pin from $TRIPLE_FILE); keeping the image's Xcode ${effective:-unknown}."
  warn "bump ios-triple.json, or pass --image with a tag that carries $xcode_version, if the runner must match the pin."
fi
tart exec "$VM_NAME" sudo xcodebuild -license accept >/dev/null 2>&1 || true
tart exec "$VM_NAME" sudo xcodebuild -runFirstLaunch >/dev/null 2>&1 || true
tart exec "$VM_NAME" sh -lc 'xcodebuild -version' ||
  die "xcodebuild not usable in '$VM_NAME'; the base image may not contain Xcode."

log "Shutting down '$VM_NAME'…"
tart stop "$VM_NAME" >/dev/null 2>&1 || true
wait "$RUN_PID" 2>/dev/null || true
RUN_PID=""

printf '%s\n' "$want_marker" >"$marker"
log "Golden runner VM '$VM_NAME' is ready ($want_marker). Select it in Tartelet's Virtual Machine pane."
