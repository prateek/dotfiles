load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_onchange_after_17-tartelet-settings.sh.tmpl
  cat > "$FIXTURE/bin/app-tool" <<'STUB'
#!/bin/sh
exec "$TEST_PYTHON" - "$0" "$@" <<'PY'
import json, os, pathlib, sys
name, *args = sys.argv[1:]
name = pathlib.Path(name).name
root = pathlib.Path(os.environ['FIXTURE'])
state_file = root / 'defaults.json'
state = json.loads(state_file.read_text()) if state_file.exists() else {}
with (root / 'calls.jsonl').open('a') as stream:
    stream.write(json.dumps([name, *args]) + '\n')
if name == 'defaults':
    verb, domain, key, *value = args
    assert domain == 'dk.shape.Tartelet', args
    if verb == 'read':
        if key not in state:
            sys.exit(1)
        print(state[key])
    elif verb == 'write':
        kind, text = value
        state[key] = {'true': '1', 'false': '0'}[text] if kind == '-bool' else text
        state_file.write_text(json.dumps(state))
    else:
        sys.exit(97)
elif name == 'pgrep':
    assert args == ['-x', 'Tartelet'], args
    sys.exit(0 if (root / 'running').exists() else 1)
elif name in ('osascript', 'killall'):
    (root / 'running').unlink(missing_ok=True)
elif name == 'open':
    assert args == ['-a', 'Tartelet'], args
    (root / 'running').touch()
elif name == 'uname':
    print('Darwin')
else:
    sys.exit(97)
PY
STUB
  chmod +x "$FIXTURE/bin/app-tool"
  local tool
  for tool in defaults pgrep osascript killall open uname; do
    ln -s app-tool "$FIXTURE/bin/$tool"
  done
}

@test "Tartelet applies typed settings between quit and relaunch and then converges" {
  touch "$FIXTURE/running"
  render_template "$template" homelab '{"machines_local":{"tart_home":"/Volumes/Runner Store/tart"}}' > "$FIXTURE/settings.sh"
  run_bash 0 "$FIXTURE/settings.sh"
  assert_success
  assert_output --partial 'Applied Tartelet settings via defaults'
  [[ "$stderr" == *'Quitting Tartelet to apply settings'* ]]
  run -0 "$TEST_PYTHON" - "$FIXTURE/calls.jsonl" <<'PY'
import json, sys
calls = [json.loads(line) for line in open(sys.argv[1])]
writes = [row[2:] for row in calls if row[:2] == ['defaults', 'write']]
assert writes == [
    ['dk.shape.Tartelet', 'githubRunnerScope', '-string', 'repo'],
    ['dk.shape.Tartelet', 'gitHubRunnerLabels', '-string', 'tartelet,homelab'],
    ['dk.shape.Tartelet', 'virtualMachine', '-string', 'virtualMachine=tartelet-runner'],
    ['dk.shape.Tartelet', 'numberOfVirtualMachines', '-int', '1'],
    ['dk.shape.Tartelet', 'startVirtualMachinesOnLaunch', '-bool', 'true'],
    ['dk.shape.Tartelet', 'tartHomeFolderURL', '-string', '/Volumes/Runner Store/tart'],
], writes
quit_at = next(i for i, row in enumerate(calls) if row[0] == 'osascript')
write_at = [i for i, row in enumerate(calls) if row[:2] == ['defaults', 'write']]
open_at = next(i for i, row in enumerate(calls) if row[0] == 'open')
assert quit_at < min(write_at) <= max(write_at) < open_at, calls
PY
  assert_success
  : > "$FIXTURE/calls.jsonl"
  run_bash 0 "$FIXTURE/settings.sh"
  assert_success
  assert_output --partial 'already match; nothing to do'
  [ -z "$stderr" ]
  run -0 "$TEST_PYTHON" - "$FIXTURE/calls.jsonl" <<'PY'
import json, sys
calls = [json.loads(line) for line in open(sys.argv[1])]
assert calls, calls
assert all(row[0] == 'uname' or row[:2] == ['defaults', 'read'] for row in calls), calls
PY
  assert_success
}

@test "Tartelet leaves its default store and stopped application alone when no host store is set" {
  render_template "$template" homelab > "$FIXTURE/settings.sh"
  run_bash 0 "$FIXTURE/settings.sh"
  assert_success
  [ -z "$stderr" ]
  run -0 "$TEST_PYTHON" - "$FIXTURE/calls.jsonl" <<'PY'
import json, sys
calls = [json.loads(line) for line in open(sys.argv[1])]
writes = [row for row in calls if row[:2] == ['defaults', 'write']]
assert {row[3] for row in writes} == {'githubRunnerScope', 'gitHubRunnerLabels', 'virtualMachine',
                                   'numberOfVirtualMachines', 'startVirtualMachinesOnLaunch'}, writes
assert not any(row[0] in ('open', 'osascript', 'killall') for row in calls), calls
PY
  assert_success
}

@test "Tartelet personal render skips app settings without requiring runner facts" {
  render_template "$template" personal > "$FIXTURE/settings.sh"
  run_bash 0 "$FIXTURE/settings.sh"
  assert_success
  assert_output --partial 'tartelet cask not selected'
  [ -z "$stderr" ]
  [ ! -e "$FIXTURE/calls.jsonl" ]
}
