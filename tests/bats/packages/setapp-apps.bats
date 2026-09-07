load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_after_22-setapp-apps.sh.tmpl
  render_template "$template" personal '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"

  shims="$HOME/.local/share/mise/shims"
  mkdir -p "$shims"
  cat > "$shims/setapp-cli" <<'STUB'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FIXTURE/setapp-cli.calls"
case "$1 ${2:-}" in
  # Default the fixture to a fully-installed machine so the happy path converges.
  "list ") cat "${TEST_SETAPP_INSTALLED:-$FIXTURE/applist.seen}" ;;
  "bundle install") cp "$4" "$FIXTURE/applist.seen"; exit "${TEST_SETAPP_CLI_RC:-0}" ;;
  *) printf 'unexpected setapp-cli call: %s\n' "$*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$shims/setapp-cli"
  : > "$FIXTURE/setapp-cli.calls"

  cat > "$FIXTURE/bin/launchctl" <<'STUB'
#!/bin/sh
set -eu
[ "${TEST_SETAPP_AGENT_LOADED:-1}" = 1 ]
STUB
  chmod +x "$FIXTURE/bin/launchctl"
}

@test "Setapp install hook is empty when the machine does not select Setapp" {
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/ci.sh"
  [ ! -s "$FIXTURE/ci.sh" ]
}

@test "Setapp install hook installs the rendered AppList and never uninstalls" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]

  run -0 cut -d' ' -f1-3 "$FIXTURE/setapp-cli.calls"
  assert_line --index 0 'bundle install --file'
  refute_output --partial cleanup
  refute_output --partial remove

  run -0 cat "$FIXTURE/applist.seen"
  assert_output - <<'APPLIST'
CleanShot X
iStat Menus
Maestri
Soulver
Yoink
APPLIST
}

@test "Setapp install hook warns when an app is still missing after the install" {
  # setapp-cli logs an unknown catalogue name to stderr and still exits 0.
  printf '%s\n' 'CleanShot X' 'Maestri' 'Soulver' 'Yoink' > "$FIXTURE/installed"
  TEST_SETAPP_INSTALLED="$FIXTURE/installed" run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'Setapp apps declared in packages.toml but still not installed:'* ]]
  [[ "$stderr" == *'iStat Menus'* ]]
  [[ "$stderr" != *'CleanShot X'* ]]
}

@test "Setapp install hook matches installed apps case-insensitively" {
  printf '%s\n' 'cleanshot x' 'istat menus' 'Maestri' 'Soulver' 'Yoink' > "$FIXTURE/installed"
  TEST_SETAPP_INSTALLED="$FIXTURE/installed" run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
}

@test "Setapp install hook warns and installs nothing when setapp-cli is missing" {
  rm "$shims/setapp-cli"
  run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'setapp-cli is not installed; skipping Setapp app installs.'* ]]
  [ ! -s "$FIXTURE/setapp-cli.calls" ]
}

@test "Setapp install hook warns and installs nothing when the Setapp agent is not loaded" {
  TEST_SETAPP_AGENT_LOADED=0 run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'the Setapp launch agent is not loaded; skipping Setapp app installs.'* ]]
  [ ! -s "$FIXTURE/setapp-cli.calls" ]
}

@test "Setapp install hook warns but does not fail the apply when the install fails" {
  TEST_SETAPP_CLI_RC=1 run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'Setapp app install failed; check that Setapp is signed in'* ]]
  run -0 cut -d' ' -f1-2 "$FIXTURE/setapp-cli.calls"
  refute_output --partial list
}
