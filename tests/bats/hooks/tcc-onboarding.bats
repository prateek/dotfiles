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
printf 'audit %s\n' "$*" >> "$events"
exit "${AUDIT_STATUS:-0}"
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

@test "permission audit defaults to desktop Mac roles and respects overrides" {
  local machine
  for machine in personal work homelab; do
    run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl "$machine"
    assert_output --partial '--audit'
    run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl "$machine" '{"machines_local":{"tcc_onboarding":false}}'
    assert_output ''
  done
  for machine in ci devbox; do
    run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl "$machine"
    assert_output ''
  done
  run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl personal '{"machines_local":{"run_install_scripts":false}}'
  assert_output ''
  run -0 render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl devbox '{"machines_local":{"tcc_onboarding":true}}'
  assert_output ''
}

@test "matching audit is quiet and never launches" {
  run_bash 0 "$hook"
  assert_output ''
  assert_equal "$(cat "$events")" $'install\naudit --audit '"$HOME/.config/dotfiles/tcc.json"
}

@test "deviations and unknown evidence print a shell-safe manual command without launching" {
  local status
  for status in 2 3; do
    : > "$events"
    run -0 env AUDIT_STATUS="$status" bash "$hook"
    assert_output --partial 'Review permissions: open -a '
    local command="${output#Review permissions: }"
    run -0 bash -c "$command"
    assert_equal "$(tail -1 "$events")" "open -a $HOME/Applications/Dotfiles Permissions.app $HOME/.config/dotfiles/tcc.json"
  done
}

@test "SSH and CI still audit without GUI or prompt" {
  local setting
  for setting in CI=true SSH_CONNECTION=remote; do
    : > "$events"
    run -0 env "$setting" AUDIT_STATUS=3 bash "$hook"
    assert_output --partial 'Review permissions:'
    assert_equal "$(cat "$events")" $'install\naudit --audit '"$HOME/.config/dotfiles/tcc.json"
  done
}

@test "manifest and unexpected audit failures fail apply with unknown evidence" {
  run -1 env AUDIT_STATUS=64 bash "$hook"
  assert_output --partial 'Invalid or unreadable permission manifest'
  run -1 env AUDIT_STATUS=1 bash "$hook"
  assert_output --partial 'recorded access remains unknown'
  run -1 env INSTALL_STATUS=1 bash "$hook"
  assert_output --partial 'installation failed'
}

@test "deferred update audits verified existing helper" {
  run -0 env INSTALL_STATUS=75 AUDIT_STATUS=2 bash "$hook"
  assert_output --partial 'quit it'
  assert_output --partial 'Review permissions:'
  assert_equal "$(cat "$events")" $'install\naudit --audit '"$HOME/.config/dotfiles/tcc.json"
}

@test "legacy helper is never called with audit flag" {
  plutil -remove DotfilesPermissionsAuditVersion "$HOME/Applications/Dotfiles Permissions.app/Contents/Info.plist"
  run -0 env INSTALL_STATUS=75 bash "$hook"
  assert_output --partial 'Permission audit unavailable'
  assert_output --partial 'Review permissions:'
  assert_equal "$(cat "$events")" install
}

@test "missing toolchain reports unavailability without scanning or launching" {
  run -0 env INSTALL_STATUS=69 bash "$hook"
  assert_output --partial 'unavailable'
  assert_output --partial 'System Settings'
  assert_equal "$(cat "$events")" install
}

@test "install lock reports retry without scanning or launching" {
  run -0 env INSTALL_STATUS=73 bash "$hook"
  assert_output --partial 'already in progress'
  assert_equal "$(cat "$events")" install
}

@test "rendered paths and manual command preserve shell metacharacters without execution" {
  local previous_home="$HOME"
  local special='User '\'' Space & ✓ $(printf substituted)`printf substituted`'
  export HOME="$FIXTURE/$special"
  local source_dir="$FIXTURE/Checkout $special/home"
  mkdir -p "$HOME/Applications" "$source_dir" "$source_dir/../scripts/macos"
  cp -R "$previous_home/Applications/Dotfiles Permissions.app" "$HOME/Applications/"
  cp "$FIXTURE/repo/scripts/macos/install-tcc-onboarding" "$source_dir/../scripts/macos/"
  local data
  data=$("$TEST_PYTHON" - "$source_dir" <<'PYTEST'
import json, sys
print(json.dumps({"chezmoi": {"sourceDir": sys.argv[1]}}))
PYTEST
)
  render_template home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl personal "$data" > "$hook"
  run -0 env AUDIT_STATUS=3 bash "$hook"
  local command="${output#Review permissions: }"
  assert_equal "$(cat "$events")" $'install\naudit --audit '"$HOME/.config/dotfiles/tcc.json"
  run -0 bash -c "$command"
  assert_equal "$(tail -1 "$events")" "open -a $HOME/Applications/Dotfiles Permissions.app $HOME/.config/dotfiles/tcc.json"
}
