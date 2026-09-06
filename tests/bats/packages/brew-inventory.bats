load '../../support/common'

setup() {
  setup_fixture
  export BREWFILE="$FIXTURE/Brewfile"
  cat > "$BREWFILE" <<'BREWFILE'
tap "yqrashawn/goku"
tap "missing/tap"
brew "homebrew/core/xcodes", args: ["force-bottle"]
brew "yqrashawn/goku/goku"
brew "missing-formula"
BREWFILE
  cat > "$FIXTURE/bin/brew" <<'STUB'
#!/bin/sh
case "$*" in
  tap) printf '%s\n' yqrashawn/goku extra/tap ;;
  'list --formula --full-name') printf '%s\n' xcodes yqrashawn/goku/goku extra-requested dependency ;;
  'list --formula --installed-on-request --full-name') printf '%s\n' xcodes yqrashawn/goku/goku extra-requested ;;
  *) exit 97 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/brew"
}

@test "Brew inventory normalizes core names and separates missing requested and dependency drift" {
  run_bash 0 "$DOTFILES_ROOT/scripts/audit/brew-inventory.sh"
  assert_success
  [ -z "$stderr" ]
  refute_output --partial '- homebrew/core/xcodes'
  refute_output --partial '- xcodes'
  refute_output --partial '- yqrashawn/goku/goku'
  assert_output --partial $'## Taps: in package data but not tapped\n- missing/tap\n\n'
  assert_output --partial $'## Taps: tapped but not in package data\n- extra/tap\n\n'
  assert_output --partial $'## Formulae: in package data but not installed\n- missing-formula\n\n'
  assert_output --partial $'## Formulae: installed (on-request) but not in package data\n- extra-requested\n\n'
  assert_output --partial $'## Formulae: installed (any) but not in package data (includes dependencies)\n- dependency\n- extra-requested\n\n'
}
