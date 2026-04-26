#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "vm-postflight-macos: $*"
  exit 1
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

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"
SCRIPT="$DOTFILES_ROOT/scripts/vm/postflight-macos.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin" "$tmp_root/zoneinfo/America"
ln -s "$tmp_root/zoneinfo/America/New_York" "$tmp_root/localtime"

cat >"$stub_bin/defaults" <<'EOF'
#!/bin/sh
set -eu

case "$*" in
  "read -g KeyRepeat")
    printf '1\n'
    ;;
  "read -g InitialKeyRepeat")
    printf '12\n'
    ;;
  "read -g AppleShowAllExtensions")
    printf '1\n'
    ;;
  "read com.apple.finder AppleShowAllFiles")
    printf '%s\n' "${DOTFILES_TEST_FINDER_SHOW_HIDDEN:-1}"
    ;;
  "read com.apple.finder ShowPathbar")
    printf '1\n'
    ;;
  "read com.apple.dock autohide")
    printf '1\n'
    ;;
  *)
    printf 'unexpected defaults invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$stub_bin/defaults"

cat >"$stub_bin/mdutil" <<'EOF'
#!/bin/sh
set -eu
printf '/:\n\tIndexing enabled. \n'
EOF
chmod +x "$stub_bin/mdutil"

assert_rc 0 env PATH="$stub_bin:/usr/bin:/bin" DOTFILES_POSTFLIGHT_LOCALTIME_PATH="$tmp_root/localtime" bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|PASS|timezone|"
assert_contains "$REPLY" "RESULT|macos|PASS|spotlight_root|"
assert_contains "$REPLY" "SUMMARY|macos|passed=8|failed=0"

assert_rc 1 env PATH="$stub_bin:/usr/bin:/bin" DOTFILES_POSTFLIGHT_LOCALTIME_PATH="$tmp_root/localtime" DOTFILES_TEST_FINDER_SHOW_HIDDEN=0 bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|FAIL|finder_show_hidden|"
assert_contains "$REPLY" "SUMMARY|macos|passed=7|failed=1"

print -- "OK vm-postflight-macos"
