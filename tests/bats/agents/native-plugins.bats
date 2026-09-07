load '../../support/common'

setup() {
  claude_cli="$(command -v claude || true)"
  codex_cli="$(command -v codex || true)"
  setup_fixture
}

# bats test_tags=host
@test "Native Claude and Codex install, update, relocate, roll back, and follow a Git marketplace" {
  [ -n "$claude_cli" ] || skip 'requires an installed Claude CLI'
  [ -n "$codex_cli" ] || skip 'requires an installed Codex CLI'
  run_without_reporting_fds 0 "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/agents/native-marketplace.py" \
    "$claude_cli" "$codex_cli" "$FIXTURE/native"
  assert_success
  assert_output --partial 'artifact-root Git distribution passed'
}
