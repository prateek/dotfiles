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
homelab_managed="$tmp_root/homelab-managed.txt"
homelab_ignored="$tmp_root/homelab-ignored.txt"
empty_ignored="$tmp_root/empty-ignored.txt"
tuna_config="$tmp_root/tuna-config.toml"
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

chezmoi_isolated \
  --override-data '{"machine_type":"homelab"}' \
  managed --path-style relative >"$homelab_managed"

chezmoi_isolated \
  --override-data '{"machine_type":"homelab"}' \
  ignored >"$homelab_ignored"

# Empty group set ⇒ no casks enabled ⇒ every gated config ignored. Arrays in
# --override-data replace rather than merge, so the ci type layer's groups=[] wins.
chezmoi_isolated \
  --override-data '{"machine_type":"ci","machines":{"type":{"ci":{"groups":[]}}}}' \
  ignored >"$empty_ignored"

# Tuna config lives at the XDG path (~/.config/tuna/config.toml), plain TOML managed as the
# authoritative sync-folder source (Tuna owns the format), so copy it verbatim.
cp "$DOTFILES_ROOT/home/dot_config/tuna/config.toml" "$tuna_config"

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

# --- personal: Mac desktop + dev + Apple + personal apps ---------------------
expect_managed ".config/cmux/preferences.json" "$personal_managed"
expect_managed ".config/ghostty" "$personal_managed"
expect_managed ".hammerspoon" "$personal_managed"
expect_managed "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$personal_managed"
expect_managed "Library/Preferences/com.raycast.macos.plist" "$personal_managed"
expect_managed ".config/raycast/scripts/temp-admin.sh" "$personal_managed"
expect_managed ".local/share/raycast-extensions/orca-worktree/package.json" "$personal_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$personal_managed"
expect_managed "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$personal_managed"
expect_managed ".config/zed" "$personal_managed"
expect_managed ".config/tuna/config.toml" "$personal_managed"
expect_managed "Library/Preferences/com.brnbw.Tuna.plist" "$personal_managed"
expect_managed "Library/Scripts/g95-sharp.sh" "$personal_managed"
expect_managed "Library/Scripts/panw-password.sh" "$personal_managed"
expect_managed "Library/Scripts/temp-admin.sh" "$personal_managed"
expect_managed "Library/Application Support/orca/orca-data.json" "$personal_managed"
expect_managed ".orca/keybindings.json" "$personal_managed"
expect_managed "Library/Application Support/Code/User" "$personal_managed"
expect_managed "Library/Colors/nvALT.clr" "$personal_managed"
expect_managed "Library/Preferences/com.jordanbaird.Ice.plist" "$personal_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$personal_managed"
expect_managed "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$personal_managed"
expect_managed "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$personal_managed"
expect_managed "Library/Preferences/net.elasticthreads.nv.plist" "$personal_managed"
expect_unmanaged "Library/Preferences/io.tailscale.ipn.macsys.plist" "$personal_managed"

# --- ci: core only. All cask-gated app configs are unmanaged. -----------
expect_unmanaged ".config/cmux" "$ci_managed"
expect_unmanaged ".config/ghostty" "$ci_managed"
expect_unmanaged ".hammerspoon" "$ci_managed"
expect_unmanaged "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/com.raycast.macos.plist" "$ci_managed"
expect_unmanaged ".config/raycast/scripts/temp-admin.sh" "$ci_managed"
expect_unmanaged "Library/Preferences/com.setapp.DesktopClient.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/dev.kdrag0n.MacVirt.plist" "$ci_managed"
expect_unmanaged ".config/tuna/config.toml" "$ci_managed"
expect_unmanaged "Library/Preferences/com.brnbw.Tuna.plist" "$ci_managed"
expect_unmanaged "Library/Application Support/Code/User" "$ci_managed"
expect_unmanaged "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$ci_managed"
expect_unmanaged ".config/zed" "$ci_managed"
expect_unmanaged "Library/Colors/nvALT.clr" "$ci_managed"
expect_unmanaged "Library/Preferences/com.jordanbaird.Ice.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/com.cmuxterm.app.plist" "$ci_managed"
expect_unmanaged "Library/Application Support/orca/orca-data.json" "$ci_managed"
expect_unmanaged ".orca/keybindings.json" "$ci_managed"
expect_unmanaged "Library/Preferences/net.elasticthreads.nv.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/io.tailscale.ipn.macsys.plist" "$ci_managed"
expect_unmanaged "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$ci_managed"

# --- work: Mac desktop + dev + work apps, no personal/homelab config ---------
# setapp is shared across daily-driver laptops (mac-desktop group), so its
# config follows the install onto work; nvALT/VoiceInk stay personal-only.
expect_managed ".config/ghostty" "$work_managed"
expect_managed ".hammerspoon" "$work_managed"
expect_managed "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$work_managed"
expect_managed ".config/zed" "$work_managed"
expect_managed "Library/Application Support/orca/orca-data.json" "$work_managed"
expect_managed ".orca/keybindings.json" "$work_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$work_managed"
expect_managed "Library/Preferences/com.setapp.DesktopClient.plist" "$work_managed"
expect_unmanaged "Library/Colors/nvALT.clr" "$work_managed"
expect_unmanaged "Library/Preferences/net.elasticthreads.nv.plist" "$work_managed"
expect_unmanaged "Library/Preferences/io.tailscale.ipn.macsys.plist" "$work_managed"
expect_unmanaged "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$work_managed"
expect_ignored "Library/Preferences/io.tailscale.ipn.macsys.plist" "$work_ignored"
expect_ignored "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$work_ignored"

# --- homelab: dev + Apple + remote/admin + AI agent apps, no Mac desktop/personal apps ---
expect_managed "Library/Preferences/io.tailscale.ipn.macsys.plist" "$homelab_managed"
expect_managed "Library/Preferences/com.cmuxterm.app.plist" "$homelab_managed"
expect_managed "Library/Application Support/orca/orca-data.json" "$homelab_managed"
expect_managed ".orca/keybindings.json" "$homelab_managed"
expect_unmanaged ".config/ghostty" "$homelab_managed"
expect_unmanaged ".hammerspoon" "$homelab_managed"
expect_unmanaged "Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$homelab_managed"
expect_unmanaged "Library/Preferences/com.raycast.macos.plist" "$homelab_managed"
expect_unmanaged "Library/Preferences/com.setapp.DesktopClient.plist" "$homelab_managed"
expect_unmanaged "Library/Preferences/pro.betterdisplay.BetterDisplay.plist" "$homelab_managed"
expect_unmanaged ".config/zed" "$homelab_managed"
expect_unmanaged "Library/Colors/nvALT.clr" "$homelab_managed"
expect_unmanaged "Library/Preferences/com.jordanbaird.Ice.plist" "$homelab_managed"
expect_unmanaged "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$homelab_managed"
expect_ignored ".config/ghostty" "$homelab_ignored"
expect_ignored "Library/Preferences/com.setapp.DesktopClient.plist" "$homelab_ignored"
expect_ignored "Library/Preferences/com.prakashjoshipax.VoiceInk.plist" "$homelab_ignored"

# --- ci ignored set: non-core app configs (default file = ci_ignored) ---
expect_ignored ".config/ghostty"
expect_ignored "Library/Preferences/com.hegenberg.BetterTouchTool.plist"
expect_ignored "Library/Preferences/com.raycast.macos.plist"
expect_ignored ".config/raycast/scripts/temp-admin.sh"
expect_ignored ".config/tuna/config.toml"
expect_ignored "Library/Preferences/com.brnbw.Tuna.plist"
expect_ignored "Library/Scripts/g95-sharp.sh"
expect_ignored "Library/Scripts/panw-password.sh"
expect_ignored "Library/Scripts/temp-admin.sh"
expect_ignored "Library/Application Support/Code/User"
expect_ignored ".config/zed"
expect_ignored ".config/cmux"
expect_ignored "Library/Application Support/orca/orca-data.json"
expect_ignored ".orca/keybindings.json"
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
  ".config/tuna/config.toml" \
  "Library/Preferences/com.brnbw.Tuna.plist" \
  "Library/Application Support/orca/orca-data.json" \
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

python3 - "$tuna_config" <<'PY'
import pathlib
import sys
import tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
binds = {b["key"]: b for b in config["comboMode"]["bindings"]}
assert set(binds) == {"1", "t", "s", "b", "c", "m", "f", "z"}, sorted(binds)
# "z" is the misc group; confirm nesting renders and its utility/GhostPepper binds exist.
misc = binds["z"]
assert misc.get("label") == "misc"
assert {"d", "m", "z", "t", "r", "g"} <= {a["key"] for a in misc["children"]}
# ⌘-tap emits F18; Tuna opens combo mode on it.
assert config["hotkeys"]["app"]["comboMode"] == {"carbonKeyCode": 79, "carbonModifiers": 0}
PY

print -- "OK package-gated-configs"
