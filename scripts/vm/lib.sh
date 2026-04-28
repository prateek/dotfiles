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
