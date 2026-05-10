#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "ice-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/com.jordanbaird.Ice.plist.tmpl"
script="$tmp_root/modify_ice.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Preferences/modify_private_com.jordanbaird.Ice.plist.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python -m py_compile "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "AutoRehide": False,
    "HideApplicationMenus": False,
    "ShowIceIcon": False,
    "Hotkeys": {"ToggleHiddenSection": b"null"},
    "MenuBarAppearanceConfigurationV2": b"local-menu-bar-layout",
    "NSStatusItem Preferred Position HItem": 224,
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

assert merged["AutoRehide"] is True
assert merged["CanToggleAlwaysHiddenSection"] is True
assert merged["CustomIceIconIsTemplate"] is False
assert merged["EnableAlwaysHiddenSection"] is False
assert merged["HideApplicationMenus"] is True
assert merged["IceBarLocation"] == 0
assert merged["ItemSpacingOffset"] == 0.0
assert merged["RehideInterval"] == 15.0
assert merged["RehideStrategy"] == 0
assert merged["ShowAllSectionsOnUserDrag"] is True
assert merged["ShowIceIcon"] is True
assert merged["ShowOnClick"] is True
assert merged["ShowOnHover"] is False
assert merged["ShowOnHoverDelay"] == 0.2
assert merged["ShowOnScroll"] is True
assert merged["ShowSectionDividers"] is False
assert merged["TempShowInterval"] == 15.0
assert merged["UseIceBar"] is False
assert merged["Hotkeys"] == {"ToggleHiddenSection": b"null"}
assert merged["MenuBarAppearanceConfigurationV2"] == b"local-menu-bar-layout"
assert merged["NSWindow Frame SettingsWindow"] == "local-window-frame"
assert merged["SULastCheckTime"] == "local-update-state"

assert empty_merged["AutoRehide"] is True
assert empty_merged["ShowIceIcon"] is True
assert "Hotkeys" not in empty_merged
PY

print -- "OK ice-plist-modify"
