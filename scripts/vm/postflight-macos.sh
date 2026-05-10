#!/usr/bin/env bash
set -euo pipefail

passes=0
failures=0

emit_result() {
  local status="$1"
  local check_id="$2"
  local detail="$3"

  printf 'RESULT|macos|%s|%s|%s\n' "$status" "$check_id" "$detail"
  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
  esac
}

read_default() {
  local domain="$1"
  local key="$2"

  if [ "$domain" = "NSGlobalDomain" ]; then
    defaults read -g "$key" 2>/dev/null || true
  else
    defaults read "$domain" "$key" 2>/dev/null || true
  fi
}

normalize_bool() {
  case "$1" in
    1|true|TRUE|True|YES|Yes|yes)
      printf '1\n'
      ;;
    0|false|FALSE|False|NO|No|no)
      printf '0\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

expect_default() {
  local check_id="$1"
  local domain="$2"
  local key="$3"
  local want="$4"
  local got

  got="$(read_default "$domain" "$key")"
  got="$(normalize_bool "$got")"
  if [ "$got" = "$want" ]; then
    emit_result PASS "$check_id" "$domain $key=$got"
  else
    emit_result FAIL "$check_id" "got='$got' want='$want'"
  fi
}

# Timezone management was dropped along with macos.toml's
# [[system.macos.systemsetup]] block — set timezone manually if needed.
# Spotlight management is currently inactive (commented out in
# run_onchange_after_30-macos-defaults.sh.tmpl). Re-enable both checks
# here when their respective management is brought back.

expect_default key_repeat NSGlobalDomain KeyRepeat 1
expect_default initial_key_repeat NSGlobalDomain InitialKeyRepeat 12
expect_default show_all_extensions NSGlobalDomain AppleShowAllExtensions 1
expect_default finder_show_hidden com.apple.finder AppleShowAllFiles 1
expect_default finder_show_pathbar com.apple.finder ShowPathbar 1
expect_default dock_autohide com.apple.dock autohide 1


# ---- Plist refactor assertions --------------------------------------------

# chezmoi status must be empty after a successful apply — any non-empty
# output means there is undeclared drift (typically caused by a per-app
# plist that didn't apply or an apply script failure).
expect_chezmoi_status_empty() {
  local out
  if ! command -v chezmoi >/dev/null 2>&1; then
    emit_result FAIL chezmoi_status "chezmoi not on PATH"
    return
  fi
  # --exclude=scripts strips run_after_ + run_onchange_ entries that
  # chezmoi always reports as pending until they run again. We only care
  # about file-level drift in postflight.
  out="$(chezmoi --no-tty status --exclude=scripts 2>&1 || true)"
  if [ -z "$out" ]; then
    emit_result PASS chezmoi_status "empty (file targets)"
  else
    local first
    first="$(printf '%s\n' "$out" | head -1)"
    emit_result FAIL chezmoi_status "$first"
  fi
}

# Hook state file lives at ${XDG_STATE_HOME}/dotfiles/plist-pending.txt
# and must be removed by the post-apply hook on every apply.
expect_hook_state_clean() {
  local state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/plist-pending.txt"
  if [ -e "$state_file" ]; then
    emit_result FAIL hook_state "leftover: $state_file"
  else
    emit_result PASS hook_state "absent"
  fi
}

# expect_plist_for asserts a single representative key landed on disk for
# a managed plist app — proves the rendered fragment was actually merged
# into the live plist (chezmoi status alone only proves rendered output
# matches what's there, not that what's there contains the keys we care
# about). Booleans accepted as 1/true equivalence per macOS normalisation.
expect_plist_for() {
  local check_id="$1" domain="$2" key="$3" want="$4"
  local got match=0
  got="$(defaults read "$domain" "$key" 2>/dev/null)" || {
    emit_result FAIL "$check_id" "key not present ($domain $key)"
    return
  }
  [ "$got" = "$want" ] && match=1
  case "$want" in
    true)  [ "$got" = "1" ] && match=1 ;;
    false) [ "$got" = "0" ] && match=1 ;;
    1)     [ "$got" = "true" ]  && match=1 ;;
    0)     [ "$got" = "false" ] && match=1 ;;
  esac
  if [ $match -eq 1 ]; then
    emit_result PASS "$check_id" "$domain $key=$got"
  else
    emit_result FAIL "$check_id" "got='$got' want='$want'"
  fi
}

expect_chezmoi_status_empty
expect_hook_state_clean

# One asserted key per managed plist app — proves the shared engine
# wrote the configured value. Keys chosen for high signal (not arbitrary
# defaults) and stability (not animated state).
expect_plist_for ice_hide_app_menus       com.jordanbaird.Ice           HideApplicationMenus       1
expect_plist_for ice_rehide_interval      com.jordanbaird.Ice           RehideInterval             15
expect_plist_for voiceink_model           com.prakashjoshipax.VoiceInk  CurrentTranscriptionModel  parakeet-tdt-0.6b-v3
expect_plist_for voiceink_menubar_only    com.prakashjoshipax.VoiceInk  IsMenuBarOnly              1
expect_plist_for tailscale_hide_dock      io.tailscale.ipn.macsys       HideDockIcon               1
expect_plist_for tailscale_start_login    io.tailscale.ipn.macsys       TailscaleStartOnLogin      1
expect_plist_for moom_application_mode    com.manytricks.Moom           "Application Mode"         2
expect_plist_for orbstack_menubar_extra   dev.kdrag0n.MacVirt           global_showMenubarExtra    1
expect_plist_for cmux_appearance          com.cmuxterm.app              appearanceMode             system
expect_plist_for btt_disabled_legacy_ui   com.hegenberg.BetterTouchTool BTTDisabledLegacyUI        1
expect_plist_for raycast_nav_style        com.raycast.macos             navigationCommandStyleIdentifierKey vim
expect_plist_for setapp_no_launcher       com.setapp.DesktopClient      EnableLauncher             0
expect_plist_for nvalt_default_editor     net.elasticthreads.nv         DefaultEEIdentifier        com.microsoft.VSCode
expect_plist_for betterdisplay_su_auto    pro.betterdisplay.BetterDisplay SUAutomaticallyUpdate    1


printf 'SUMMARY|macos|passed=%d|failed=%d\n' "$passes" "$failures"

[ "$failures" -eq 0 ]
