load '../../support/common'

setup() {
  setup_fixture
  export events="$FIXTURE/events"
  : > "$events"
  export compiled="$FIXTURE/compiled"
  mkdir -p "$compiled"
  cat > "$compiled/DotfilesPermissions" <<'SH'
#!/bin/bash
exit "${APP_RUNNING:-1}"
SH
  chmod +x "$compiled/DotfilesPermissions"
  cat > "$FIXTURE/bin/xcrun" <<'SH'
#!/bin/bash
case "$*" in
  'swift --version') [ "${TOOLCHAIN_MISSING:-0}" = 0 ] || exit 1; printf 'Swift test toolchain\n' ;;
  *--show-bin-path*) printf '%s\n' "$compiled" ;;
  'swift build '*) printf 'compile\n' >> "$events" ;;
  *make-icon.swift*) : > "${@: -1}" ;;
  *) exit 1 ;;
esac
SH
  cat > "$FIXTURE/bin/codesign" <<'SH'
#!/bin/bash
exit "${SIGNATURE_INVALID:-0}"
SH
  chmod +x "$FIXTURE/bin/xcrun" "$FIXTURE/bin/codesign"
  installer="$DOTFILES_ROOT/scripts/macos/install-tcc-onboarding"
  app="$HOME/Applications/Dotfiles Permissions.app"
}

@test "permission installer preserves an unchanged app and rebuilds when its digest differs" {
  run_bash 0 "$installer"
  assert_output "$app"
  printf 'preserved\n' > "$app/Contents/Resources/local-sentinel"
  run_bash 0 "$installer"
  [ -f "$app/Contents/Resources/local-sentinel" ]
  assert_equal "$(cat "$events")" compile
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run_bash 0 "$installer"
  [ ! -e "$app/Contents/Resources/local-sentinel" ]
  assert_equal "$(cat "$events")" $'compile\ncompile'
}

@test "permission installer defers an update while the app is running" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run -75 env APP_RUNNING=0 bash "$installer"
  assert_output --partial 'Quit Dotfiles Permissions'
  assert_output --partial "$app"
  assert_equal "$(cat "$events")" compile
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
}

@test "permission installer refuses unrelated apps and concurrent installs" {
  mkdir -p "$app/Contents"
  cp "$DOTFILES_ROOT/scripts/macos/tcc-onboarding/Info.plist" "$app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string com.example.unrelated "$app/Contents/Info.plist"
  run_bash 1 "$installer"
  assert_equal "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" com.example.unrelated
  mkdir -p "$XDG_CACHE_HOME/dotfiles/tcc-onboarding/install.lock"
  run_bash 73 "$installer"
  assert_regex "$stderr" 'install already in progress'
  [ ! -s "$events" ]
}

@test "missing toolchain reuses only a verified installed helper without compiling" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run -0 env TOOLCHAIN_MISSING=1 bash "$installer"
  assert_output --partial "$app"
  assert_equal "$(cat "$events")" compile
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
  run -69 env TOOLCHAIN_MISSING=1 SIGNATURE_INVALID=1 bash "$installer"
  assert_output --partial 'System Settings'
  assert_equal "$(cat "$events")" compile
}

@test "missing toolchain without an installed helper gives manual recovery" {
  run -69 env TOOLCHAIN_MISSING=1 bash "$installer"
  assert_output --partial 'System Settings'
  [ ! -e "$app" ]
  [ ! -s "$events" ]
}
