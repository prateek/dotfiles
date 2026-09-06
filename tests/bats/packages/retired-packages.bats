load '../../support/common'
load '../../support/chezmoi'
load '../../support/brew'

setup() {
  setup_fixture
  setup_brew_state
  cleaner="$DOTFILES_ROOT/scripts/packages/uninstall-retired-packages"
  template=home/.chezmoiscripts/run_onchange_after_08-retired-packages.sh.tmpl
  printf 'gogstub\nbystander\n' > "$FIXTURE/brew.formulas"
  printf 'appstub\n' > "$FIXTURE/brew.casks"
  data='{"machines_local":{"run_install_scripts":true},"packages":{"retired":{"brews":[{"name":"gogstub"}],"casks":[{"name":"appstub"}]}}}'
}

@test "Retired-package cleanup removes listed installed packages, preserves bystanders, and skips absent entries" {
  printf 'gogstub\tformula\nappstub\tcask\n' > "$FIXTURE/entries"
  run_bash 0 "$cleaner" --entries-file "$FIXTURE/entries"
  assert_success
  [ -z "$stderr" ]
  local calls
  calls=$'\n'"$(cat "$FIXTURE/brew.calls")"$'\n'
  [[ "$calls" == *$'\nuninstall --formula gogstub\n'* ]]
  [[ "$calls" == *$'\nuninstall --cask appstub\n'* ]]
  [[ "$calls" != *bystander* ]]
  : > "$FIXTURE/brew.formulas"
  : > "$FIXTURE/brew.casks"
  : > "$FIXTURE/brew.calls"
  run_bash 0 "$cleaner" --entries-file "$FIXTURE/entries"
  assert_success
  [ -z "$stderr" ]
  [[ $'\n'"$(cat "$FIXTURE/brew.calls")" != *$'\nuninstall '* ]]
}

@test "Retired-package hook hands off both package kinds and requests administrator setup only for casks" {
  render_template "$template" personal "$data" > "$FIXTURE/hook.sh"
  run_bash 0 "$FIXTURE/hook.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/brew.calls")" == *'uninstall --formula gogstub'* ]]
  [[ "$(cat "$FIXTURE/brew.calls")" == *'uninstall --cask appstub'* ]]
  [ "$(cat "$FIXTURE/id.calls")" = -u ]
  : > "$FIXTURE/id.calls"
  : > "$FIXTURE/brew.calls"
  render_template "$template" personal \
    '{"machines_local":{"run_install_scripts":true},"packages":{"retired":{"brews":[{"name":"gogstub"}],"casks":[]}}}' > "$FIXTURE/formulas.sh"
  run_bash 0 "$FIXTURE/formulas.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/brew.calls")" == *'uninstall --formula gogstub'* ]]
  [[ "$(cat "$FIXTURE/brew.calls")" != *'uninstall --cask'* ]]
  [ ! -s "$FIXTURE/id.calls" ]
}

@test "Retired-package hook skips empty retirements and disabled installation" {
  local override
  for override in \
    '{"machines_local":{"run_install_scripts":true},"packages":{"retired":{"brews":[],"casks":[]}}}' \
    '{"machines_local":{"run_install_scripts":false}}'; do
    render_template "$template" personal "$override" > "$FIXTURE/hook.sh"
    run_bash 0 "$FIXTURE/hook.sh"
    assert_success
    assert_output --partial skipping
    [ -z "$stderr" ]
    [ ! -s "$FIXTURE/brew.calls" ]
    [ ! -e "$FIXTURE/id.calls" ]
  done
}

@test "Brewfile refuses a retired formula still selected for installation" {
  run -1 --separate-stderr render_template home/.chezmoitemplates/brewfile.tmpl personal \
    '{"packages":{"retired":{"brews":[{"name":"git"}],"casks":[]}}}'
  assert_failure 1
  [[ "$stderr" == *'retired brew "git" is still declared in a selected group'* ]]
}
