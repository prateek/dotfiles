load '../../support/common'

setup() {
  claude_binary="$(command -v claude || true)"
  setup_fixture
}

# bats test_tags=host
@test "console constants match the recorded Claude build and producer fragments" {
  [[ -n "$claude_binary" ]] || skip 'requires the recorded native Claude build'
  run -0 "$TEST_PYTHON" -B "$DOTFILES_ROOT/tests/scenarios/agents/console-native.py" "$claude_binary" ConsoleNativeTests.test_constant_provenance
  assert_success
}

# bats test_tags=host
@test "console renders and dry-runs an unchanged plan against the recorded Claude build" {
  [[ -n "$claude_binary" ]] || skip 'requires the recorded native Claude build'
  run -0 "$TEST_PYTHON" -B "$DOTFILES_ROOT/tests/scenarios/agents/console-native.py" "$claude_binary" ConsoleNativeTests.test_render_apply_cycle
  assert_success
}
