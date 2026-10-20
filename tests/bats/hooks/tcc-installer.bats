load '../../support/common'

setup() {
  setup_fixture
  export events="$FIXTURE/events"
  : > "$events"
  export compiled="$FIXTURE/compiled"
  mkdir -p "$compiled"
  : > "$compiled/DotfilesPermissions"
  chmod +x "$compiled/DotfilesPermissions"
  cat > "$FIXTURE/bin/lsappinfo" <<'SH'
#!/bin/bash
[ "$*" = 'find bundleid=com.prateek.DotfilesPermissions' ] || exit 1
[ "${APP_RUNNING:-1}" != 0 ] || printf 'ASN:0x0-0x1234:\n'
SH
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
[ "$1" != --force ] || printf 'sign %s\n' "$3" >> "$events"
exit "${SIGNATURE_INVALID:-0}"
SH
  cat > "$FIXTURE/bin/openssl" <<'SH'
#!/bin/bash
case "$1" in
  rand) printf 'fixture-secret\n' ;;
  req) for ((i = 1; i <= $#; i++)); do case "${!i}" in -keyout|-out) j=$((i + 1)); : > "${!j}" ;; esac; done ;;
  pkcs12) for ((i = 1; i <= $#; i++)); do [ "${!i}" != -out ] || { j=$((i + 1)); : > "${!j}"; }; done ;;
esac
SH
  cat > "$FIXTURE/bin/security" <<'SH'
#!/bin/bash
printf 'security %s\n' "$1" >> "$FIXTURE/security-calls"
case "$1" in
  create-keychain) mkdir -p "$(dirname "${@: -1}")"; : > "${@: -1}" ;;
  list-keychains)
    if [ -n "${EMPTY_SEARCH:-}" ]; then :
    elif [ "${4:-}" = -s ]; then shift 4; printf '    "%s"\n' "$@" > "$FIXTURE/search-list"
    elif [ -f "$FIXTURE/search-list" ]; then cat "$FIXTURE/search-list"
    else printf '    "%s"\n' "$HOME/Library/Keychains/login.keychain-db"; fi ;;
  find-certificate) [ -n "${NO_CERT:-}" ] || printf 'SHA-1 hash: ABCDEF0123456789\n' ;;
esac
SH
  chmod +x "$FIXTURE/bin/xcrun" "$FIXTURE/bin/codesign" "$FIXTURE/bin/lsappinfo" "$FIXTURE/bin/openssl" "$FIXTURE/bin/security"
  installer="$DOTFILES_ROOT/scripts/macos/install-tcc-onboarding"
  app="$HOME/Applications/Dotfiles Permissions.app"
}

@test "permission installer preserves an unchanged app and rebuilds when its digest differs" {
  run_bash 0 "$installer"
  assert_output "$app"
  printf 'preserved\n' > "$app/Contents/Resources/local-sentinel"
  run_bash 0 "$installer"
  [ -f "$app/Contents/Resources/local-sentinel" ]
  assert_equal "$(cat "$events")" $'compile\nsign ABCDEF0123456789'
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run_bash 0 "$installer"
  [ ! -e "$app/Contents/Resources/local-sentinel" ]
  assert_equal "$(cat "$events")" $'compile\nsign ABCDEF0123456789\ncompile\nsign ABCDEF0123456789'
}

@test "permission installer signs with one stable per-machine identity" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run_bash 0 "$installer"
  assert_equal "$(grep -c 'security create-keychain' "$FIXTURE/security-calls")" 1
  assert_equal "$(grep -c 'security unlock-keychain' "$FIXTURE/security-calls")" 2
  run_bash 0 "$installer"
  assert_equal "$(grep -c 'security unlock-keychain' "$FIXTURE/security-calls")" 2
  assert_equal "$(grep -c "dotfiles-codesign.keychain-db" "$FIXTURE/search-list")" 1
  assert_equal "$(grep -c "login.keychain-db" "$FIXTURE/search-list")" 1
  assert_equal "$(stat -f %Lp "$XDG_STATE_HOME/dotfiles/codesign/keychain-password")" 600
  assert_equal "$(grep -c '^sign ABCDEF0123456789$' "$events")" 2
}

@test "permission installer refuses to sign when the keychain password is gone" {
  run_bash 0 "$installer"
  rm "$XDG_STATE_HOME/dotfiles/codesign/keychain-password"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run_bash 1 "$installer"
  assert_regex "$stderr" 'keychain password missing'
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
}

@test "permission installer defers an update while the app is running" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run -75 env APP_RUNNING=0 bash "$installer"
  assert_output --partial 'Quit Dotfiles Permissions'
  assert_output --partial "$app"
  assert_equal "$(cat "$events")" $'compile\nsign ABCDEF0123456789'
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
}

@test "permission installer refuses unrelated apps and concurrent installs" {
  mkdir -p "$app/Contents"
  cp "$DOTFILES_ROOT/scripts/macos/tcc-onboarding/Info.plist" "$app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string com.example.unrelated "$app/Contents/Info.plist"
  run_bash 1 "$installer"
  assert_equal "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" com.example.unrelated
  mkdir -p "$XDG_CACHE_HOME/dotfiles/tcc-onboarding"
  ln -s "$$" "$XDG_CACHE_HOME/dotfiles/tcc-onboarding/install.lock"
  run_bash 73 "$installer"
  assert_regex "$stderr" 'install already in progress'
  [ ! -s "$events" ]
}

@test "permission installer reclaims a lock left by a dead install" {
  local lock="$XDG_CACHE_HOME/dotfiles/tcc-onboarding/install.lock"
  for owner in legacy-directory 99999999; do
    rm -rf "$app"
    mkdir -p "$(dirname "$lock")"
    if [ "$owner" = legacy-directory ]; then mkdir "$lock"; else ln -s "$owner" "$lock"; fi
    run_bash 0 "$installer"
    assert_regex "$stderr" 'Removing a stale permission helper install lock'
    [ ! -e "$lock" ]
    [ -d "$app" ]
  done
}

@test "missing toolchain reuses only a verified installed helper without compiling" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  run -0 env TOOLCHAIN_MISSING=1 bash "$installer"
  assert_output --partial "$app"
  assert_equal "$(cat "$events")" $'compile\nsign ABCDEF0123456789'
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
  run -69 env TOOLCHAIN_MISSING=1 SIGNATURE_INVALID=1 bash "$installer"
  assert_output --partial 'System Settings'
  assert_equal "$(cat "$events")" $'compile\nsign ABCDEF0123456789'
}

@test "missing toolchain without an installed helper gives manual recovery" {
  run -69 env TOOLCHAIN_MISSING=1 bash "$installer"
  assert_output --partial 'System Settings'
  [ ! -e "$app" ]
  [ ! -s "$events" ]
}

@test "permission installer never rewrites the keychain search list from an empty read" {
  run -1 env EMPTY_SEARCH=1 bash "$installer"
  assert_output --partial 'refusing to change it'
  [ ! -e "$FIXTURE/search-list" ]
  [ ! -e "$app" ]
}

@test "permission installer explains a keychain without its certificate" {
  run_bash 0 "$installer"
  printf 'old\n' > "$app/Contents/Resources/source.sha256"
  NO_CERT=1 run_bash 1 "$installer"
  assert_regex "$stderr" 'Delete that keychain to recreate the identity'
  assert_equal "$(cat "$app/Contents/Resources/source.sha256")" old
}
