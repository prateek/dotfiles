load '../../support/common'

setup() {
  setup_fixture
  script="$DOTFILES_ROOT/scripts/vm/test-install-tart.sh"
  unset DOTFILES_TART_ALLOW_BOOT_DISK DOTFILES_TRACE DOTFILES_TART_TRACE_FILE
  unset DOTFILES_TART_TRACE_DIR DOTFILES_TART_HOMEBREW_CACHE_DIR TART_HOMEBREW_CACHE_DIR
  export TART_HOME="$FIXTURE/tart" LOG_FILE="$FIXTURE/install.log"
  cat > "$FIXTURE/bin/tart" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/tart.calls"
case "$1" in
  list|clone|set|run|exec|stop|delete) exit 0 ;;
  *) printf 'unexpected tart call: %s\n' "$*" >&2; exit 99 ;;
esac
STUB
  cat > "$FIXTURE/bin/stat" <<'STUB'
#!/bin/sh
[ "$1" = -f ] && [ "$2" = %d ] || exit 99
printf '42\n'
STUB
  chmod +x "$FIXTURE/bin/tart" "$FIXTURE/bin/stat"
}

@test "Tart helper help explains lane images, resource controls, cache sharing, and guest tracing" {
  run_bash 0 "$script" --help
  assert_success
  [ -z "$stderr" ]
  local entry
  for entry in ghcr.io/cirruslabs/macos-tahoe-base:latest ghcr.io/cirruslabs/macos-tahoe-xcode:latest \
    '--lane <smoke|full>' '--cpu <count>' '--memory <mb>' '--homebrew-cache-dir <path>' \
    --no-homebrew-cache 'MAS requires opt-in' 'Local mode also' 'captures guest zsh spans' \
    DOTFILES_TART_HOMEBREW_CACHE_DIR; do
    assert_output --partial "$entry"
  done
  refute_output --partial --profile
}

@test "Tart helper rejects invalid lanes, retired profiles, undersized resources, and missing values before contacting Tart" {
  run_bash 1 "$script" --lane invalid
  assert_failure 1
  assert_output --partial "--lane must be 'smoke' or 'full'"
  run_bash 1 "$script" --profile core
  assert_failure 1
  assert_output --partial 'Unknown arg: --profile'
  run_bash 1 "$script" --cpu 0
  assert_failure 1
  assert_output --partial '--cpu must be >= 1'
  run_bash 1 "$script" --memory 1024
  assert_failure 1
  assert_output --partial '--memory must be >= 2048 MB'
  local flag
  for flag in --lane --cpu --vm-name --homebrew-cache-dir; do
    run_bash 1 "$script" "$flag"
    assert_failure 1
    assert_output --partial "missing value for $flag"
  done
  [ ! -e "$FIXTURE/tart.calls" ]
}

@test "Tart helper refuses storage on the boot device before any Tart operation" {
  run_bash 1 "$script" --lane smoke --dry-run --vm-name dotfiles-guard-contract --no-homebrew-cache
  assert_failure 1
  [[ "$stderr" == *'boot disk'* ]]
  [ ! -e "$FIXTURE/tart.calls" ]
}

@test "Tart helper boot-device override allows full-lane plumbing and forwards explicit MAS opt-in" {
  export DOTFILES_TART_ALLOW_BOOT_DISK=1 DOTFILES_INSTALL_MAS_APPS=true
  run_bash 0 "$script" --lane full --dry-run --vm-name dotfiles-helper-contract --no-homebrew-cache
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/tart.calls")" == *'DOTFILES_INSTALL_MAS_APPS=true'* ]]
}
