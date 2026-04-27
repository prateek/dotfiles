#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "vm-install-log-scan: $*"
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
SCRIPT="$DOTFILES_ROOT/scripts/vm/check-install-log.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

clean_log="$tmp_root/clean.log"
cat >"$clean_log" <<'EOF'
Applying macOS settings + app configs...
Bootstrap complete.
SUMMARY|verify|passed=59|failed=0|info=1
EOF

assert_rc 0 bash "$SCRIPT" "$clean_log"
assert_contains "$REPLY" "install log scan passed"

bad_log="$tmp_root/bad.log"
cat >"$bad_log" <<'EOF'
# The -kill option has been removed because it was dangerous and no longer useful.
chmod: Unable to change file mode on /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search: Read-only file system
2026-04-26 17:19:21.744 defaults[815:5785] Could not write domain /.Spotlight-V100/VolumeConfiguration; exiting
find: /Users/admin/Library/Application Support/Dock: No such file or directory
EOF

assert_rc 1 bash "$SCRIPT" "$bad_log"
assert_contains "$REPLY" "removed LaunchServices flag"
assert_contains "$REPLY" "sealed system write"
assert_contains "$REPLY" "unsupported Spotlight defaults write"
assert_contains "$REPLY" "missing clean-VM Dock database path"

print -- "OK vm-install-log-scan"
