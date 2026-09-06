load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_onchange_after_12-gh-extensions.sh.tmpl
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
  cat > "$FIXTURE/bin/gh" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/gh.calls"
exit "${TEST_GH_STATUS:-0}"
STUB
  chmod +x "$FIXTURE/bin/gh"
  : > "$FIXTURE/gh.calls"
}

@test "GitHub extension installation warns and continues when gh is absent" {
  run_without_reporting_fds 0 env PATH=/usr/bin:/bin "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'gh is not installed; skipping gh extension install.'* ]]
  [ ! -s "$FIXTURE/gh.calls" ]
}

@test "GitHub extension installation installs the selected extension then skips its installed directory" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [ "$(cat "$FIXTURE/gh.calls")" = 'extension install enthus-appdev/gh-attach' ]
  mkdir -p "$XDG_DATA_HOME/gh/extensions/gh-attach"
  : > "$FIXTURE/gh.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'gh extension already installed: enthus-appdev/gh-attach'
  [ -z "$stderr" ]
  [ ! -s "$FIXTURE/gh.calls" ]
}

@test "GitHub extension installation reports failure without aborting apply" {
  export TEST_GH_STATUS=1
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'gh extension install failed for enthus-appdev/gh-attach; retry with: gh extension install enthus-appdev/gh-attach'* ]]
  [ "$(cat "$FIXTURE/gh.calls")" = 'extension install enthus-appdev/gh-attach' ]
}

@test "GitHub extension installation with no selected groups is a no-op on both Bash interpreters" {
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true,"groups":[]}}' > "$FIXTURE/empty.sh"
  local interpreter
  for interpreter in "$BASH" /bin/bash; do
    run_without_reporting_fds 0 "$interpreter" "$FIXTURE/empty.sh"
    assert_success
    assert_output ''
    [ -z "$stderr" ]
    [ ! -s "$FIXTURE/gh.calls" ]
  done
}
