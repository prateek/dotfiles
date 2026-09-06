# Child-shell snippets and injection probes require literal arguments.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
  launcher="$DOTFILES_ROOT/scripts/pi-isolated-run"
  root="$FIXTURE/isolated"
}

@test "Pi isolated launcher materializes the settings it prints and an executable statusline" {
  run -0 bash -c '"$@" > "$FIXTURE/settings.json"' _ "$launcher" --root "$root" --empty --print-settings
  assert_success
  run -0 cmp "$FIXTURE/settings.json" "$root/home/.pi/agent/settings.json"
  assert_success
  run -0 "$TEST_PYTHON" - "$FIXTURE/settings.json" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
assert 'npm:pi-statusline' in settings['packages'], settings
assert settings['statusLine']['command'] == '~/.pi/agent/statusline.sh', settings
PY
  assert_success
  [ -d "$root/sessions" ]
  [ -x "$root/home/.pi/agent/statusline.sh" ]
}

@test "Pi dry-run reports isolated environment and package updates without launching" {
  run -0 "$launcher" --root "$root" --empty --dry-run -- --no-approve
  assert_success
  assert_output --partial 'pi update --extensions'
  assert_output --partial 'pi --no-approve'
  run -0 "$TEST_PYTHON" - "$root" "$output" <<'PY'
import shlex, sys
root, text = sys.argv[1:]
actual = dict(shlex.split(line)[0].split('=', 1) for line in text.splitlines()[:3])
assert actual == {'HOME': root + '/home', 'PI_CODING_AGENT_DIR': root + '/home/.pi/agent',
                  'PI_CODING_AGENT_SESSION_DIR': root + '/sessions'}, actual
PY
  assert_success
  run -0 "$launcher" --root "$root" --empty --no-install --dry-run
  assert_success
  refute_output --partial 'pi update --extensions'
}

@test "Pi dry-run removes its automatically created root before returning" {
  run -0 "$launcher" --empty --dry-run
  assert_success
  assert_output --partial 'cleanup: automatic rm -rf'
  local text="$output"
  run -0 "$TEST_PYTHON" -c 'import shlex,sys; print(shlex.split(sys.argv[1].splitlines()[0])[0].removeprefix("HOME="))' "$text"
  assert_success
  [ ! -d "${output%/home}" ]
}

@test "Pi preserves positional arguments on both sides of its separator" {
  run -0 "$launcher" --root "$root" --empty --dry-run --no-install foo -- bar
  assert_success
  assert_output --partial 'pi foo bar'
}

@test "Pi help contains usage without exposing the script body" {
  run -0 "$launcher" --help
  assert_success
  assert_output --partial 'Usage:'
  refute_output --partial 'set -euo pipefail'
}

@test "Pi updates before launch and passes isolated paths and literal arguments" {
  cat > "$FIXTURE/bin/pi" <<'STUB'
#!/bin/sh
exec "$TEST_PYTHON" - "$@" <<'PY'
import json, os, sys
with open(os.environ['FIXTURE'] + '/pi.calls', 'a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'env': {key: os.environ[key] for key in
        ('HOME', 'PI_CODING_AGENT_DIR', 'PI_CODING_AGENT_SESSION_DIR')}}) + '\n')
PY
STUB
  chmod +x "$FIXTURE/bin/pi"
  run -0 "$launcher" --root "$root" --empty -- 'space ; $(touch injected) *'
  assert_success
  run -0 "$TEST_PYTHON" - "$FIXTURE/pi.calls" "$root" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1])]
root = sys.argv[2]
assert [row['args'] for row in records] == [['update', '--extensions'], ['space ; $(touch injected) *']], records
for row in records:
    assert row['env'] == {'HOME': root + '/home', 'PI_CODING_AGENT_DIR': root + '/home/.pi/agent',
                          'PI_CODING_AGENT_SESSION_DIR': root + '/sessions'}, row
PY
  assert_success
  [ ! -e injected ]
}
