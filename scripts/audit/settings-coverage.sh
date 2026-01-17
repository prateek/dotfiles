#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BREWFILE="${BREWFILE:-$REPO_ROOT/Brewfile}"

if [ ! -f "$BREWFILE" ]; then
  echo "Brewfile not found: $BREWFILE" >&2
  exit 1
fi

extract_casks() {
  sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE"
}

tracked_paths_for() {
  # Print a short, pipe-separated list of repo paths for tracked config.
  case "$1" in
    alfred)
      echo "osx-apps/alfred/Alfred.alfredpreferences | osx-apps/defaults/com.runningwithcrayons.Alfred-Preferences.plist | scripts/macos/apply.sh"
      ;;
    bettertouchtool)
      echo "osx-apps/bettertouchtool/ | osx-apps/defaults/com.hegenberg.BetterTouchTool.plist | osx-apps/defaults/com.hegenberg.bettertouchtool-setapp.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    moom)
      echo "osx-apps/Moom.plist | scripts/macos/apply.sh"
      ;;
    leader-key)
      echo "osx-apps/leader-key/config.json | osx-apps/defaults/com.brnbw.Leader-Key.plist | scripts/macos/apply.sh"
      ;;
    karabiner-elements)
      echo ".config/karabiner/karabiner.json | scripts/macos/apply.sh"
      ;;
    ghostty)
      echo "osx-apps/ghostty/config | scripts/macos/apply.sh"
      ;;
    iterm2)
      echo "osx-apps/iterm2/ | scripts/macos/apply.sh"
      ;;
    orbstack)
      echo "osx-apps/orbstack/config/docker.json | osx-apps/orbstack/vmconfig.json | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    google-chrome)
      echo "osx-apps/chrome/policies/com.google.Chrome.plist | scripts/macos/apply.sh"
      ;;
    raycast)
      echo "osx-apps/defaults/com.raycast.macos.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    setapp)
      echo "osx-apps/defaults/com.setapp.DesktopClient.plist | osx-apps/defaults/com.setapp.DesktopClient.SetappLauncher.plist | osx-apps/defaults/com.setapp.defaults.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    tailscale-app)
      echo "osx-apps/defaults/io.tailscale.ipn.macsys.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    voiceink)
      echo "osx-apps/defaults/com.prakashjoshipax.VoiceInk.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    1password)
      echo "osx-apps/defaults/com.1password.1password.plist | osx-apps/defaults/com.1password.safari.plist | scripts/macos/capture.sh | scripts/macos/apply.sh"
      ;;
    visual-studio-code)
      echo "osx-apps/vscode/settings.json | osx-apps/vscode/keybindings.json | osx-apps/vscode/snippets/ | scripts/macos/apply.sh"
      ;;
    *)
      echo ""
      ;;
  esac
}

artifact_paths_for() {
  # Repo paths that must exist for the config to actually be "captured".
  # (We don't count scripts here — only exported/copied config artifacts.)
  case "$1" in
    alfred)
      echo "osx-apps/alfred osx-apps/defaults/com.runningwithcrayons.Alfred-Preferences.plist"
      ;;
    bettertouchtool)
      echo "osx-apps/bettertouchtool osx-apps/defaults/com.hegenberg.BetterTouchTool.plist osx-apps/defaults/com.hegenberg.bettertouchtool-setapp.plist"
      ;;
    moom)
      echo "osx-apps/Moom.plist"
      ;;
    leader-key)
      echo "osx-apps/leader-key osx-apps/defaults/com.brnbw.Leader-Key.plist"
      ;;
    karabiner-elements)
      echo ".config/karabiner/karabiner.json"
      ;;
    ghostty)
      echo "osx-apps/ghostty/config"
      ;;
    iterm2)
      echo "osx-apps/iterm2/DynamicProfiles/dotfiles.json osx-apps/iterm2/colors/Solarized-Dark-Patched.itermcolors osx-apps/iterm2/backgrounds/solarized-grain.png osx-apps/defaults/com.googlecode.iterm2.plist"
      ;;
    orbstack)
      echo "osx-apps/orbstack/config/docker.json osx-apps/orbstack/vmconfig.json"
      ;;
    google-chrome)
      echo "osx-apps/chrome/policies/com.google.Chrome.plist"
      ;;
    raycast)
      echo "osx-apps/defaults/com.raycast.macos.plist"
      ;;
    setapp)
      echo "osx-apps/defaults/com.setapp.DesktopClient.plist osx-apps/defaults/com.setapp.DesktopClient.SetappLauncher.plist osx-apps/defaults/com.setapp.defaults.plist"
      ;;
    tailscale-app)
      echo "osx-apps/defaults/io.tailscale.ipn.macsys.plist"
      ;;
    voiceink)
      echo "osx-apps/defaults/com.prakashjoshipax.VoiceInk.plist"
      ;;
    1password)
      echo "osx-apps/defaults/com.1password.1password.plist osx-apps/defaults/com.1password.safari.plist"
      ;;
    visual-studio-code)
      echo "osx-apps/vscode/settings.json osx-apps/vscode/keybindings.json osx-apps/vscode/snippets"
      ;;
    *)
      echo ""
      ;;
  esac
}

is_captured() {
  local cask="$1"
  local any=0

  artifacts="$(artifact_paths_for "$cask")"
  [ -n "$artifacts" ] || { echo "no"; return; }

  for rel in $artifacts; do
    path="$REPO_ROOT/$rel"
    if [ -f "$path" ]; then
      any=1
      break
    fi
    if [ -d "$path" ] && [ -n "$(ls -A "$path" 2>/dev/null || true)" ]; then
      any=1
      break
    fi
  done

  if [ "$any" -eq 1 ]; then
    echo "yes"
  else
    echo "no"
  fi
}

echo "# Settings coverage (tracked in this repo)"
echo "# Brewfile: $BREWFILE"
echo

targets=()
if [ "$#" -gt 0 ]; then
  targets=("$@")
else
  mapfile -t targets < <(extract_casks)
fi

printf "cask\ttracked\tcaptured\twhere\n"
for cask in "${targets[@]}"; do
  where="$(tracked_paths_for "$cask")"
  if [ -n "$where" ]; then
    printf "%s\tyes\t%s\t%s\n" "$cask" "$(is_captured "$cask")" "$where"
  else
    printf "%s\tno\tno\t-\n" "$cask"
  fi
done | LC_ALL=C sort -t $'\t' -k2,2r -k1,1

echo
echo "# Notes"
echo "# - 'tracked=yes' means this repo has an apply step for it."
echo "# - 'captured=yes' means the config artifact(s) exist in this repo right now."
echo "# - Many apps are better synced via their own account/cloud (Raycast/Setapp/1Password/etc)."
