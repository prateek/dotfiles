#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "moom-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/com.manytricks.Moom.plist.tmpl"
script="$tmp_root/modify_moom.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Preferences/modify_private_com.manytricks.Moom.plist.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "Application Mode": 99,
    "Custom Controls": [],
    "SULastCheckTime": "local-state",
    "Unmanaged Local Key": {"kept": True},
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

assert merged["Application Mode"] == 2
assert len(merged["Custom Controls"]) == 11
assert len(merged["Custom Controls (4001)"]) == 10
assert all(item.get("Title") != "Examples" for item in merged["Custom Controls (4001)"])
assert merged["Keyboard Controls"]["Visual Representation"] == "\u2303Q"
assert merged["SULastCheckTime"] == "local-state"
assert merged["Unmanaged Local Key"] == {"kept": True}
assert empty_merged["Application Mode"] == 2
assert len(empty_merged["Custom Controls"]) == 11
PY

print -- "OK moom-plist-modify"
