#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "zed-settings: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
template="$DOTFILES_ROOT/home/dot_config/zed/settings.json.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

full_json="$tmp_root/full.json"

chezmoi --source "$DOTFILES_ROOT" execute-template --file "$template" >"$full_json"

python3 - "$full_json" <<'PY'
import json
import pathlib
import sys

full = json.loads(pathlib.Path(sys.argv[1]).read_text())

assert full["auto_install_extensions"] == {
    "html": True,
    "latex": True,
    "typst": True,
    "vscode-dark-plus": True,
}
PY

print -- "OK zed-settings"
