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

personal_managed="$tmp_root/personal-managed.txt"
ci_managed="$tmp_root/ci-managed.txt"
ci_ignored="$tmp_root/ci-ignored.txt"
work_managed="$tmp_root/work-managed.txt"
work_ignored="$tmp_root/work-ignored.txt"
empty_ignored="$tmp_root/empty-ignored.txt"
leader_key_json="$tmp_root/leader-key.json"
state_file="$tmp_root/chezmoi-state.boltdb"

# package-cask-enabled.tmpl resolves package groups through the machines.toml
# resolver (features.tmpl), which reads .machine_type from data, pinned per
# render via --override-data. An empty --config isolates from this host's own
# chezmoi config so a local [data.machines_local] cannot skew the result.
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"
chezmoi_isolated() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$state_file" \
    "$@"
}

chezmoi_isolated \
  --override-data '{"machine_type":"personal"}' \
  managed --path-style relative >"$personal_managed"

chezmoi_isolated \
  --override-data '{"machine_type":"ci"}' \
  managed --path-style relative >"$ci_managed"

chezmoi_isolated \
  --override-data '{"machine_type":"ci"}' \
  ignored >"$ci_ignored"

chezmoi_isolated \
  --override-data '{"machine_type":"work"}' \
  managed --path-style relative >"$work_managed"

chezmoi_isolated \
  --override-data '{"machine_type":"work"}' \
  ignored >"$work_ignored"

# Empty group set ⇒ no casks enabled ⇒ every gated config ignored. Arrays in
# --override-data replace rather than merge, so the ci type layer's groups=[] wins.
chezmoi_isolated \
  --override-data '{"machine_type":"ci","machines":{"type":{"ci":{"groups":[]}}}}' \
  ignored >"$empty_ignored"

chezmoi_isolated \
  --override-data '{"machine_type":"personal"}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Application Support/Leader Key/config.json.tmpl" \
  >"$leader_key_json"

expect_managed() {
  local target_path="$1" file="$2"
  grep -Fx -- "$target_path" "$file" >/dev/null || die "expected managed path: $target_path (${file:t})"
}

expect_unmanaged() {
  local target_path="$1" file="$2"
  if grep -Fx -- "$target_path" "$file" >/dev/null; then
    die "expected unmanaged path: $target_path (${file:t})"
  fi
}

expect_ignored() {
  local target_path="$1" file="${2:-$ci_ignored}"
  grep -Fx -- "$target_path" "$file" >/dev/null || die "expected ignored path: $target_path (${file:t})"
}

# --- personal: everything managed (base + dev + dev-apple + personal-apps) ---
expect_managed ".config/cmux/preferences.json" "$personal_managed"
expect_managed ".config/ghostty" "$personal_managed"
expect_managed ".hammerspoon" "$personal_managed"
expect_managed "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$personal_managed"
expect_managed "Library/Preferences/com.raycast.macos.plist" "$personal_managed"
expect_managed ".config/raycast/scripts/temp-admin.sh" "$personal_managed"
expect_managed ".local/share/raycast-extensions/orca-worktree/package.json" "$personal_managed"
expect_managed "Library/Preferences/io.tailscale.ipn.macsys.plist" "$personal_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$personal_managed"
expect_managed "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$personal_managed"
expect_managed ".config/zed" "$personal_managed"
expect_managed "Library/Application Support/Leader Key/config.json" "$personal_managed"
expect_managed "Library/Application Support/Code/User" "$personal_managed"
expect_managed "Library/Colors/nvALT.clr" "$personal_managed"
expect_managed "Library/Preferences/com.jordanbaird.Ice.plist" "$personal_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$personal_managed"
expect_managed "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$personal_managed"
expect_managed "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$personal_managed"
expect_managed "Library/Preferences/net.elasticthreads.nv.plist" "$personal_managed"

# --- ci: base only. dev/dev-apple/personal-app configs unmanaged. ---
expect_unmanaged ".config/cmux" "$ci_managed"
expect_managed ".config/ghostty" "$ci_managed"
expect_unmanaged ".hammerspoon" "$ci_managed"
expect_managed "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$ci_managed"
expect_managed "Library/Preferences/com.raycast.macos.plist" "$ci_managed"
expect_managed ".config/raycast/scripts/temp-admin.sh" "$ci_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$ci_managed"
expect_managed "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$ci_managed"
expect_managed "Library/Application Support/Leader Key/config.json" "$ci_managed"
expect_managed "Library/Application Support/Code/User" "$ci_managed"
expect_unmanaged "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$ci_managed"
expect_unmanaged ".config/zed" "$ci_managed"
expect_unmanaged "Library/Colors/nvALT.clr" "$ci_managed"
expect_unmanaged "Library/Preferences/com.jordanbaird.Ice.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/com.cmuxterm.app.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/net.elasticthreads.nv.plist" "$ci_managed"
# tailscale + voiceink are personal apps now, so the base-only ci type drops them.
expect_unmanaged "Library/Preferences/io.tailscale.ipn.macsys.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$ci_managed"

# --- work: full dev machine minus the personal apps (the core requirement) ---
expect_managed ".config/ghostty" "$work_managed"
expect_managed ".hammerspoon" "$work_managed"
expect_managed "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$work_managed"
expect_managed ".config/zed" "$work_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$work_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$work_managed"
expect_unmanaged "Library/Preferences/io.tailscale.ipn.macsys.plist" "$work_managed"
expect_unmanaged "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$work_managed"
expect_ignored "Library/Preferences/io.tailscale.ipn.macsys.plist" "$work_ignored"
expect_ignored "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$work_ignored"

# --- ci ignored set: dev/dev-apple/personal-app configs (default file = ci_ignored) ---
expect_ignored ".config/zed"
expect_ignored ".config/cmux"
expect_ignored ".hammerspoon"
expect_ignored "Library/Colors/nvALT.clr"
expect_ignored "Library/Preferences/com.jordanbaird.Ice.plist"
expect_ignored "Library/Preferences/com.cmuxterm.app.plist"
expect_ignored "Library/Preferences/net.elasticthreads.nv.plist"
expect_ignored "Library/Preferences/pro.betterdisplay.BetterDisplay.plist"
expect_ignored "Library/Preferences/io.tailscale.ipn.macsys.plist"
expect_ignored "Library/Preferences/com.prakashjoshipax.VoiceInk.plist"

# --- empty group set ⇒ every gated config ignored ---
for p in \
  "Library/Application Support/Leader Key/config.json" \
  ".config/ghostty" \
  "Library/Application Support/Code/User" \
  "Library/Preferences/dev.kdrag0n.MacVirt.plist" \
  "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" \
  "Library/Preferences/com.hegenberg.BetterTouchTool.plist" \
  "Library/Preferences/com.raycast.macos.plist" \
  ".config/raycast/scripts/temp-admin.sh" \
  ".local/share/raycast-extensions" \
  "Library/Preferences/io.tailscale.ipn.macsys.plist" \
  "Library/Preferences/com.setapp.DesktopClient.plist"; do
  expect_ignored "$p" "$empty_ignored"
done

# An unknown machine type must fail loudly through the gate, not silently treat
# every app as disabled.
set +e
bogus_out="$(chezmoi_isolated --override-data '{"machine_type":"bogus"}' ignored 2>&1)"
bogus_rc=$?
set -e
[[ $bogus_rc -ne 0 ]] || die "unknown machine type should fail the ignored evaluation"
[[ $bogus_out == *"unknown machine type"* ]] || die "expected 'unknown machine type' error, got: $bogus_out"

python3 - "$leader_key_json" <<'PY'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["type"] == "group"
assert {item["key"] for item in config["actions"]} == {"t", "s", "v", "w", "b", "m"}
PY

print -- "OK package-gated-configs"
