#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/macos/capture.sh: macOS only; skipping."
  exit 0
fi

echo "Capturing macOS/app settings into repo…"

delete_plist_key() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
}

sanitize_defaults_export() {
  local domain="$1"
  local plist="$2"

  case "$domain" in
    com.brnbw.Leader-Key|com.runningwithcrayons.Alfred-Preferences)
      # Remove file-dialog bookmarks (machine-specific blobs)
      delete_plist_key "$plist" "NSOSPLastRootDirectory"
      ;;
    io.tailscale.ipn.macsys)
      delete_plist_key "$plist" "com.tailscale.cached.currentProfile"
      delete_plist_key "$plist" "com.tailscale.cached.profiles"
      delete_plist_key "$plist" "com.tailscale.ipn.restartState"
      ;;
    com.getcleanshot.app-setapp)
      delete_plist_key "$plist" "allowURLSchemesAPI"
      delete_plist_key "$plist" "mediaHistory"
      ;;
    com.raycast.macos)
      delete_plist_key "$plist" "raycastAnonymousId"
      delete_plist_key "$plist" "posthog.anonymousId"
      delete_plist_key "$plist" "posthog.distinctId"
      ;;
    com.setapp.DesktopClient)
      # Remove account identifiers + device tokens before committing.
      delete_plist_key "$plist" "APNSDeviceTokenString"
      delete_plist_key "$plist" "CurrentUserAccount"
      delete_plist_key "$plist" "GoogleAnalyticsCID"
      delete_plist_key "$plist" "InAppID"
      delete_plist_key "$plist" "SatuID"
      delete_plist_key "$plist" "AFXDataHubUID"
      delete_plist_key "$plist" "known_customers"
      delete_plist_key "$plist" "known_environments"
      delete_plist_key "$plist" "suggested_account_names"
      ;;
    com.setapp.DesktopClient.SetappLauncher|com.setapp.defaults)
      delete_plist_key "$plist" "APNSDeviceTokenString"
      delete_plist_key "$plist" "CurrentUserAccount"
      ;;
  esac
}

# App preferences via `defaults` exports
DEFAULTS_DIR="$REPO_ROOT/osx-apps/defaults"
mkdir -p "$DEFAULTS_DIR"

# Export app preferences that are safe/portable (avoid secrets; sanitize where needed).
for domain in \
  com.brnbw.Leader-Key \
  com.runningwithcrayons.Alfred-Preferences \
  com.hegenberg.BetterTouchTool \
  com.hegenberg.bettertouchtool-setapp \
  com.raycast.macos \
  com.prakashjoshipax.VoiceInk \
  io.tailscale.ipn.macsys \
  com.1password.1password \
  com.1password.safari \
  com.getcleanshot.app-setapp \
  com.setapp.DesktopClient \
  com.setapp.DesktopClient.SetappLauncher \
  com.setapp.defaults; do
  if defaults read "$domain" >/dev/null 2>&1; then
    defaults export "$domain" "$DEFAULTS_DIR/$domain.plist" >/dev/null 2>&1 || true
    plutil -convert xml1 "$DEFAULTS_DIR/$domain.plist" >/dev/null 2>&1 || true
    sanitize_defaults_export "$domain" "$DEFAULTS_DIR/$domain.plist"
  fi
done

# Karabiner-Elements
if [ -f "$HOME/.config/karabiner/karabiner.json" ]; then
  mkdir -p "$REPO_ROOT/.config/karabiner"
  cp "$HOME/.config/karabiner/karabiner.json" "$REPO_ROOT/.config/karabiner/karabiner.json"
fi

# Ghostty
GHOSTTY_CONFIG_SRC="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [ -f "$GHOSTTY_CONFIG_SRC" ]; then
  mkdir -p "$REPO_ROOT/osx-apps/ghostty"
  cp "$GHOSTTY_CONFIG_SRC" "$REPO_ROOT/osx-apps/ghostty/config"
fi

# Moom
if defaults read com.manytricks.Moom >/dev/null 2>&1; then
  defaults export com.manytricks.Moom "$REPO_ROOT/osx-apps/Moom.plist" >/dev/null 2>&1 || true
  plutil -convert xml1 "$REPO_ROOT/osx-apps/Moom.plist" >/dev/null 2>&1 || true
fi

# BetterTouchTool config (exclude license file; avoid copying backups/logs).
BTT_SRC="$HOME/Library/Application Support/BetterTouchTool"
if [ -d "$BTT_SRC" ]; then
  killall BetterTouchTool >/dev/null 2>&1 || true

  mkdir -p "$REPO_ROOT/osx-apps/bettertouchtool"
  rm -f "$REPO_ROOT/osx-apps/bettertouchtool"/btt_data_store.version_* 2>/dev/null || true
  rm -f "$REPO_ROOT/osx-apps/bettertouchtool"/btt_user_variables.plist 2>/dev/null || true

  store=""
  newest_mtime=0
  shopt -s nullglob
  candidates=("$BTT_SRC"/btt_data_store.version_*_build_*)
  shopt -u nullglob
  for f in "${candidates[@]}"; do
    case "$f" in
      *-shm|*-wal) continue ;;
    esac
    mtime="$(stat -f %m "$f" 2>/dev/null || echo 0)"
    if [ "$mtime" -gt "$newest_mtime" ]; then
      newest_mtime="$mtime"
      store="$f"
    fi
  done
  if [ -n "$store" ]; then
    cp "$store" "$REPO_ROOT/osx-apps/bettertouchtool/$(basename "$store")"
    [ -f "${store}-shm" ] && cp "${store}-shm" "$REPO_ROOT/osx-apps/bettertouchtool/$(basename "${store}-shm")"
    [ -f "${store}-wal" ] && cp "${store}-wal" "$REPO_ROOT/osx-apps/bettertouchtool/$(basename "${store}-wal")"
  fi

  if [ -f "$BTT_SRC/btt_user_variables.plist" ]; then
    cp "$BTT_SRC/btt_user_variables.plist" "$REPO_ROOT/osx-apps/bettertouchtool/btt_user_variables.plist"
  fi
fi

# VS Code extensions (best-effort; requires `code` on PATH)
if command -v code >/dev/null 2>&1; then
  code --list-extensions | LC_ALL=C sort >"$REPO_ROOT/osx-apps/vscode/extensions.txt"
fi

# OrbStack config (keep it minimal; OrbStack will manage VM/data separately).
if [ -f "$HOME/.orbstack/config/docker.json" ]; then
  mkdir -p "$REPO_ROOT/osx-apps/orbstack/config"
  cp "$HOME/.orbstack/config/docker.json" "$REPO_ROOT/osx-apps/orbstack/config/docker.json"
fi
if [ -f "$HOME/.orbstack/vmconfig.json" ]; then
  mkdir -p "$REPO_ROOT/osx-apps/orbstack"
  cp "$HOME/.orbstack/vmconfig.json" "$REPO_ROOT/osx-apps/orbstack/vmconfig.json"
fi

# Text replacements (System Settings → Keyboard → Text replacements)
GLOBAL_PREFS="$HOME/Library/Preferences/.GlobalPreferences.plist"
if [ -f "$GLOBAL_PREFS" ]; then
  mkdir -p "$REPO_ROOT/osx-apps/macos"
  plutil -extract NSUserDictionaryReplacementItems xml1 -o "$REPO_ROOT/osx-apps/macos/text-replacements.plist" "$GLOBAL_PREFS" >/dev/null 2>&1 || true
fi

echo "Done."
