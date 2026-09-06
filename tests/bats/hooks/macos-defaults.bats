load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset DOTFILES_SKIP_SPOTLIGHT_REINDEX
  export DOTFILES_SKIP_LSREGISTER=1 DOTFILES_SKIP_APP_RESTART=1
  local command
  for command in defaults osascript systemsetup pmset launchctl chflags mdutil; do
    cat > "$FIXTURE/bin/$command" <<'STUB'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$FIXTURE/defaults.calls"
STUB
    chmod +x "$FIXTURE/bin/$command"
  done
  cat > "$FIXTURE/bin/uname" <<'STUB'
#!/bin/sh
printf 'Darwin\n'
STUB
  cat > "$FIXTURE/bin/id" <<'STUB'
#!/bin/sh
if [ "$1" = -u ]; then printf '0\n'; else exec /usr/bin/id "$@"; fi
STUB
  cat > "$FIXTURE/bin/sudo" <<'STUB'
#!/bin/sh
printf 'sudo %s\n' "$*" >> "$FIXTURE/defaults.calls"
case "$*" in '-v'|'-n true') exit 42 ;; esac
STUB
  cat > "$FIXTURE/bin/killall" <<'STUB'
#!/bin/sh
printf 'killall %s\n' "$*" >> "$FIXTURE/defaults.calls"
if [ "$1" = mds ]; then
  printf 'No matching processes belonging to you were found\n' >&2
  exit 1
fi
STUB
  chmod +x "$FIXTURE/bin/uname" "$FIXTURE/bin/id" "$FIXTURE/bin/sudo" "$FIXTURE/bin/killall"
  mkdir -p "$HOME/Library/Preferences"
  "$TEST_PYTHON" - "$HOME/Library/Preferences/com.apple.symbolichotkeys.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as stream:
    plistlib.dump({}, stream)
PY
  render_template home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl personal \
    '{"machines_local":{"run_install_scripts":true,"apply_macos_defaults":true}}' > "$FIXTURE/defaults.sh"
}

@test "macOS defaults reuse root access, honor app-restart opt-out, and reindex Spotlight despite an absent mds process" {
  run_bash 0 "$FIXTURE/defaults.sh"
  assert_success
  [ -z "$stderr" ]
  local calls
  calls=$'\n'"$(cat "$FIXTURE/defaults.calls")"$'\n'
  [[ "$calls" != *$'\nsudo -v\n'* && "$calls" != *$'\nsudo -n true\n'* ]]
  [[ "$calls" != *$'\nkillall -q Activity Monitor Dock Finder Google Chrome Messages Safari SystemUIServer\n'* ]]
  [[ "$calls" == *$'\nkillall mds\n'* ]]
  [[ "$calls" == *$'\nsudo mdutil -i on /\n'* ]]
  [[ "$calls" == *$'\nsudo mdutil -E /\n'* ]]
}
