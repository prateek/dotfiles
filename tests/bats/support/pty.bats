# Child-shell snippets and injection probes require literal arguments.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
}

teardown() {
  if [[ ${BATS_TEST_COMPLETED:-} != 1 && -f "$FIXTURE/transcript" ]]; then
    cat "$FIXTURE/transcript" >&2
  fi
}

@test "PTY timeout retains a transcript and releases the child" {
  run_zsh 124 "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/transcript" '[Y/n]' '' /bin/zsh -f -c 'print -r -- $$ > "$FIXTURE/actual-child"; print -r -- waiting; read answer'
  assert_failure 124
  assert_regex "$stderr" 'prompt deadline exceeded'
  run -0 cat "$FIXTURE/transcript"
  assert_output --partial waiting
  run -1 kill -0 "$(cat "$FIXTURE/transcript.pid")"
  assert_failure
  run -1 kill -0 "$(cat "$FIXTURE/actual-child")"
  assert_failure
}

@test "PTY command setup failure retains diagnostics and releases the terminal" {
  run_zsh 1 "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/transcript" '[Y/n]' '' /bin/zsh -f -c 'print -u2 -- setup-failed; exit 17'
  assert_failure 1
  assert_regex "$stderr" 'command exited before prompt'
  assert_regex "$(cat "$FIXTURE/transcript")" 'setup-failed'
  run -1 kill -0 "$(cat "$FIXTURE/transcript.pid")"
  assert_failure 1
}

@test "PTY cancellation releases the child before fixture cleanup" {
  run -0 /bin/zsh -f "$DOTFILES_ROOT/tests/scenarios/support/pty-cancel.zsh" "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh"
  assert_success
}

@test "PTY preserves literal arguments and nonzero command status" {
  run -23 /bin/zsh -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/transcript" '[Y/n]' 'n' /bin/zsh -f -c 'printf "%s\n" "$@" > "$FIXTURE/args"; printf "[Y/n]"; read answer; exit 23' _ 'space ; $(touch injected) *'
  assert_failure 23
  run -0 cat "$FIXTURE/args"
  assert_output 'space ; $(touch injected) *'
  [[ ! -e injected ]]
}

@test "PTY interrupt releases its child" {
  run -0 /bin/zsh -f "$DOTFILES_ROOT/tests/scenarios/support/pty-cancel.zsh" "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" INT 130
  assert_success
}
