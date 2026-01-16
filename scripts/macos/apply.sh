#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/macos/apply.sh: macOS only; skipping."
  exit 0
fi

timestamp() { date +%s; }

backup_if_exists() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    mv "$path" "${path}.backup-$(timestamp)"
  fi
}

ensure_symlink() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$(readlink "$dest" 2>/dev/null || true)" = "$src" ]; then
      return 0
    fi
    backup_if_exists "$dest"
  fi
  ln -snf "$src" "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_if_exists "$dest"
  fi
  cp "$src" "$dest"
}

echo "Applying macOS settings + app configs…"

if [ -x "$REPO_ROOT/macos" ] && [ "${SKIP_MACOS_DEFAULTS:-0}" != "1" ]; then
  "$REPO_ROOT/macos"
fi

# App preferences via `defaults` exports (osx-apps/defaults/<domain>.plist)
DEFAULTS_DIR="$REPO_ROOT/osx-apps/defaults"
if [ -d "$DEFAULTS_DIR" ]; then
  for plist in "$DEFAULTS_DIR"/*.plist; do
    [ -e "$plist" ] || continue
    domain="$(basename "$plist" .plist)"
    defaults import "$domain" "$plist" >/dev/null 2>&1 || true
  done
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

# BetterTouchTool config (portable settings DB; license is intentionally not tracked)
BTT_REPO_DIR="$REPO_ROOT/osx-apps/bettertouchtool"
if [ -d "$BTT_REPO_DIR" ]; then
  killall BetterTouchTool >/dev/null 2>&1 || true

  BTT_DEST_DIR="$HOME/Library/Application Support/BetterTouchTool"
  mkdir -p "$BTT_DEST_DIR"
  for src in "$BTT_REPO_DIR"/*; do
    [ -e "$src" ] || continue
    base="$(basename "$src")"
    case "$base" in
      btt_data_store.version_*|btt_user_variables.plist)
        copy_file "$src" "$BTT_DEST_DIR/$base"
        ;;
    esac
  done
fi

# Google Chrome policies (force-install extensions, etc.)
CHROME_POLICY_PLIST="$REPO_ROOT/osx-apps/chrome/policies/com.google.Chrome.plist"
if [ -f "$CHROME_POLICY_PLIST" ]; then
  sudo mkdir -p "/Library/Managed Preferences"
  sudo install -m 0644 "$CHROME_POLICY_PLIST" "/Library/Managed Preferences/com.google.Chrome.plist"
  killall "Google Chrome" >/dev/null 2>&1 || true
fi

# OrbStack config (keep it minimal; OrbStack will manage VM/data separately).
if [ -f "$REPO_ROOT/osx-apps/orbstack/config/docker.json" ]; then
  copy_file "$REPO_ROOT/osx-apps/orbstack/config/docker.json" "$HOME/.orbstack/config/docker.json"
fi
if [ -f "$REPO_ROOT/osx-apps/orbstack/vmconfig.json" ]; then
  copy_file "$REPO_ROOT/osx-apps/orbstack/vmconfig.json" "$HOME/.orbstack/vmconfig.json"
fi

# VS Code + Cursor settings
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
for user_dir in "$VSCODE_USER_DIR" "$CURSOR_USER_DIR"; do
  ensure_symlink "$REPO_ROOT/osx-apps/vscode/settings.json" "$user_dir/settings.json"
  ensure_symlink "$REPO_ROOT/osx-apps/vscode/keybindings.json" "$user_dir/keybindings.json"
  ensure_symlink "$REPO_ROOT/osx-apps/vscode/snippets" "$user_dir/snippets"
done

# Alfred preferences sync folder (expects repo-managed prefs at osx-apps/alfred)
if [ -d "$REPO_ROOT/osx-apps/alfred" ]; then
  defaults write com.runningwithcrayons.Alfred-Preferences syncfolder -string "$REPO_ROOT/osx-apps/alfred" || true
  killall Alfred >/dev/null 2>&1 || true
fi

# Moom preferences
if [ -f "$REPO_ROOT/osx-apps/Moom.plist" ]; then
  defaults import com.manytricks.Moom "$REPO_ROOT/osx-apps/Moom.plist" >/dev/null 2>&1 || true
  killall Moom >/dev/null 2>&1 || true
fi

# Leader Key config (expects repo-managed config at osx-apps/leader-key/config.json)
if [ -d "$REPO_ROOT/osx-apps/leader-key" ]; then
  defaults write com.brnbw.Leader-Key configDir -string "$REPO_ROOT/osx-apps/leader-key" >/dev/null 2>&1 || true
  killall "Leader Key" >/dev/null 2>&1 || true
fi

# Ghostty config (expects repo-managed config at osx-apps/ghostty/config)
if [ -f "$REPO_ROOT/osx-apps/ghostty/config" ]; then
  ensure_symlink \
    "$REPO_ROOT/osx-apps/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  killall Ghostty >/dev/null 2>&1 || true
fi

# iTerm2 Dynamic Profiles + Scripts (expects repo-managed config at osx-apps/iterm2)
ITERM2_REPO_DIR="$REPO_ROOT/osx-apps/iterm2"
if [ -d "$ITERM2_REPO_DIR/DynamicProfiles" ]; then
  ITERM2_DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  if [ -L "$ITERM2_DYNAMIC_PROFILES_DIR" ] || { [ -e "$ITERM2_DYNAMIC_PROFILES_DIR" ] && [ ! -d "$ITERM2_DYNAMIC_PROFILES_DIR" ]; }; then
    backup_if_exists "$ITERM2_DYNAMIC_PROFILES_DIR"
  fi

  mkdir -p "$ITERM2_DYNAMIC_PROFILES_DIR"
  for src in "$ITERM2_REPO_DIR/DynamicProfiles"/*; do
    [ -e "$src" ] || continue
    cp -f "$src" "$ITERM2_DYNAMIC_PROFILES_DIR/$(basename "$src")"
  done
fi
if [ -d "$ITERM2_REPO_DIR/Scripts" ]; then
  ensure_symlink \
    "$ITERM2_REPO_DIR/Scripts" \
    "$HOME/Library/Application Support/iTerm2/Scripts"
fi

# Set the default profile to the first profile in the dotfiles Dynamic Profile.
# (This avoids hardcoding GUIDs in multiple places.)
DEFAULT_ITERM2_PROFILE_JSON="$ITERM2_REPO_DIR/DynamicProfiles/dotfiles.json"
if [ -f "$DEFAULT_ITERM2_PROFILE_JSON" ] && command -v python3 >/dev/null 2>&1; then
  default_guid="$(
    python3 - "$DEFAULT_ITERM2_PROFILE_JSON" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    sys.exit(0)

profiles = data.get("Profiles")
if not isinstance(profiles, list) or not profiles:
    sys.exit(0)

guid = profiles[0].get("Guid")
if isinstance(guid, str) and guid:
    print(guid)
PY
  )"

  if [ -n "${default_guid:-}" ]; then
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$default_guid" >/dev/null 2>&1 || true
    defaults write com.googlecode.iterm2 "Default Browser Profile Guid" -string "$default_guid" >/dev/null 2>&1 || true
    killall iTerm2 >/dev/null 2>&1 || true
  fi
fi

# Karabiner-Elements (link only karabiner.json to avoid repo churn from automatic_backups)
if [ -f "$REPO_ROOT/.config/karabiner/karabiner.json" ]; then
  mkdir -p "$HOME/.config/karabiner"
  ensure_symlink "$REPO_ROOT/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
  /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --reloadxml >/dev/null 2>&1 || true
fi

echo "Done."
