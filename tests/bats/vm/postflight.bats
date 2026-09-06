load '../../support/common'

setup() {
  setup_fixture
  unset DOTFILES_TEST_FINDER_SHOW_HIDDEN
  postflight="$DOTFILES_ROOT/scripts/vm/postflight-macos.sh"
  cp "$DOTFILES_ROOT/tests/scenarios/vm/postflight-defaults.sh" "$FIXTURE/bin/defaults"
  cat > "$FIXTURE/bin/chezmoi" <<'STUB'
#!/bin/sh
[ "$*" = '--no-tty status' ] || exit 97
if [ -n "${TEST_CHEZMOI_DRIFT:-}" ]; then
  printf ' M /Users/test/.zshrc\n'
fi
exit 0
STUB
  chmod +x "$FIXTURE/bin/defaults" "$FIXTURE/bin/chezmoi"
  unset TEST_CHEZMOI_DRIFT
}

assert_summary() {
  run -0 "$TEST_PYTHON" - "$output" "$@" <<'PY'
import sys
lines = sys.argv[1].splitlines()
results = [line.split('|', 4) for line in lines if line.startswith('RESULT|macos|')]
assert results, lines
assert all(row[2] in ('PASS', 'FAIL') for row in results), results
failed = [row[3] for row in results if row[2] == 'FAIL']
assert failed == sys.argv[2:], failed
summaries = [line for line in lines if line.startswith('SUMMARY|macos|')]
assert summaries == [f'SUMMARY|macos|passed={len(results)-len(failed)}|failed={len(failed)}'], summaries
PY
  assert_success
}

@test "macOS postflight reports successful system app status and hook checks consistently" {
  run_bash 0 "$postflight"
  assert_success
  [ -z "$stderr" ]
  assert_output --partial 'RESULT|macos|PASS|key_repeat|'
  assert_output --partial 'RESULT|macos|PASS|finder_show_hidden|'
  assert_output --partial 'RESULT|macos|PASS|chezmoi_status|empty'
  assert_output --partial 'RESULT|macos|PASS|hook_state|absent'
  assert_output --partial 'RESULT|macos|PASS|thaw_section_divider|'
  assert_output --partial 'RESULT|macos|PASS|voiceink_model|'
  assert_output --partial 'RESULT|macos|PASS|tailscale_hide_dock|'
  assert_summary
}

@test "macOS postflight identifies hidden-file preference drift" {
  export DOTFILES_TEST_FINDER_SHOW_HIDDEN=0
  run_bash 1 "$postflight"
  assert_failure 1
  assert_output --partial 'RESULT|macos|FAIL|finder_show_hidden|'
  assert_summary finder_show_hidden
}

@test "macOS postflight reports leftover apply-hook state" {
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  printf 'com.example.foo\n' > "$XDG_STATE_HOME/dotfiles/plist-pending.txt"
  run_bash 1 "$postflight"
  assert_failure 1
  assert_output --partial 'RESULT|macos|FAIL|hook_state|leftover:'
  assert_summary hook_state
}

@test "macOS postflight surfaces nonempty chezmoi status as drift" {
  export TEST_CHEZMOI_DRIFT=1
  run_bash 1 "$postflight"
  assert_failure 1
  assert_output --partial 'RESULT|macos|FAIL|chezmoi_status| M /Users/test/.zshrc'
  assert_summary chezmoi_status
}
