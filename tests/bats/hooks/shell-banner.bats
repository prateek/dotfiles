load '../../support/common'

setup() { setup_fixture; }

@test "shell banner renders cached source rows and preserves refresh isolation, permissions, TTL, and locks" {
  run_zsh 0 "$DOTFILES_ROOT/tests/shell-banner.zsh"
  assert_success
  assert_output --partial 'OK shell-banner'
  [ -z "$stderr" ]
}
