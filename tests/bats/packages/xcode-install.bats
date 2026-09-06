load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset DOTFILES_INSTALL_XCODE
  template=home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl
  render_template "$template" homelab '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
  mkdir -p "$HOME/.agents/state"
  printf '{"xcode_version":"26.3"}\n' > "$HOME/.agents/state/ios-triple.json"
  ln -s "$(command -v jq)" "$FIXTURE/bin/jq"
  cat > "$FIXTURE/bin/uname" <<'STUB'
#!/bin/sh
printf 'Darwin\n'
STUB
  cat > "$FIXTURE/bin/id" <<'STUB'
#!/bin/sh
if [ "$1" = -u ]; then printf '0\n'; else exec /usr/bin/id "$@"; fi
STUB
  cat > "$FIXTURE/bin/xcodes" <<'STUB'
#!/bin/sh
case "$*" in
  'installed 26.3') [ "${TEST_XCODE_PRESENT:-0}" = 1 ] ;;
  'install 26.3 --experimental-unxip'|'select 26.3')
    printf 'xcodes %s\n' "$*" >> "$FIXTURE/xcode.calls" ;;
  *) printf 'unexpected xcodes call: %s\n' "$*" >&2; exit 1 ;;
esac
STUB
  cat > "$FIXTURE/bin/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$FIXTURE/xcode.calls"
STUB
  cat > "$FIXTURE/bin/sudo" <<'STUB'
#!/bin/sh
printf 'sudo %s\n' "$*" >> "$FIXTURE/xcode.calls"
STUB
  chmod +x "$FIXTURE/bin/uname" "$FIXTURE/bin/id" "$FIXTURE/bin/xcodes" "$FIXTURE/bin/brew" "$FIXTURE/bin/sudo"
  : > "$FIXTURE/xcode.calls"
}

@test "Xcode setup skips a machine without the Apple development group" {
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/ci.sh"
  run_bash 0 "$FIXTURE/ci.sh"
  assert_success
  assert_output --partial 'no apple-development group'
  [ -z "$stderr" ]
  [ ! -s "$FIXTURE/xcode.calls" ]
}

@test "Xcode setup refuses a missing installation during an unforced noninteractive apply" {
  run_bash 1 "$FIXTURE/install.sh" < /dev/null
  assert_failure 1
  [[ "$stderr" == *'Xcode 26.3 is not installed and this apply is non-interactive.'* ]]
  [ ! -s "$FIXTURE/xcode.calls" ]
}

@test "Xcode forced setup installs and selects the pin before accepting licenses and installing dependent tools" {
  export DOTFILES_INSTALL_XCODE=true
  run_bash 0 "$FIXTURE/install.sh" < /dev/null
  assert_success
  [[ "$stderr" == *'Installing Xcode 26.3 through xcodes'* ]]
  local calls entry
  calls="$(cat "$FIXTURE/xcode.calls")"
  [[ "$calls" == $'xcodes install 26.3 --experimental-unxip\nxcodes select 26.3\n'* ]]
  for entry in 'sudo xcodebuild -license accept' 'sudo xcodebuild -runFirstLaunch' \
    'brew install facebook/fb/idb-companion' 'brew install swiftlint'; do
    [[ "$calls" == *"$entry"* ]]
  done
}

@test "Xcode setup reuses an installed pin without downloading it" {
  export TEST_XCODE_PRESENT=1
  run_bash 0 "$FIXTURE/install.sh" < /dev/null
  assert_success
  [ -z "$stderr" ]
  local calls
  calls="$(cat "$FIXTURE/xcode.calls")"
  [[ "$calls" != *'xcodes install '* ]]
  [[ "$calls" == *'xcodes select 26.3'* ]]
}
