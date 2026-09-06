load '../../support/common'

setup() {
  setup_fixture
  unset GEMINI_MEETING_SYNC_SCRIPT GEMINI_MEETING_SYNC_STUB_RUN_DIR
  export GEMINI_MEETING_SYNC_TMP_ROOT="$FIXTURE/tmp"
  wrapper="$DOTFILES_ROOT/bin/gemini-meeting-sync"
}

@test "Gemini sync enable creates its marker and valid generated defaults" {
  run_zsh 0 -n "$wrapper"
  assert_success
  run -0 "$TEST_PYTHON" -m json.tool "$DOTFILES_ROOT/home/dot_config/gemini-meeting-sync/config.json"
  assert_success
  run_zsh 0 "$wrapper" enable
  assert_success
  [ -z "$stderr" ]
  [ -f "$XDG_CONFIG_HOME/gemini-meeting-sync/enabled" ]
  run -0 "$TEST_PYTHON" - "$XDG_CONFIG_HOME/gemini-meeting-sync/config.json" <<'PY'
import json, os, sys
cfg = json.load(open(sys.argv[1]))
assert cfg['out_dir'] == '~/code/github.com/prateek/personal-notes/21-openai-meetings', cfg
assert os.path.expanduser(cfg['out_dir']) == os.environ['HOME'] + '/code/github.com/prateek/personal-notes/21-openai-meetings'
assert cfg['interval_seconds'] == 900, cfg
assert cfg['notify_on_success'] == 'on_change', cfg
assert cfg['notify_on_failure'] is True, cfg
PY
  assert_success
}

@test "Gemini sync records a successful producer run and its output directory" {
  export GEMINI_MEETING_SYNC_SCRIPT="$FIXTURE/importer.py"
  cat > "$GEMINI_MEETING_SYNC_SCRIPT" <<'PY'
import argparse, json, os
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('--out-dir', required=True)
parser.add_argument('--days', required=True)
parser.add_argument('--prune-days', required=True)
parser.add_argument('--no-calendar', action='store_true')
args = parser.parse_args()
assert args.out_dir == os.environ['HOME'] + '/code/github.com/prateek/personal-notes/21-openai-meetings', args
root = Path(os.environ['FIXTURE']) / 'producer run'
root.mkdir()
(root / 'summary.json').write_text(json.dumps({'errors': 0}))
print(f'Run dir: {root}')
PY
  run_zsh 0 "$wrapper" run
  assert_success
  [ -z "$stderr" ]
  run -0 "$TEST_PYTHON" - "$GEMINI_MEETING_SYNC_TMP_ROOT/latest-status.json" <<'PY'
import json, os, sys
status = json.load(open(sys.argv[1]))
assert status['exit_code'] == 0, status
assert status['errors'] == 0, status
assert status['run_dir'] == os.environ['FIXTURE'] + '/producer run', status
PY
  assert_success
}

@test "Gemini sync explains the missing default producer path" {
  run_zsh 2 "$wrapper" run
  assert_failure 2
  [[ "$stderr" == *"$HOME/.agents/skills/gog-gemini-meeting-import/scripts/sync_gemini_meetings.py"* ]]
}
