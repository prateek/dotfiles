#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "tart-install-helper-contract: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "expected output not to contain: $needle"
}

assert_rc() {
  local expected="$1"
  shift

  local output rc
  set +e
  output="$("$@" 2>&1)"
  rc=$?
  set -e

  [[ "$rc" -eq "$expected" ]] || {
    print -u2 -- "$output"
    die "expected rc=$expected, got rc=$rc for: $*"
  }

  REPLY="$output"
}

DOTFILES_ROOT="${0:A:h:h}"
SCRIPT="$DOTFILES_ROOT/scripts/vm/test-install-tart.sh"

help_output="$(bash "$SCRIPT" --help)"
assert_contains "$help_output" "ghcr.io/cirruslabs/macos-tahoe-base:latest"
assert_contains "$help_output" "--lane <smoke|full>"
assert_contains "$help_output" "--cpu <count>"
assert_contains "$help_output" "--memory <mb>"
assert_contains "$help_output" "--homebrew-cache-dir <path>"
assert_contains "$help_output" "--no-homebrew-cache"
assert_contains "$help_output" "Local mode also"
assert_contains "$help_output" "captures guest zsh spans"
assert_contains "$help_output" "DOTFILES_TART_HOMEBREW_CACHE_DIR"
assert_not_contains "$help_output" "--profile"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --lane invalid
assert_contains "$REPLY" "--lane must be 'smoke' or 'full'"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --lane
assert_contains "$REPLY" "missing value for --lane"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --profile core
assert_contains "$REPLY" "Unknown arg: --profile"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --cpu 0
assert_contains "$REPLY" "--cpu must be >= 1"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --cpu
assert_contains "$REPLY" "missing value for --cpu"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --memory 1024
assert_contains "$REPLY" "--memory must be >= 2048 MB"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --vm-name
assert_contains "$REPLY" "missing value for --vm-name"

assert_rc 1 env PATH="/usr/bin:/bin" bash "$SCRIPT" --homebrew-cache-dir
assert_contains "$REPLY" "missing value for --homebrew-cache-dir"

print -- "OK tart-install-helper-contract"
