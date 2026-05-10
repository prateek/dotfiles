#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "nvalt-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/net.elasticthreads.nv.plist.tmpl"
script="$tmp_root/modify_nvalt.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Preferences/modify_private_net.elasticthreads.nv.plist.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python -m py_compile "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "AppActivationKeyCode": 999,
    "Bookmarks": ["local"],
    "DefaultEEIdentifier": "local.editor",
    "DirectoryAlias": b"local-directory-alias",
    "NSWindow Frame NotationWindow": "local-window-frame",
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

assert merged["AppActivationKeyCode"] == 49
assert merged["AppActivationModifiers"] == 2048
assert merged["Bookmarks"] == []
assert merged["BookmarksVisible"] is False
assert merged["ColorScheme"] == 2
assert merged["DefaultEEIdentifier"] == "com.microsoft.VSCode"
assert merged["UserEEIdentifiers"] == [
    "com.apple.TextEdit",
    "dev.zed.Zed",
    "com.todesktop.230313mzl4w4u92",
    "com.microsoft.VSCode",
]
assert merged["ShowDockIcon"] is False
assert merged["StatusBarItem"] is True
assert merged["DirectoryAlias"] == b"local-directory-alias"
assert merged["NSWindow Frame NotationWindow"] == "local-window-frame"
assert merged["SULastCheckTime"] == "local-update-state"

assert empty_merged["AppActivationKeyCode"] == 49
assert empty_merged["DefaultEEIdentifier"] == "com.microsoft.VSCode"
assert "DirectoryAlias" not in empty_merged
PY

print -- "OK nvalt-plist-modify"
