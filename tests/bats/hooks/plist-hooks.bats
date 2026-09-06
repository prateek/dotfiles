# The loaded plist fixture assigns hook, pending, events, and quit_list.
# shellcheck disable=SC2154
load '../../support/common'
load '../../support/plist-hooks'

setup() { setup_hooks; }

@test "plist pre-hook refuses noninteractive writes over a running app" {
  pending_apps com.example.foo
  printf 'com.example.foo\n' > "$FIXTURE/running"
  run -1 bash "$hook" pre
  assert_failure 1
  assert_equal "$(cat "$pending")" com.example.foo
}

@test "plist pre-hook records changes for stopped apps and container preferences" {
  pending_apps com.example.foo
  printf ' M %s/Library/Containers/com.example.bar/Data/Library/Preferences/com.example.bar.plist\n' "$HOME" >> "$FIXTURE/status"
  run -0 bash "$hook" pre
  assert_success
  assert_equal "$(cat "$pending")" $'com.example.foo\ncom.example.bar'
}

@test "plist pre-hook with no changes leaves an empty pending list" {
  run -0 bash "$hook" pre
  assert_success
  [ ! -s "$pending" ]
}

@test "plist post-hook with empty or missing state has no app effects" {
  for state in missing empty; do
    if [[ "$state" == empty ]]; then : > "$pending"; fi
    run -0 bash "$hook" post
    assert_success
    [ ! -e "$pending" ]
    [ ! -s "$events" ]
  done
}

@test "plist post-hook nudges preferences once and relaunches only on opt-in" {
  for relaunch in 0 1; do
    : > "$events"
    printf 'com.example.foo\ncom.example.bar\n' > "$pending"
    run -0 env DOTFILES_RELAUNCH_AFTER_APPLY="$relaunch" bash "$hook" post
    assert_success
    [ ! -e "$pending" ]
    assert_equal "$(grep -c '^flush ' "$events")" 1
    if [[ "$relaunch" == 1 ]]; then
      assert_equal "$(grep '^open ' "$events")" $'open com.example.foo\nopen com.example.bar'
    else
      run -1 grep '^open ' "$events"
      assert_failure 1
    fi
  done
}

@test "plist hooks skip dry-run forms and preserve post state" {
  pending_apps com.example.foo
  printf 'com.example.foo\n' > "$FIXTURE/running"
  local args
  for args in 'chezmoi apply --dry-run' 'chezmoi apply --dry-run=true' \
    'chezmoi apply -n' 'chezmoi apply -nv' 'chezmoi apply -vn' \
    'chezmoi apply --dry-run=false -n'; do
    rm -f "$pending"
    run -0 env CHEZMOI_ARGS="$args" bash "$hook" pre
    assert_success
    [ ! -s "$pending" ]
    printf 'com.example.foo\n' > "$pending"
    run -0 env CHEZMOI_ARGS="$args" bash "$hook" post
    assert_success
    [ -s "$pending" ]
    [ ! -s "$events" ]
  done
}

@test "plist hooks honor explicit non-preview flags and ignore flags inside data" {
  pending_apps com.example.foo
  printf 'com.example.foo\n' > "$FIXTURE/running"
  local args
  for args in 'chezmoi apply --dry-run=false' 'chezmoi apply -v' \
    'chezmoi apply --override-data {"note":"words -n words"}' \
    'chezmoi apply -n --dry-run=false' 'chezmoi apply -n=false' \
    'chezmoi apply --override-data {"note":"words --dry-run words"}'; do
    rm -f "$pending"
    : > "$events"
    run -1 env CHEZMOI_ARGS="$args" bash "$hook" pre
    assert_failure 1
    [ -s "$pending" ]
    run -0 env CHEZMOI_ARGS="$args" bash "$hook" post
    assert_success
    assert_equal "$(cat "$events")" 'flush cfprefsd'
  done
}

@test "explicit plist skip avoids status queries and preserves pending post state" {
  rm "$FIXTURE/bin/chezmoi"
  cat > "$FIXTURE/bin/chezmoi" <<'STUB'
#!/bin/sh
printf 'unexpected status query\n' >> "$FIXTURE/events"
exit 99
STUB
  run -0 env DOTFILES_SKIP_PLIST_HOOKS=1 bash "$hook" pre
  assert_success
  [ ! -e "$pending" ]
  [ ! -s "$events" ]
  printf 'com.example.foo\n' > "$pending"
  run -0 env DOTFILES_SKIP_PLIST_HOOKS=1 bash "$hook" post
  assert_success
  [ -s "$pending" ]
  [ ! -s "$events" ]
}

@test "one terminal acceptance quits both apps and records them for relaunch" {
  pending_apps com.example.foo com.example.bar
  printf 'com.example.foo\ncom.example.bar\n' > "$FIXTURE/running"
  hook_dialogue ''
  assert_success
  assert_equal "$(cat "$events")" $'quit com.example.foo\nquit com.example.bar'
  assert_equal "$(cat "$quit_list")" $'com.example.foo\ncom.example.bar'
}

@test "declining the terminal prompt proceeds without quitting apps" {
  pending_apps com.example.foo com.example.bar
  printf 'com.example.foo\ncom.example.bar\n' > "$FIXTURE/running"
  hook_dialogue n
  assert_success
  [ ! -s "$events" ]
  [ ! -s "$quit_list" ]
  assert_equal "$(cat "$pending")" $'com.example.foo\ncom.example.bar'
}

@test "a stuck app is diagnosed and omitted from the relaunch list" {
  pending_apps com.example.foo com.example.bar
  printf 'com.example.foo\ncom.example.bar\n' > "$FIXTURE/running"
  printf 'com.example.bar\n' > "$FIXTURE/stuck"
  export DOTFILES_PLIST_QUIT_TIMEOUT_SECS=1
  hook_dialogue ''
  assert_success
  assert_equal "$(cat "$quit_list")" com.example.foo
  assert_regex "$(cat "$FIXTURE/transcript")" 'com.example.bar did not quit'
}

@test "post-hook relaunches successfully quit apps and removes both state files" {
  printf 'com.example.foo\ncom.example.bar\n' > "$pending"
  printf 'com.example.foo\n' > "$quit_list"
  run -0 bash "$hook" post
  assert_success
  assert_equal "$(cat "$events")" $'flush cfprefsd\nopen com.example.foo'
  [ ! -e "$pending" ]
  [ ! -e "$quit_list" ]
}

@test "post-hook deduplicates opt-in relaunches against apps it quit" {
  printf 'com.example.foo\ncom.example.bar\n' > "$pending"
  printf 'com.example.foo\n' > "$quit_list"
  run -0 env DOTFILES_RELAUNCH_AFTER_APPLY=1 bash "$hook" post
  assert_success
  assert_equal "$(grep '^open ' "$events")" $'open com.example.foo\nopen com.example.bar'
}

teardown() {
  if [[ ${BATS_TEST_COMPLETED:-} != 1 && -f "$FIXTURE/transcript" ]]; then
    cat "$FIXTURE/transcript" >&2
  fi
}
