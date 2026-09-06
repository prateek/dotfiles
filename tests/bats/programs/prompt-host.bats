load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/dot_config/zsh/lib/prompt.zsh.tmpl
  scenario="$DOTFILES_ROOT/tests/scenarios/programs/prompt-host.zsh"
}

@test "Pure host prefix color follows machine identity with a fallback for unknown types" {
  local item machine color
  for item in personal:108 homelab:109 work:167 vm:242; do
    machine="${item%:*}"
    color="${item#*:}"
    render_template "$template" "$machine" > "$FIXTURE/prompt.zsh"
    run_zsh 0 "$scenario" "$FIXTURE/prompt.zsh" color
    assert_success
    assert_output "$color"
    [ -z "$stderr" ]
  done
}

@test "Pure custom prefix shows the local host only when the built-in host prefix is absent" {
  render_template "$template" work > "$FIXTURE/prompt.zsh"
  run_zsh 0 "$scenario" "$FIXTURE/prompt.zsh" host
  assert_success
  assert_output ''
  [ -z "$stderr" ]
}
