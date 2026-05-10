#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "nvalt-colors: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_json="$DOTFILES_ROOT/home/.chezmoiassets/Library/Colors/nvALT.clr.json"
script="$tmp_root/modify_nvalt_colors.py"
colors_plist="$tmp_root/nvALT.clr"

uv run --quiet --python '>=3.11' python -m json.tool "$source_json" >/dev/null

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Colors/modify_private_nvALT.clr.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python -m py_compile "$script"

"$script" </dev/null | cat >"$colors_plist"

uv run --quiet --python '>=3.11' python - "$colors_plist" <<'PY'
import pathlib
import plistlib
import sys

payload = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
objects = payload["$objects"]

def obj(uid):
    return objects[uid.data]

keys = [obj(uid) for uid in obj(payload["$top"]["NSKeys"])["NS.objects"]]
colors = [obj(uid)["NSRGB"].decode("ascii").rstrip("\0") for uid in obj(payload["$top"]["NSColors"])["NS.objects"]]

assert payload["$archiver"] == "NSKeyedArchiver"
assert keys == [
    "Search Highlight",
    "Foreground Text (AndaleMono 13)",
    "Background",
]
assert colors == [
    "0.003921568859 0.3215686381 0.6627451181",
    "0.9215686917 0.9058824182 0.8901961446",
    "0.2235294282 0.2235294282 0.2235294282",
]
PY

print -- "OK nvalt-colors"
