#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "thaw-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/com.stonerl.Thaw.plist.tmpl"
script="$tmp_root/modify_thaw.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/private_Preferences/modify_private_com.stonerl.Thaw.plist.tmpl" \
  >"$script"
chmod +x "$script"

bash -n "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "EnableAlwaysHiddenSection": True,
    "SUAutomaticallyUpdate": False,
    "SectionDividerStyle": 0,
    "DisplayIceBarConfigurations": b"local-per-display-bar-config",
    "MenuBarAppearanceConfigurationV2": b"local-menu-bar-appearance",
    "MenuBarItemManager.knownItemIdentifiers": ["com.example.app:Item-0"],
    "NSStatusItem Preferred Position Thaw.ControlItem.Visible": 316,
    "NSWindow Frame SettingsWindow": "local-window-frame",
    "SULastCheckTime": "local-update-state",
}
with path.open("wb") as file:
    plistlib.dump(payload, file, fmt=plistlib.FMT_BINARY)
PY

"$script" <"$current_plist" | cat >"$merged_plist"
"$script" </dev/null | cat >"$empty_merged_plist"

uv run --quiet --python '>=3.11' python - "$merged_plist" "$empty_merged_plist" <<'PY'
import pathlib
import plistlib
import sys

merged = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
empty_merged = plistlib.loads(pathlib.Path(sys.argv[2]).read_bytes())

assert merged["EnableAlwaysHiddenSection"] is False
assert merged["SUAutomaticallyUpdate"] is True
assert merged["SUEnableAutomaticChecks"] is True
assert merged["SectionDividerStyle"] == 1
assert merged["DisplayIceBarConfigurations"] == b"local-per-display-bar-config"
assert merged["MenuBarAppearanceConfigurationV2"] == b"local-menu-bar-appearance"
assert merged["MenuBarItemManager.knownItemIdentifiers"] == ["com.example.app:Item-0"]
assert merged["NSStatusItem Preferred Position Thaw.ControlItem.Visible"] == 316
assert merged["NSWindow Frame SettingsWindow"] == "local-window-frame"
assert merged["SULastCheckTime"] == "local-update-state"

assert empty_merged["EnableAlwaysHiddenSection"] is False
assert empty_merged["SectionDividerStyle"] == 1
assert "MenuBarAppearanceConfigurationV2" not in empty_merged
PY

print -- "OK thaw-plist-modify"
