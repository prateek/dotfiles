load '../../support/common'

setup() {
  claude_cli="$(command -v claude || true)"
  codex_cli="$(command -v codex || true)"
  setup_fixture
  plugins="$FIXTURE/.agents/plugins"
}

render_plugins() {
  run_without_reporting_fds 0 "$DOTFILES_ROOT/.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace" \
    --plugins-root "$plugins" --skip-config-templates
  assert_success
  [[ "$stderr" == *'codex has no mapping for evals; that payload is claude-only'* ]]
  [[ "$stderr" == *'codex has no mapping for hooks; that payload is claude-only'* ]]
}

# bats test_tags=host
@test "Installed Claude validates the rendered plugin marketplace" {
  [ -n "$claude_cli" ] || skip 'requires an installed Claude CLI'
  render_plugins
  run_without_reporting_fds 0 "$claude_cli" plugin validate "$plugins"
  assert_success
  assert_output --partial 'Validation passed'
}

# bats test_tags=host
@test "Installed Codex app server reads skills from the rendered marketplace" {
  [ -n "$codex_cli" ] || skip 'requires an installed Codex CLI'
  render_plugins
  run_without_reporting_fds 0 "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/agents/codex-plugin-read.py" \
    "$codex_cli" "$plugins/marketplace.json"
  assert_success
  [ -z "$stderr" ]
}
