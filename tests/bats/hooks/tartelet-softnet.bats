# Injection probes must remain literal arguments.
# shellcheck disable=SC2016
load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_after_18-tartelet-tart-softnet-wrapper.sh.tmpl
  export TEST_BREW_PREFIX="$FIXTURE/brew"
  target="$TEST_BREW_PREFIX/bin/tart"
  real="$TEST_BREW_PREFIX/opt/tart/bin/tart"
  mkdir -p "${target%/*}" "${real%/*}"
  cat > "$real" <<'STUB'
#!/bin/sh
printf '%s\n' "$@"
STUB
  chmod +x "$real"
  cat > "$FIXTURE/bin/sudo" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "$FIXTURE/sudo.args"
exit "${TEST_SUDO_STATUS:-0}"
STUB
  cat > "$FIXTURE/bin/uname" <<'STUB'
#!/bin/sh
printf 'Darwin\n'
STUB
  chmod +x "$FIXTURE/bin/sudo" "$FIXTURE/bin/uname"
  render_template "$template" homelab > "$FIXTURE/rendered.sh"
  "$TEST_PYTHON" - "$FIXTURE/rendered.sh" "$FIXTURE/install.sh" <<'PY'
import os, pathlib, shlex, sys
text = pathlib.Path(sys.argv[1]).read_text()
assert '/opt/homebrew/bin/tart' in text
assert '/opt/homebrew/opt/tart/bin/tart' in text
text = text.replace('/opt/homebrew/bin/softnet', shlex.quote(os.environ['TEST_BREW_PREFIX'] + '/bin/softnet'))
pathlib.Path(sys.argv[2]).write_text(text.replace('/opt/homebrew', os.environ['TEST_BREW_PREFIX']))
PY
}

@test "Tartelet replaces the brew symlink with an executable wrapper and preserves an identical installation" {
  ln -s "$real" "$target"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'replaced: brew symlink'
  [ -z "$stderr" ]
  [ -f "$target" ] && [ ! -L "$target" ] && [ -x "$target" ]
  run -0 "$TEST_PYTHON" - "$target" <<'PY'
import pathlib, stat, sys
assert stat.S_IMODE(pathlib.Path(sys.argv[1]).stat().st_mode) == 0o755
PY
  assert_success
  local before
  before="$("$TEST_PYTHON" -c 'import os,sys; s=os.stat(sys.argv[1]); print(s.st_ino,s.st_mtime_ns)' "$target")"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ "$before" = "$("$TEST_PYTHON" -c 'import os,sys; s=os.stat(sys.argv[1]); print(s.st_ino,s.st_mtime_ns)' "$target")" ]
}

@test "Tartelet wrapper adds softnet only for run without an explicit network mode and forwards literal arguments" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  run -0 "$target" run 'VM ; $(touch injected) *'
  assert_success
  assert_output $'run\n--net-softnet\nVM ; $(touch injected) *'
  run -0 "$target" run --net-bridged=en0 'VM name'
  assert_success
  assert_output $'run\n--net-bridged=en0\nVM name'
  run -0 "$target" list --format json
  assert_success
  assert_output $'list\n--format\njson'
  [ ! -e injected ]
}

@test "Tartelet reports an absent sudo grant without failing installation" {
  export TEST_SUDO_STATUS=1
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'softnet sudo grant missing'* ]]
  [ -x "$target" ]
  printf '%s\n' -n "$TEST_BREW_PREFIX/bin/softnet" --help > "$FIXTURE/expected.args"
  run -0 cmp "$FIXTURE/expected.args" "$FIXTURE/sudo.args"
  assert_success
}

@test "Tartelet does not install a wrapper when the real Tart binary is absent" {
  rm "$real"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'tart not installed at'* ]]
  [ ! -e "$target" ]
  [ ! -e "$FIXTURE/sudo.args" ]
}

@test "Tartelet personal wrapper render is empty" {
  render_template "$template" personal > "$FIXTURE/personal.sh"
  [ ! -s "$FIXTURE/personal.sh" ]
}
