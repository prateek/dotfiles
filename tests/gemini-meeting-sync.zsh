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

stub_script="$tmp_root/sync_gemini_meetings.py"
cat >"$stub_script" <<'PY'
#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--out-dir", required=True)
parser.add_argument("--days", required=True)
parser.add_argument("--prune-days", required=True)
parser.add_argument("--no-calendar", action="store_true")
args = parser.parse_args()

run_dir = Path(os.environ["GEMINI_MEETING_SYNC_STUB_RUN_DIR"])
run_dir.mkdir(parents=True, exist_ok=True)
(run_dir / "summary.json").write_text(json.dumps({"errors": 0}), encoding="utf-8")
print(f"Run dir: {run_dir}")
PY
chmod +x "$stub_script"

export GEMINI_MEETING_SYNC_SCRIPT="$stub_script"
export GEMINI_MEETING_SYNC_STUB_RUN_DIR="$tmp_root/run-dir"
"$DOTFILES_ROOT/bin/gemini-meeting-sync" run >/dev/null

python3 - "$GEMINI_MEETING_SYNC_TMP_ROOT/latest-status.json" "$GEMINI_MEETING_SYNC_STUB_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

status = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert status["exit_code"] == 0
assert status["errors"] == 0
assert status["run_dir"] == sys.argv[2]
PY

unset GEMINI_MEETING_SYNC_SCRIPT GEMINI_MEETING_SYNC_STUB_RUN_DIR
missing_home="$tmp_root/missing-home"
mkdir -p "$missing_home"
if HOME="$missing_home" "$DOTFILES_ROOT/bin/gemini-meeting-sync" run >"$tmp_root/missing.out" 2>"$tmp_root/missing.err"; then
  die "run unexpectedly succeeded without default sync script"
fi
grep -q "$missing_home/.agents/skills/gog-gemini-meeting-import/scripts/sync_gemini_meetings.py" "$tmp_root/missing.err" \
  || die "missing-script error did not use ~/.agents/skills"

print -- "OK gemini-meeting-sync"
