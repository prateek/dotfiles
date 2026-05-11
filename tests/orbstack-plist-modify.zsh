#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "orbstack-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/dev.kdrag0n.MacVirt.plist.tmpl"
script="$tmp_root/modify_orbstack.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/private_Preferences/modify_private_dev.kdrag0n.MacVirt.plist.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python -m py_compile "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "global_showMenubarExtra": False,
    "drm_lastState": '{"entitlementTier":0,"entitlementType":0}',
    "selectedTab": "k8s-pods",
    "NSWindow Frame main": "local-window-frame",
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

assert merged["global_showMenubarExtra"] is True
assert merged["drm_lastState"] == '{"entitlementTier":0,"entitlementType":0}'
assert merged["selectedTab"] == "k8s-pods"
assert merged["NSWindow Frame main"] == "local-window-frame"
assert merged["SULastCheckTime"] == "local-update-state"

assert empty_merged["global_showMenubarExtra"] is True
assert "selectedTab" not in empty_merged
PY

print -- "OK orbstack-plist-modify"
