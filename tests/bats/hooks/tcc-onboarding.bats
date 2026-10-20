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
printf 'cli %s\n' "$*" >> "$events"
[ -z "${AUDIT_OUTPUT:-}" ] || printf '%s\n' "$AUDIT_OUTPUT"
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
  render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl personal '{"machines_local":{"tcc_onboarding":true}}' > "$FIXTURE/rendered"
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
    run -0 render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl "$machine"
    assert_output --partial '" audit'
    run -0 render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl "$machine" '{"machines_local":{"tcc_onboarding":false}}'
    assert_output ''
  done
  for machine in ci devbox; do
    run -0 render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl "$machine"
    assert_output ''
  done
  run -0 render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl personal '{"machines_local":{"run_install_scripts":false}}'
  assert_output ''
  run -0 render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl devbox '{"machines_local":{"tcc_onboarding":true}}'
  assert_output ''
}

@test "matching audit is quiet and never launches" {
  run_bash 0 "$hook"
  assert_output ''
  assert_equal "$(cat "$events")" $'install\ncli audit'
}

@test "deviations and unknown evidence pass the CLI report through and continue apply" {
  local status
  for status in 2 3; do
    : > "$events"
    run -0 env AUDIT_STATUS="$status" AUDIT_OUTPUT='Guided review (optional): dotfiles-permissions gui' bash "$hook"
    assert_output 'Guided review (optional): dotfiles-permissions gui'
    assert_equal "$(cat "$events")" $'install\ncli audit'
  done
}

@test "SSH and CI still audit without GUI or prompt" {
  local setting
  for setting in CI=true SSH_CONNECTION=remote; do
    : > "$events"
    run -0 env "$setting" AUDIT_STATUS=3 bash "$hook"
    assert_equal "$(cat "$events")" $'install\ncli audit'
  done
}

@test "a helper without Full Disk Access fails apply with recovery" {
  run -1 env AUDIT_STATUS=77 bash "$hook"
  assert_output --partial 'needs Full Disk Access'
  assert_output --partial 'tcc_onboarding = false'
}

@test "manifest and unexpected audit failures fail apply with unknown evidence" {
  run -1 env AUDIT_STATUS=65 bash "$hook"
  assert_output --partial 'Invalid or unreadable permission manifest'
  run -1 env AUDIT_STATUS=1 bash "$hook"
  assert_output --partial 'recorded access remains unknown'
  run -1 env INSTALL_STATUS=1 bash "$hook"
  assert_output --partial 'installation failed'
}

@test "deferred update audits verified existing helper" {
  run -0 env INSTALL_STATUS=75 AUDIT_STATUS=2 bash "$hook"
  assert_output --partial 'quit it'
  assert_equal "$(cat "$events")" $'install\ncli audit'
}

@test "legacy helper is never sent CLI commands" {
  plutil -remove DotfilesPermissionsCLIVersion "$HOME/Applications/Dotfiles Permissions.app/Contents/Info.plist"
  run -0 env INSTALL_STATUS=75 bash "$hook"
  assert_output --partial 'predates its CLI'
  assert_equal "$(cat "$events")" install
}

@test "missing toolchain fails apply without scanning or launching" {
  run -1 env INSTALL_STATUS=69 bash "$hook"
  assert_output --partial 'Swift toolchain'
  assert_output --partial 'tcc_onboarding = false'
  assert_equal "$(cat "$events")" install
}

@test "install lock reports retry without scanning or launching" {
  run -0 env INSTALL_STATUS=73 bash "$hook"
  assert_output --partial 'already in progress'
  assert_equal "$(cat "$events")" install
}

@test "rendered installer path preserves shell metacharacters without execution" {
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
  render_template home/.chezmoiscripts/run_after_99-tcc-onboarding.sh.tmpl personal "$data" > "$hook"
  run -0 env AUDIT_STATUS=3 bash "$hook"
  assert_equal "$(cat "$events")" $'install\ncli audit'
}
