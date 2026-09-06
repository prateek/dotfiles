load '../../support/common'

setup() {
  dash="$(command -v dash || true)"
  setup_fixture
}

# bats test_tags=host
@test "Claude statusline renders under the installed Dash interpreter" {
  [ -n "$dash" ] || skip 'requires an installed Dash interpreter'
  run -0 "$TEST_PYTHON" - "$dash" "$DOTFILES_ROOT/home/dot_claude/executable_statusline.sh" <<'PY'
import json, re, subprocess, sys
payload = {'model': {'display_name': 'Fable 5'}, 'workspace': {'current_dir': '/tmp'}}
result = subprocess.run(sys.argv[1:], input=json.dumps(payload).encode(), capture_output=True, check=True, timeout=5)
assert result.stderr == b'', result.stderr
assert re.sub(rb'\x1b\[[0-9;]*m', b'', result.stdout) == b'Fable 5 | /tmp\n', result.stdout
PY
  assert_success
}
