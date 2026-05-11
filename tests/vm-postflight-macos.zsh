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
mkdir -p "$stub_bin"

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
  # Per-app plist assertions (one key/app for the 11 managed plists).
  # Each returns the value the production script's expect_plist_for asserts
  # for that key. Add a new case here when adding a new expect_plist_for line.
  "read com.jordanbaird.Ice HideApplicationMenus")           printf '1\n' ;;
  "read com.jordanbaird.Ice RehideInterval")                 printf '15\n' ;;
  "read com.prakashjoshipax.VoiceInk CurrentTranscriptionModel") printf 'parakeet-tdt-0.6b-v3\n' ;;
  "read com.prakashjoshipax.VoiceInk IsMenuBarOnly")         printf '1\n' ;;
  "read io.tailscale.ipn.macsys HideDockIcon")               printf '1\n' ;;
  "read io.tailscale.ipn.macsys TailscaleStartOnLogin")      printf '1\n' ;;
  "read com.manytricks.Moom Application Mode")               printf '2\n' ;;
  "read dev.kdrag0n.MacVirt global_showMenubarExtra")        printf '1\n' ;;
  "read com.cmuxterm.app appearanceMode")                    printf 'system\n' ;;
  "read com.hegenberg.BetterTouchTool BTTDisabledLegacyUI")  printf '1\n' ;;
  "read com.raycast.macos navigationCommandStyleIdentifierKey") printf 'vim\n' ;;
  "read com.setapp.DesktopClient EnableLauncher")            printf '0\n' ;;
  "read net.elasticthreads.nv DefaultEEIdentifier")          printf 'com.microsoft.VSCode\n' ;;
  "read pro.betterdisplay.BetterDisplay SUAutomaticallyUpdate") printf '1\n' ;;
  *)
    printf 'unexpected defaults invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$stub_bin/defaults"

# Timezone (systemsetup) and Spotlight (mdutil) checks were dropped from
# postflight along with the corresponding management in
# run_onchange_after_30-macos-defaults.sh.tmpl. Re-add stubs + assertions
# here when the management is re-enabled.

# Stub chezmoi to return empty status (no drift).
cat >"$stub_bin/chezmoi" <<'EOF'
#!/bin/sh
set -eu
case "$*" in
  *status*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$stub_bin/chezmoi"

# Set XDG_STATE_HOME to a clean tmp dir so the hook-state-file check passes.
state_root="$tmp_root/state"
mkdir -p "$state_root"

assert_rc 0 env PATH="$stub_bin:/usr/bin:/bin" XDG_STATE_HOME="$state_root" bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|PASS|key_repeat|"
assert_contains "$REPLY" "RESULT|macos|PASS|finder_show_hidden|"
assert_contains "$REPLY" "RESULT|macos|PASS|chezmoi_status|empty"
assert_contains "$REPLY" "RESULT|macos|PASS|hook_state|absent"
assert_contains "$REPLY" "SUMMARY|macos|passed=22|failed=0"
assert_contains "$REPLY" "RESULT|macos|PASS|ice_hide_app_menus|"
assert_contains "$REPLY" "RESULT|macos|PASS|voiceink_model|"
assert_contains "$REPLY" "RESULT|macos|PASS|tailscale_hide_dock|"

# Drift case: finder_show_hidden mismatch.
assert_rc 1 env PATH="$stub_bin:/usr/bin:/bin" XDG_STATE_HOME="$state_root" DOTFILES_TEST_FINDER_SHOW_HIDDEN=0 bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|FAIL|finder_show_hidden|"
assert_contains "$REPLY" "SUMMARY|macos|passed=21|failed=1"

# Hook state leftover case: pre-create the state file, expect FAIL.
mkdir -p "$state_root/dotfiles"
echo "com.example.foo" > "$state_root/dotfiles/plist-pending.txt"
assert_rc 1 env PATH="$stub_bin:/usr/bin:/bin" XDG_STATE_HOME="$state_root" bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|FAIL|hook_state|leftover:"
rm -rf "$state_root/dotfiles"

# Chezmoi status non-empty (drift) case.
cat >"$stub_bin/chezmoi" <<'EOF'
#!/bin/sh
set -eu
case "$*" in
  *status*)
    printf ' M /Users/test/.zshrc\n'
    ;;
esac
exit 0
EOF
chmod +x "$stub_bin/chezmoi"
assert_rc 1 env PATH="$stub_bin:/usr/bin:/bin" XDG_STATE_HOME="$state_root" bash "$SCRIPT"
assert_contains "$REPLY" "RESULT|macos|FAIL|chezmoi_status| M /Users/test/.zshrc"

print -- "OK vm-postflight-macos"
