load '../../support/common'

setup() {
  kanata="$(command -v kanata || true)"
  setup_fixture
}

# bats test_tags=host
@test "Kanata accepts the managed keyboard configuration" {
  [ -n "$kanata" ] || skip 'requires an installed Kanata binary'
  run -0 "$kanata" --check --cfg "$DOTFILES_ROOT/home/dot_config/kanata/kanata.kbd"
  assert_success
}
