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

expect_timezone() {
  local localtime_path="${DOTFILES_POSTFLIGHT_LOCALTIME_PATH:-/etc/localtime}"
  local target

  target="$(readlink "$localtime_path" 2>/dev/null || true)"
  if [[ "$target" == */America/New_York ]]; then
    emit_result PASS timezone "$target"
  else
    emit_result FAIL timezone "target='$target'"
  fi
}

expect_spotlight_root() {
  local output

  output="$(mdutil -s / 2>&1 || true)"
  if [[ "$output" == *"Indexing enabled"* ]]; then
    emit_result PASS spotlight_root "Indexing enabled"
  else
    output="${output//$'\n'/ }"
    emit_result FAIL spotlight_root "$output"
  fi
}

expect_timezone
expect_default key_repeat NSGlobalDomain KeyRepeat 1
expect_default initial_key_repeat NSGlobalDomain InitialKeyRepeat 12
expect_default show_all_extensions NSGlobalDomain AppleShowAllExtensions 1
expect_default finder_show_hidden com.apple.finder AppleShowAllFiles 1
expect_default finder_show_pathbar com.apple.finder ShowPathbar 1
expect_default dock_autohide com.apple.dock autohide 1
expect_spotlight_root

printf 'SUMMARY|macos|passed=%d|failed=%d\n' "$passes" "$failures"

[ "$failures" -eq 0 ]
