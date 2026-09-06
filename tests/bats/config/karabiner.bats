load '../../support/common'
load '../../support/chezmoi'

setup() {
  goku_cli="$(command -v goku || true)"
  setup_fixture
  export XDG_CONFIG_HOME="$HOME/.config"
}

# bats test_tags=host
@test "Installed Goku compiles device-scoped overlays, sticky mouse mode, and real Shift with F18 taps" {
  [ -n "$goku_cli" ] || skip 'requires the installed Goku toolchain'
  mkdir -p "$XDG_CONFIG_HOME/karabiner"
  printf '{"profiles":[{"name":"Default","complex_modifications":{"rules":[]}}]}\n' > "$FIXTURE/input.json"
  cp "$FIXTURE/input.json" "$XDG_CONFIG_HOME/karabiner/karabiner.json"
  render_template home/dot_config/karabiner.edn.tmpl personal > "$FIXTURE/karabiner.edn"
  run_without_reporting_fds 0 "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/config/karabiner.py" \
    "$goku_cli" "$FIXTURE/karabiner.edn"
  assert_success
  [ -z "$stderr" ]
  run -0 cmp "$FIXTURE/input.json" "$XDG_CONFIG_HOME/karabiner/karabiner.json"
  assert_success
}
