load '../../support/common'

setup() {
  setup_fixture
  cat > "$FIXTURE/bin/dotpkgs" <<EOF
#!/bin/sh
exec "$DOTFILES_ROOT/scripts/packages/dotpkgs/.venv/bin/python" "$DOTFILES_ROOT/home/dot_local/bin/executable_dotpkgs" "\$@"
EOF
  chmod +x "$FIXTURE/bin/dotpkgs"
  export DOTPKGS_BIN="$FIXTURE/bin/dotpkgs"
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
  'info --json=v2 --installed')
    cat <<'JSON'
{"formulae":[{"name":"xcodes","installed":[{"version":"1","installed_on_request":true}],"versions":{"stable":"1"}},{"name":"goku","full_name":"yqrashawn/goku/goku","installed":[{"version":"1","installed_on_request":true}],"versions":{"stable":"1"}},{"name":"extra-requested","installed":[{"version":"1","installed_on_request":true}],"versions":{"stable":"1"}},{"name":"dependency","installed":[{"version":"1","installed_on_request":false}],"versions":{"stable":"1"}}],"casks":[]}
JSON
    ;;
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

@test "Brew inventory reports unavailable package data instead of declaring packages missing" {
  export DOTPKGS_BIN=/usr/bin/false
  run_bash 1 "$DOTFILES_ROOT/scripts/audit/brew-inventory.sh"
  [[ "$stderr" == *'Package inventory unavailable: dotpkgs failed'* ]]
  refute_output --partial '## Formulae:'
}
