# shellcheck shell=bash
#
# Shared helpers for VM driver scripts. Source from a wrapper that has set
# REPO_ROOT and may have set LOG_FILE / VM_NAME.
#
# Image / CPU / memory defaults are intentionally per-script: callers can
# work standalone, and the Makefile is authoritative when invoked via `make`.

log() {
  if [ -n "${LOG_FILE:-}" ]; then
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
  else
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  fi
}

warn() {
  log "WARNING: $*"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    usage
    die "missing value for $flag"
  fi
}

require_integer_at_least() {
  local flag="$1"
  local value="$2"
  local min="$3"
  local unit="${4:-}"

  local type_description="positive integer"
  local min_description="$min"
  if [ -n "$unit" ]; then
    type_description="$type_description in $unit"
    min_description="$min_description $unit"
  fi

  case "$value" in
    ''|*[!0-9]*)
      die "$flag must be a $type_description (got: $value)"
      ;;
  esac

  if [ "$value" -lt "$min" ]; then
    die "$flag must be >= $min_description (got: $value)"
  fi
}

# Reads $VM_NAME from the caller's scope.
vm_exists() {
  tart list --quiet --source local 2>/dev/null | grep -qx "$VM_NAME"
}

# True when the effective TART_HOME resolves onto a different volume than the
# boot disk (i.e. the external SSD is actually mounted). Walks up to the nearest
# existing ancestor so an as-yet-uncreated TART_HOME still reports the device of
# the volume it would be created on. Unset TART_HOME falls back to ~/.tart, which
# is on the boot volume, so this returns false. Keep in sync with the mount check
# in home/dot_config/zsh/dot_zshenv.tmpl.
tart_home_on_external_volume() {
  local probe="${TART_HOME:-$HOME/.tart}"
  while [ ! -e "$probe" ] && [ "$probe" != "/" ]; do
    probe="$(dirname "$probe")"
  done
  [ "$(stat -f %d "$probe" 2>/dev/null)" != "$(stat -f %d / 2>/dev/null)" ]
}

# Abort guard for the multi-GB lanes: refuse to pull images or create VM disks
# when TART_HOME would land on the boot disk. Set DOTFILES_TART_ALLOW_BOOT_DISK=1
# to override (CI plumbing tests, or a deliberate boot-disk run). Prints guidance
# on stderr and returns nonzero so the caller can die with its own formatting.
check_tart_home_external() {
  [ "${DOTFILES_TART_ALLOW_BOOT_DISK:-0}" = "1" ] && return 0
  if ! tart_home_on_external_volume; then
    printf 'tart storage would land on the boot disk (TART_HOME=%s).\n' "${TART_HOME:-unset}" >&2
    printf 'Mount the external SSD, or set DOTFILES_TART_ALLOW_BOOT_DISK=1 to override.\n' >&2
    return 1
  fi
  return 0
}
