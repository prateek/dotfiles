#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "package-gated-configs: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

full_managed="$tmp_root/full-managed.txt"
core_managed="$tmp_root/core-managed.txt"
core_ignored="$tmp_root/core-ignored.txt"
minimal_ignored="$tmp_root/minimal-ignored.txt"
leader_key_json="$tmp_root/leader-key.json"
state_file="$tmp_root/chezmoi-state.boltdb"

chezmoi_isolated() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$state_file" \
    "$@"
}

chezmoi_isolated \
  --override-data '{"manage_zinit_external":false}' \
  managed --path-style relative >"$full_managed"

chezmoi_isolated \
  --override-data '{"manage_zinit_external":false,"install_profile":"core"}' \
  managed --path-style relative >"$core_managed"

chezmoi_isolated \
  --override-data '{"manage_zinit_external":false,"install_profile":"core"}' \
  ignored >"$core_ignored"

chezmoi_isolated \
  --override-data '{"manage_zinit_external":false,"install_profile":"minimal","packages":{"default_profile":"minimal","profiles":{"minimal":{"casks":[]}}}}' \
  ignored >"$minimal_ignored"

chezmoi_isolated \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Application Support/Leader Key/config.json.tmpl" \
  >"$leader_key_json"

expect_managed() {
  local target_path="$1"
  local file="$2"
  grep -Fx -- "$target_path" "$file" >/dev/null || die "expected managed path: $target_path"
}

expect_unmanaged() {
  local target_path="$1"
  local file="$2"
  if grep -Fx -- "$target_path" "$file" >/dev/null; then
    die "expected unmanaged path: $target_path"
  fi
}

expect_ignored() {
  local target_path="$1"
  grep -Fx -- "$target_path" "$core_ignored" >/dev/null || die "expected ignored path: $target_path"
}

expect_managed ".config/cmux/preferences.json" "$full_managed"
expect_managed ".config/ghostty" "$full_managed"
expect_managed ".hammerspoon" "$full_managed"
expect_managed "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$full_managed"
expect_managed "Library/Preferences/com.raycast.macos.plist" "$full_managed"
expect_managed ".config/raycast/scripts/temp-admin.sh" "$full_managed"
expect_managed ".config/raycast/extensions/orca-worktree/package.json" "$full_managed"
expect_managed "Library/Preferences/io.tailscale.ipn.macsys.plist" "$full_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$full_managed"
expect_managed "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$full_managed"
expect_managed ".config/zed" "$full_managed"
expect_managed "Library/Application Support/Leader Key/config.json" "$full_managed"
expect_managed "Library/Application Support/Code/User" "$full_managed"
expect_managed "Library/Colors/nvALT.clr" "$full_managed"
expect_managed "Library/Preferences/com.jordanbaird.Ice.plist" "$full_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$full_managed"
expect_managed "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$full_managed"
expect_managed "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$full_managed"
expect_managed "Library/Preferences/net.elasticthreads.nv.plist" "$full_managed"

expect_unmanaged ".config/cmux" "$core_managed"
expect_managed ".config/ghostty" "$core_managed"
expect_unmanaged ".hammerspoon" "$core_managed"
expect_managed "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$core_managed"
expect_managed "Library/Preferences/com.raycast.macos.plist" "$core_managed"
expect_managed ".config/raycast/scripts/temp-admin.sh" "$core_managed"
expect_managed ".config/raycast/extensions/orca-worktree/package.json" "$core_managed"
expect_managed "Library/Preferences/io.tailscale.ipn.macsys.plist" "$core_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$core_managed"
expect_unmanaged "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$core_managed"
expect_unmanaged ".config/zed" "$core_managed"
expect_managed "Library/Application Support/Leader Key/config.json" "$core_managed"
expect_managed "Library/Application Support/Code/User" "$core_managed"
expect_unmanaged "Library/Colors/nvALT.clr" "$core_managed"
expect_unmanaged "Library/Preferences/com.jordanbaird.Ice.plist" "$core_managed"
expect_unmanaged "Library/Preferences/com.cmuxterm.app.plist" "$core_managed"
expect_managed "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$core_managed"
expect_managed "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$core_managed"
expect_unmanaged "Library/Preferences/net.elasticthreads.nv.plist" "$core_managed"

expect_ignored ".config/zed"
expect_ignored ".config/cmux"
expect_ignored ".hammerspoon"
expect_ignored "Library/Colors/nvALT.clr"
expect_ignored "Library/Preferences/com.jordanbaird.Ice.plist"
expect_ignored "Library/Preferences/com.cmuxterm.app.plist"
expect_ignored "Library/Preferences/net.elasticthreads.nv.plist"
expect_ignored "Library/Preferences/pro.betterdisplay.BetterDisplay.plist"
grep -Fx -- "Library/Application Support/Leader Key/config.json" "$minimal_ignored" >/dev/null ||
  die "expected Leader Key to be ignored when profile has no leader-key cask"
grep -Fx -- ".config/ghostty" "$minimal_ignored" >/dev/null ||
  die "expected Ghostty to be ignored when profile has no ghostty cask"
grep -Fx -- "Library/Application Support/Code/User" "$minimal_ignored" >/dev/null ||
  die "expected VS Code to be ignored when profile has no visual-studio-code cask"
grep -Fx -- "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$minimal_ignored" >/dev/null ||
  die "expected OrbStack to be ignored when profile has no orbstack cask"
grep -Fx -- "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$minimal_ignored" >/dev/null ||
  die "expected VoiceInk to be ignored when profile has no voiceink cask"
grep -Fx -- "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$minimal_ignored" >/dev/null ||
  die "expected BetterTouchTool to be ignored when profile has no bettertouchtool cask"
grep -Fx -- "Library/Preferences/com.raycast.macos.plist" "$minimal_ignored" >/dev/null ||
  die "expected Raycast to be ignored when profile has no raycast cask"
grep -Fx -- ".config/raycast/scripts/temp-admin.sh" "$minimal_ignored" >/dev/null ||
  die "expected Raycast temp-admin script to be ignored when profile has no raycast cask"
grep -Fx -- ".config/raycast/extensions" "$minimal_ignored" >/dev/null ||
  die "expected Raycast extensions to be ignored when profile has no raycast cask"
grep -Fx -- "Library/Preferences/io.tailscale.ipn.macsys.plist" "$minimal_ignored" >/dev/null ||
  die "expected Tailscale to be ignored when profile has no tailscale-app cask"
grep -Fx -- "Library/Preferences/com.setapp.DesktopClient.plist" "$minimal_ignored" >/dev/null ||
  die "expected Setapp to be ignored when profile has no setapp cask"

python3 - "$leader_key_json" <<'PY'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["type"] == "group"
assert {item["key"] for item in config["actions"]} == {"t", "s", "v", "w", "b", "m"}
PY

print -- "OK package-gated-configs"
