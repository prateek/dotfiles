#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPTURE_ROOT="${DOTFILES_CAPTURE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/captures/app-settings}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/macos/capture.sh: macOS only; skipping."
  exit 0
fi

echo "Capturing macOS/app settings into ${CAPTURE_ROOT}..."

capture_mackup_candidates() {
  if ! command -v chezmoi >/dev/null 2>&1 || ! command -v mackup >/dev/null 2>&1; then
    echo "Skipping Mackup candidate capture; chezmoi and mackup are both required."
    return
  fi

  local mackup_source="$CAPTURE_ROOT/mackup-source"
  local mackup_cache="$CAPTURE_ROOT/mackup-cache"
  local mackup_state="$CAPTURE_ROOT/mackup-state.boltdb"
  local apps=(
    aerospace
    bartender
    bettertouchtool
    caffeine
    codex
    cursor
    fastscripts
    ghostty
    hammerspoon
    iterm2
    moom
    nvalt
    rocket
    spotify
    vscode
    zed
  )

  rm -rf "$mackup_source" "$mackup_cache"
  mkdir -p "$mackup_source" "$mackup_cache"

  chezmoi \
    --source "$mackup_source" \
    --cache "$mackup_cache" \
    --persistent-state "$mackup_state" \
    --no-tty \
    --force \
    mackup add \
    --secrets ignore \
    "${apps[@]}" >/dev/null
}

delete_plist_key() {
  local plist="$1"
  local key="$2"
  local plist_key="${key//:/\\:}"
  /usr/libexec/PlistBuddy -c "Delete :$plist_key" "$plist" >/dev/null 2>&1 || true
}

sanitize_defaults_export() {
  local domain="$1"
  local plist="$2"

  case "$domain" in
    com.brnbw.Leader-Key|com.runningwithcrayons.Alfred-Preferences)
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
    pro.betterdisplay.BetterDisplay)
      /usr/libexec/PlistBuddy -c "Print" "$plist" 2>/dev/null \
        | awk -F= '/Paddle|storedIdentifiers|currentColorProfileURL|factoryColorProfileURL/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }' \
        | while IFS= read -r key; do
            delete_plist_key "$plist" "$key"
          done
      ;;
    com.raycast.macos)
      delete_plist_key "$plist" "raycastAnonymousId"
      delete_plist_key "$plist" "posthog.anonymousId"
      delete_plist_key "$plist" "posthog.distinctId"
      ;;
    com.setapp.DesktopClient)
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

mkdir -p "$CAPTURE_ROOT/defaults"
capture_mackup_candidates

for domain in \
  com.brnbw.Leader-Key \
  bobko.aerospace \
  com.cmuxterm.app \
  com.electron.ollama \
  com.helftone.monodraw \
  com.intelliscapesolutions.caffeine \
  com.jordanbaird.Ice \
  com.openai.codex \
  com.rescuetime.RescueTime \
  com.soma-zone.LaunchControl \
  com.spotify.client \
  com.surteesstudios.Bartender \
  com.tinyspeck.slackmacgap \
  dev.zed.Zed \
  md.obsidian \
  net.matthewpalmer.Rocket \
  com.runningwithcrayons.Alfred-Preferences \
  com.hegenberg.BetterTouchTool \
  com.hegenberg.bettertouchtool-setapp \
  com.raycast.macos \
  com.prakashjoshipax.VoiceInk \
  io.tailscale.ipn.macsys \
  com.1password.1password \
  com.1password.safari \
  com.getcleanshot.app-setapp \
  pro.betterdisplay.BetterDisplay \
  com.setapp.DesktopClient \
  com.setapp.DesktopClient.SetappLauncher \
  com.setapp.defaults; do
  if defaults read "$domain" >/dev/null 2>&1; then
    defaults export "$domain" "$CAPTURE_ROOT/defaults/$domain.plist" >/dev/null 2>&1 || true
    plutil -convert xml1 "$CAPTURE_ROOT/defaults/$domain.plist" >/dev/null 2>&1 || true
    sanitize_defaults_export "$domain" "$CAPTURE_ROOT/defaults/$domain.plist"
  fi
done

if defaults read com.manytricks.Moom >/dev/null 2>&1; then
  defaults export com.manytricks.Moom "$CAPTURE_ROOT/Moom.plist" >/dev/null 2>&1 || true
  plutil -convert xml1 "$CAPTURE_ROOT/Moom.plist" >/dev/null 2>&1 || true
fi

if command -v code >/dev/null 2>&1; then
  code --list-extensions | LC_ALL=C sort >"$CAPTURE_ROOT/vscode-extensions.txt"
fi

if [ -f "$HOME/.orbstack/config/docker.json" ]; then
  mkdir -p "$CAPTURE_ROOT/orbstack/config"
  cp "$HOME/.orbstack/config/docker.json" "$CAPTURE_ROOT/orbstack/config/docker.json"
fi
if [ -f "$HOME/.orbstack/vmconfig.json" ]; then
  mkdir -p "$CAPTURE_ROOT/orbstack"
  cp "$HOME/.orbstack/vmconfig.json" "$CAPTURE_ROOT/orbstack/vmconfig.json"
fi

global_prefs="$HOME/Library/Preferences/.GlobalPreferences.plist"
if [ -f "$global_prefs" ]; then
  mkdir -p "$CAPTURE_ROOT/macos"
  plutil -extract NSUserDictionaryReplacementItems xml1 -o "$CAPTURE_ROOT/macos/text-replacements.plist" "$global_prefs" >/dev/null 2>&1 || true
fi

echo "Done."
