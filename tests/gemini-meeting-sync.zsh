#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "gemini-meeting-sync: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
export XDG_CONFIG_HOME="$tmp_root/config"
export GEMINI_MEETING_SYNC_TMP_ROOT="$tmp_root/tmp"
mkdir -p "$HOME"

zsh -n "$DOTFILES_ROOT/bin/gemini-meeting-sync"
python3 -m json.tool "$DOTFILES_ROOT/home/dot_config/gemini-meeting-sync/config.json" >/dev/null

"$DOTFILES_ROOT/bin/gemini-meeting-sync" enable >/dev/null

[[ -f "$XDG_CONFIG_HOME/gemini-meeting-sync/enabled" ]] || die "missing enabled marker"
[[ -f "$XDG_CONFIG_HOME/gemini-meeting-sync/config.json" ]] || die "missing generated config"

python3 - "$XDG_CONFIG_HOME/gemini-meeting-sync/config.json" "$HOME" <<'PY'
import json
import os
import sys
from pathlib import Path

cfg = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert cfg["out_dir"] == "~/code/github.com/prateek/personal-notes/21-openai-meetings"
assert os.path.expanduser(cfg["out_dir"]) == sys.argv[2] + "/code/github.com/prateek/personal-notes/21-openai-meetings"
assert cfg["interval_seconds"] == 900
assert cfg["notify_on_success"] == "on_change"
assert cfg["notify_on_failure"] is True
PY

print -- "OK gemini-meeting-sync"
