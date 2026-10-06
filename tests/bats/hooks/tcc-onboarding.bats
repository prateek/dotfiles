load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset CI SSH_CONNECTION SSH_TTY
  export events="$FIXTURE/events"
  : > "$events"
  mkdir -p "$FIXTURE/repo/home" "$FIXTURE/repo/scripts/macos" "$HOME/Applications/Dotfiles Permissions.app/Contents/MacOS"
  cat > "$FIXTURE/repo/scripts/macos/install-tcc-onboarding" <<'SH'
#!/bin/bash
printf 'install\n' >> "$events"
printf '%s\n' "$HOME/Applications/Dotfiles Permissions.app"
exit "${INSTALL_STATUS:-0}"
SH
  cat > "$HOME/Applications/Dotfiles Permissions.app/Contents/MacOS/DotfilesPermissions" <<'SH'
#!/bin/bash
printf 'validate %s\n' "$*" >> "$events"
exit "${VALIDATE_STATUS:-0}"
SH
  cat > "$FIXTURE/bin/open" <<'SH'
#!/bin/bash
printf 'open %s\n' "$*" >> "$events"
exit "${OPEN_STATUS:-0}"
SH
  cat > "$FIXTURE/bin/stat" <<'SH'
#!/bin/bash
if [[ "$*" == '-f %u /dev/console' ]]; then printf '%s\n' "${CONSOLE_UID:-$(id -u)}"; else /usr/bin/stat "$@"; fi
SH
  chmod +x "$FIXTURE/repo/scripts/macos/install-tcc-onboarding" "$HOME/Applications/Dotfiles Permissions.app/Contents/MacOS/DotfilesPermissions" "$FIXTURE/bin/open" "$FIXTURE/bin/stat"
  render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl personal '{"machines_local":{"tcc_onboarding":true}}' > "$FIXTURE/rendered"
  "$TEST_PYTHON" - "$FIXTURE/rendered" "$FIXTURE/hook" "$DOTFILES_ROOT" "$FIXTURE/repo" <<'PY'
from pathlib import Path
import sys
source, target, real, fixture = sys.argv[1:]
Path(target).write_text(Path(source).read_text().replace(real + '/home/../scripts/macos', fixture + '/scripts/macos'))
PY
  cp "$DOTFILES_ROOT/scripts/macos/tcc-onboarding/Info.plist" "$HOME/Applications/Dotfiles Permissions.app/Contents/Info.plist"
  hook="$FIXTURE/hook"
}

@test "permission hook is opt-in and respects install and OS gates" {
  local machine
  for machine in personal work homelab ci devbox; do
    run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl "$machine"
    assert_output ''
  done
  run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl personal '{"machines_local":{"tcc_onboarding":true,"run_install_scripts":false}}'
  assert_output ''
  run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl devbox '{"machines_local":{"tcc_onboarding":true}}'
  assert_output ''
}

@test "headless permission apply validates and prints resume without launching" {
  run_bash 0 "$hook"
  assert_output --partial 'Review permissions later:'
  assert_equal "$(cat "$events")" $'install\nvalidate --validate '"$HOME/.config/dotfiles/tcc.json"
}

@test "terminal permission prompt accepts yes and preserves paths with spaces" {
  run -0 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' 'y' bash "$hook"
  assert_success
  run -0 rg '^open ' "$events"
  local encoded_manifest
  encoded_manifest=$("$TEST_PYTHON" - "$HOME/.config/dotfiles/tcc.json" <<'PYTEST'
from urllib.parse import quote
import sys
print(quote(sys.argv[1], safe='/'))
PYTEST
)
  assert_output "open -g -a $HOME/Applications/Dotfiles Permissions.app dotfiles-permissions://reconcile?manifest=$encoded_manifest --args --reconcile --manifest $HOME/.config/dotfiles/tcc.json"
}

@test "terminal permission prompt defaults to later and never launches on no" {
  local answer
  for answer in '' n; do
    : > "$events"
    run -0 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' "$answer" bash "$hook"
    assert_success
    run -1 rg '^open ' "$events"
    assert_failure 1
  done
}

@test "permission hook keeps unattended contexts silent even with a terminal" {
  local setting
  for setting in 'CI=true' 'SSH_CONNECTION=remote' 'CONSOLE_UID=99999'; do
    : > "$events"
    run -0 env "$setting" "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[complete]' '' bash -c 'bash "$1"; printf "[complete]"; read -r answer' _ "$hook"
    assert_success
    run -0 rg 'Review permissions later:' "$FIXTURE/pty"
    run -1 rg '^open ' "$events"
    assert_failure 1
  done
}

@test "permission hook reports installation and manifest errors but tolerates deferred updates" {
  run -1 env INSTALL_STATUS=1 bash "$hook"
  assert_failure 1
  run -1 env VALIDATE_STATUS=1 bash "$hook"
  assert_failure 1
  : > "$events"
  run -0 env INSTALL_STATUS=75 bash "$hook"
  assert_equal "$(cat "$events")" $'install\nvalidate --validate '"$HOME/.config/dotfiles/tcc.json"
}

@test "permission GUI launch failure gives recovery without failing apply" {
  run -0 env OPEN_STATUS=1 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' 'y' bash "$hook"
  run -0 rg 'Could not open|Review permissions later' "$FIXTURE/pty"
  assert_success
}

@test "missing toolchain skips helper without failing apply or launching" {
  run -0 env INSTALL_STATUS=69 bash "$hook"
  assert_output --partial 'System Settings'
  assert_equal "$(cat "$events")" install
}

@test "deferred update still offers onboarding with the existing app" {
  run -0 env INSTALL_STATUS=75 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' 'y' bash "$hook"
  run -0 rg '^open ' "$events"
  assert_output --partial 'dotfiles-permissions://reconcile?manifest='
  run -0 rg 'quit it' "$FIXTURE/pty"
}

@test "concurrent install reports retry without prompting or validating" {
  run -0 env INSTALL_STATUS=73 bash "$hook"
  assert_output --partial 'already in progress'
  assert_equal "$(cat "$events")" install
}

@test "reconcile URL encodes path separators independently of reserved characters" {
  local previous_home="$HOME"
  export HOME="$FIXTURE/User Space & ✓"
  mkdir -p "$HOME/Applications"
  cp -R "$previous_home/Applications/Dotfiles Permissions.app" "$HOME/Applications/"
  "$TEST_PYTHON" - "$hook" "$previous_home" "$HOME" <<'PYTEST'
from pathlib import Path
import sys
p=Path(sys.argv[1]); p.write_text(p.read_text().replace(sys.argv[2], sys.argv[3]))
PYTEST
  run -0 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' 'y' bash "$hook"
  run -0 rg '^open ' "$events"
  assert_output --partial 'User%20Space%20%26%20%E2%9C%93/.config/dotfiles/tcc.json'
}

@test "older helper still opens inventory when its update is deferred" {
  plutil -remove CFBundleURLTypes "$HOME/Applications/Dotfiles Permissions.app/Contents/Info.plist"
  run -0 env INSTALL_STATUS=75 "$TEST_ZSH" -f "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" "$FIXTURE/pty" '[y/N]' 'y' bash "$hook"
  run -0 rg '^open ' "$events"
  assert_output --partial "$HOME/.config/dotfiles/tcc.json --args --reconcile --manifest"
  run -0 rg 'needs an update for background reconciliation' "$FIXTURE/pty"
}
