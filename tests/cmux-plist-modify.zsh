#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "cmux-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

script="$tmp_root/modify_cmux.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/com.cmuxterm.app.plist.tmpl"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/private_Preferences/modify_private_com.cmuxterm.app.plist.tmpl" \
  >"$script"
chmod +x "$script"

bash -n "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "appearanceMode": "dark",
    "browserHostWhitelist": "old.example",
    "shortcut.focusDown": b'{"command":true,"control":false,"key":"x","option":false,"shift":false}',
    "cmux.session.lastWindowGeometry.v1": b"local-window-state",
    "posthog.lastActiveDayUTC": "local-state",
    "Unmanaged Local Key": {"kept": True},
}
with path.open("wb") as file:
    plistlib.dump(payload, file, fmt=plistlib.FMT_BINARY)
PY

"$script" <"$current_plist" | cat >"$merged_plist"

uv run --quiet --python '>=3.11' python - "$merged_plist" <<'PY'
import json
import pathlib
import plistlib
import sys

merged = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())

assert merged["appearanceMode"] == "dark"
assert merged["browserHostWhitelist"] == "chatgpt.com\ngoogle.com\ngmail.com\nanthropic.com\nopenai.com"
assert merged["browserThemeMode"] == "system"
assert merged["sidebarActiveTabIndicatorStyle"] == "solidFill"
assert merged["sidebarAppearanceDefaultsVersion"] == 1
assert merged["sidebarTintOpacity"] == 0.18
assert json.loads(merged["shortcut.focusDown"].decode()) == {
    "command": False,
    "control": True,
    "key": "j",
    "option": False,
    "shift": False,
}
assert json.loads(merged["shortcut.prevSurface"].decode()) == {
    "command": True,
    "control": False,
    "key": "[",
    "option": False,
    "shift": True,
}
assert merged["cmux.session.lastWindowGeometry.v1"] == b"local-window-state"
assert merged["posthog.lastActiveDayUTC"] == "local-state"
assert merged["Unmanaged Local Key"] == {"kept": True}
PY

print -- "OK cmux-plist-modify"
