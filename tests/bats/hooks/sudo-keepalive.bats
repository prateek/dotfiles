# Child-shell snippets expand their own variables.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
  cp "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh" "$FIXTURE/script_lib.sh"
  scenario="$DOTFILES_ROOT/tests/scenarios/hooks/sudo-lifecycle.bash"
  export DOTFILES_ELEVATION_METHOD=none
  : > "$FIXTURE/sudo.log"
  cat > "$FIXTURE/bin/sudo" <<'STUB'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FIXTURE/sudo.log"
case "$*" in
  '-n -v') [ -e "$FIXTURE/warmed" ] ;;
  '-v') : > "$FIXTURE/warmed" ;;
  '-k') rm -f "$FIXTURE/warmed" ;;
  *) exit 99 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/sudo"
}

@test "sudo start reuses a cold validation and stop invalidates it once" {
  run_bash 0 "$scenario" reuse
  assert_success
  run -0 grep -cx -- '-v' "$FIXTURE/sudo.log"
  assert_output 1
  run -0 grep -cx -- '-k' "$FIXTURE/sudo.log"
  assert_output 1
  [ ! -e "$FIXTURE/warmed" ]
}

@test "sudo stop preserves a preexisting credential without prompting" {
  : > "$FIXTURE/warmed"
  run_bash 0 "$scenario" reuse
  assert_success
  run -1 grep -Ex -- '-v|-k' "$FIXTURE/sudo.log"
  assert_failure 1
  [ -e "$FIXTURE/warmed" ]
}

@test "separate managed scripts share one helper through the chezmoi parent" {
  run_bash 0 "$scenario" shared
  assert_success
  run -0 grep -cx -- '-v' "$FIXTURE/sudo.log"
  assert_output 1
  run -0 grep -cx -- '-k' "$FIXTURE/sudo.log"
  assert_output 1
}

@test "sudo start survives an ancestor disappearing during parent lookup" {
  cat > "$FIXTURE/bin/ps" <<'STUB'
#!/bin/sh
if [ "$*" = "-o ppid= -p $DOTFILES_TEST_SELF_PID" ]; then
  printf '%s\n' "$DOTFILES_TEST_PARENT_PID"
else
  exit 1
fi
STUB
  chmod +x "$FIXTURE/bin/ps"
  run_bash 0 "$scenario" race
  assert_success
}

@test "sudo replaces stale or missing parent state and preserves warm credentials" {
  local mode
  for mode in stale missing; do
    : > "$FIXTURE/sudo.log"
    : > "$FIXTURE/warmed"
    run_bash 0 "$scenario" "$mode"
    assert_success
    run -1 grep -Ex -- '-v|-k' "$FIXTURE/sudo.log"
    assert_failure 1
    [ -e "$FIXTURE/warmed" ]
  done
}

@test "sudo helper exits and removes state after its parent exits" {
  run_zsh 0 "$DOTFILES_ROOT/tests/scenarios/hooks/sudo-parent-exit.zsh"
  assert_success
  run -1 kill -0 "$(cat "$FIXTURE/helper-pid")"
  assert_failure 1
  run -0 grep -cx -- '-v' "$FIXTURE/sudo.log"
  assert_output 1
  run -0 grep -cx -- '-k' "$FIXTURE/sudo.log"
  assert_output 1
}

elevation_fixture() {
  mkdir -p "$HOME/.config/dotfiles"
  printf 'DOTFILES_ELEVATION_METHOD=%s\nDOTFILES_JAMF_POLICY_ID=4242\n' "$1" > "$HOME/.config/dotfiles/elevation.sh"
  cat > "$FIXTURE/bin/open" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" >> "$FIXTURE/open.log"
: > "$FIXTURE/admin"
STUB
  cat > "$FIXTURE/bin/id" <<'STUB'
#!/bin/sh
if [ "$*" = '-Gn' ]; then
  if [ -e "$FIXTURE/admin" ]; then printf 'staff admin\n'; else printf 'staff\n'; fi
else
  exec /usr/bin/id "$@"
fi
STUB
  chmod +x "$FIXTURE/bin/open" "$FIXTURE/bin/id"
}

@test "Jamf elevation opens the configured policy once and observes admin membership" {
  elevation_fixture jamf-self-service
  run_bash 0 -c 'source "$FIXTURE/script_lib.sh"; dotfiles_admin_elevate'
  assert_success
  assert_equal "$(cat "$FIXTURE/open.log")" 'jamfselfservice://content?entity=policy&action=execute&id=4242'
}

@test "existing admin membership and explicit elevation opt-out launch no app" {
  elevation_fixture jamf-self-service
  : > "$FIXTURE/admin"
  run_bash 0 -c 'source "$FIXTURE/script_lib.sh"; dotfiles_admin_elevate'
  assert_success
  [ ! -e "$FIXTURE/open.log" ]
  rm "$FIXTURE/admin"
  elevation_fixture none
  run_bash 0 -c 'source "$FIXTURE/script_lib.sh"; dotfiles_admin_elevate'
  assert_success
  [ ! -e "$FIXTURE/open.log" ]
}
