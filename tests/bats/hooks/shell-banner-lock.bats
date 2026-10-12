load '../../support/common'

setup() { setup_fixture; }

@test "concurrent stale-lock reclamation grants only one source owner" {
  run_without_reporting_fds 0 "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/shell/shell-banner-lock.py"
  assert_success
  assert_output 'one refresh owner'
  [ -z "$stderr" ]
}
