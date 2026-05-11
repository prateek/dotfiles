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
template="$DOTFILES_ROOT/home/dot_config/zed/private_settings.json.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

full_json="$tmp_root/full.json"

chezmoi --source "$DOTFILES_ROOT" execute-template --file "$template" >"$full_json"

python3 - "$full_json" <<'PY'
import json
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
text = re.sub(r"(?m)^\s*//.*\n", "", text)
text = re.sub(r",\s*([}\]])", r"\1", text)
full = json.loads(text)

assert full["auto_install_extensions"] == {
    "html": True,
    "latex": True,
    "typst": True,
    "vscode-dark-plus": True,
}
assert full["project_panel"]["dock"] == "right"
assert full["agent"]["dock"] == "left"
assert full["ui_font_size"] == 16
assert full["buffer_font_size"] == 15
assert full["theme"]["dark"] == "One Dark"
PY

print -- "OK zed-settings"
