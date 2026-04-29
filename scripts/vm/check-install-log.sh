#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/vm/check-install-log.sh <log-file>

Scans an install log for macOS command failures that can be hidden by older
bootstrap scripts.
USAGE
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

log_file="$1"
if [ ! -f "$log_file" ]; then
  echo "install log not found: $log_file" >&2
  exit 2
fi

failed=0

check_fixed() {
  local label="$1"
  local needle="$2"
  local matches

  matches="$(LC_ALL=C grep -nF "$needle" "$log_file" || true)"
  if [ -n "$matches" ]; then
    failed=1
    printf 'install-log-failure: %s\n' "$label" >&2
    printf '%s\n' "$matches" >&2
  fi
}

check_regex() {
  local label="$1"
  local pattern="$2"
  local matches

  matches="$(LC_ALL=C grep -nE "$pattern" "$log_file" || true)"
  if [ -n "$matches" ]; then
    failed=1
    printf 'install-log-failure: %s\n' "$label" >&2
    printf '%s\n' "$matches" >&2
  fi
}

check_fixed "removed LaunchServices flag" "# The -kill option has been removed"
check_fixed "sealed system write" "Read-only file system"
check_fixed "unsupported Spotlight defaults write" "Could not write domain /.Spotlight-V100/VolumeConfiguration"
check_fixed "missing clean-VM Dock database path" "Library/Application Support/Dock: No such file or directory"
check_regex "dynamic loader failure" 'dyld(\[[0-9]+\])?: Library not loaded:'

if [ "$failed" -ne 0 ]; then
  echo "install log contains macOS command failures" >&2
  exit 1
fi

echo "install log scan passed"
