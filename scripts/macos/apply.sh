#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/macos/apply.sh: macOS only; skipping."
  exit 0
fi

echo "Applying macOS settings…"

if [ -x "$REPO_ROOT/macos" ] && [ "${SKIP_MACOS_DEFAULTS:-0}" != "1" ]; then
  "$REPO_ROOT/macos"
fi

# Text replacements (System Settings → Keyboard → Text replacements)
TEXT_REPLACEMENTS_PLIST="$REPO_ROOT/osx-apps/macos/text-replacements.plist"
if [ -f "$TEXT_REPLACEMENTS_PLIST" ]; then
  GLOBAL_PREFS="$HOME/Library/Preferences/.GlobalPreferences.plist"
  mkdir -p "$(dirname "$GLOBAL_PREFS")"
  if [ ! -f "$GLOBAL_PREFS" ]; then
    plutil -create binary1 "$GLOBAL_PREFS" >/dev/null 2>&1 || true
  fi

  xml_value="$(cat "$TEXT_REPLACEMENTS_PLIST")"
  if ! plutil -replace NSUserDictionaryReplacementItems -xml "$xml_value" "$GLOBAL_PREFS" >/dev/null 2>&1; then
    plutil -insert NSUserDictionaryReplacementItems -xml "$xml_value" "$GLOBAL_PREFS" >/dev/null 2>&1 || true
  fi

  killall cfprefsd >/dev/null 2>&1 || true
fi

GUI_APPS_SCRIPT="$REPO_ROOT/scripts/macos/gui-apps.sh"
GUI_APPS_MANIFEST="${DOTFILES_GUI_APPS_MANIFEST:-$REPO_ROOT/osx-apps/gui-apps.yaml}"
if [ -x "$GUI_APPS_SCRIPT" ] && [ -f "$GUI_APPS_MANIFEST" ]; then
  "$GUI_APPS_SCRIPT" apply --manifest "$GUI_APPS_MANIFEST" --dry-run=false
fi

echo "Done."
