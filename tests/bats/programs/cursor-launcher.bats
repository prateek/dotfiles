# Injection probes must remain literal arguments.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
  cat > "$FIXTURE/bin/cursor-agent" <<'STUB'
#!/bin/sh
printf '%s\n' "$@"
STUB
  chmod +x "$FIXTURE/bin/cursor-agent"
}

@test "Cursor yoloa selects Run Everything and the required model with literal arguments" {
  run_zsh 0 "$DOTFILES_ROOT/tests/scenarios/programs/cursor-launcher.zsh" 'do the thing' 'space ; $(touch injected) *'
  assert_success
  assert_output $'--yolo\n--model\ngpt-5.6-sol-xhigh-fast\ndo the thing\nspace ; $(touch injected) *'
  [ -z "$stderr" ]
  [ ! -e injected ]
}
