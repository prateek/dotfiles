load '../../support/common'

setup() {
  setup_fixture
  local name
  for name in ${!DOTFILES_BANNER_@}; do
    unset "$name"
  done
  unset SSH_TTY SSH_CONNECTION
  export XDG_CONFIG_HOME="$HOME/.config" TERM=xterm-256color NO_COLOR=1
  export BANNER_ROOT="$XDG_CONFIG_HOME/dotfiles/shell-banner"
  export LOADER="$XDG_CONFIG_HOME/zsh/extra/shell-banner.zsh"
  export DOTFILES_BANNER_STATE_DIR="$FIXTURE/banner-state"
  export DOTFILES_BANNER_SOURCES=chezmoi
  : > "$FIXTURE/chezmoi.toml"
  run_without_reporting_fds 0 env DOTFILES_SKIP_PLIST_HOOKS=1 chezmoi \
    --source "$DOTFILES_ROOT" --destination "$HOME" \
    --config "$FIXTURE/chezmoi.toml" --cache "$XDG_CACHE_HOME" \
    --persistent-state "$FIXTURE/chezmoi-state.boltdb" --no-tty \
    --override-data '{"machine_type":"ci","chezmoi":{"hostname":"dotfiles-test-host"}}' \
    apply --force --exclude=scripts --parent-dirs "$BANNER_ROOT" "$LOADER" \
    "$XDG_CONFIG_HOME/fastfetch/config.jsonc"
  assert_success
  [ -z "$stderr" ]
}

@test "shell banner returns cached output while its refresh is blocked, then publishes the new row" {
  run_without_reporting_fds 0 "$TEST_PYTHON" \
    "$DOTFILES_ROOT/tests/scenarios/shell/shell-banner-background.py"
  assert_success
  assert_output 'OK shell banner background refresh'
  [ -z "$stderr" ]
}
