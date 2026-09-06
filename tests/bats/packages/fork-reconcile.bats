load '../../support/common'
load '../../support/chezmoi'
load '../../support/brew'

setup() {
  setup_fixture
  setup_brew_state
  reconciler="$DOTFILES_ROOT/scripts/packages/reconcile-fork-installs"
  printf 'prateek/forks/forkstub-fork\tformula\tforkstub\nprateek/forks/forkstub-app-fork\tcask\tforkstub-app\n' > "$FIXTURE/entries"
}

installed_forks() {
  printf 'forkstub-fork\n' > "$FIXTURE/brew.formulas"
  printf 'forkstub-app-fork\n' > "$FIXTURE/brew.casks"
  printf 'prateek/forks\n' > "$FIXTURE/brew.taps"
}

@test "Fork adoption creates the tap and removes official packages before installing their replacements" {
  printf 'forkstub\n' > "$FIXTURE/brew.formulas"
  printf 'forkstub-app\n' > "$FIXTURE/brew.casks"
  run_bash 0 "$reconciler" --entries-file "$FIXTURE/entries"
  assert_success
  [ -z "$stderr" ]
  run -0 "$TEST_PYTHON" - "$FIXTURE/brew.calls" <<'PY'
import pathlib, sys
calls = pathlib.Path(sys.argv[1]).read_text().splitlines()
formula = calls.index('install --formula prateek/forks/forkstub-fork')
cask = calls.index('CASK_OPTS=--no-quarantine install --cask prateek/forks/forkstub-app-fork')
assert calls.index('tap prateek/forks https://github.com/prateek/forks') < formula
assert calls.index('uninstall --formula forkstub') < formula
assert calls.index('uninstall --cask forkstub-app') < cask
PY
  assert_success
}

@test "Installed forks remain untouched and outdated forks only produce an upgrade hint" {
  installed_forks
  run_bash 0 "$reconciler" --entries-file "$FIXTURE/entries"
  assert_success
  [ -z "$stderr" ]
  local calls
  calls=$'\n'"$(cat "$FIXTURE/brew.calls")"
  [[ "$calls" != *$'\ninstall '* && "$calls" != *$'\nuninstall '* && "$calls" != *CASK_OPTS=* ]]
  printf 'forkstub-app-fork (20260704.13.1) != 20260705.14.1\n' > "$FIXTURE/brew.outdated"
  : > "$FIXTURE/brew.calls"
  run_bash 0 "$reconciler" --entries-file "$FIXTURE/entries"
  assert_success
  assert_output --partial 'outdated fork: forkstub-app-fork (20260704.13.1) != 20260705.14.1'
  assert_output --partial 'brew upgrade --cask forkstub-app-fork'
  refute_output --partial 'outdated fork: forkstub-fork'
  [ -z "$stderr" ]
  calls=$'\n'"$(cat "$FIXTURE/brew.calls")"
  [[ "$calls" != *$'\ninstall '* && "$calls" != *$'\nupgrade '* && "$calls" != *CASK_OPTS=* ]]
}

@test "Retired forks are removed only when their definitions belong to the managed tap" {
  installed_forks
  printf 'someoneelses-fork\n' >> "$FIXTURE/brew.formulas"
  mkdir -p "$FIXTURE/brew-repo/Library/Taps/prateek/homebrew-forks/Formula" "$FIXTURE/brew-repo/Library/Taps/prateek/homebrew-forks/Casks"
  touch "$FIXTURE/brew-repo/Library/Taps/prateek/homebrew-forks/Formula/forkstub-fork.rb" \
    "$FIXTURE/brew-repo/Library/Taps/prateek/homebrew-forks/Casks/forkstub-app-fork.rb"
  : > "$FIXTURE/entries"
  run_bash 0 "$reconciler" --entries-file "$FIXTURE/entries"
  assert_success
  [ -z "$stderr" ]
  local calls
  calls=$'\n'"$(cat "$FIXTURE/brew.calls")"$'\n'
  [[ "$calls" == *$'\nuninstall --formula forkstub-fork\n'* ]]
  [[ "$calls" == *$'\nuninstall --cask forkstub-app-fork\n'* ]]
  [[ "$calls" != *'uninstall --formula someoneelses-fork'* ]]
  [[ "$calls" != *$'\ninstall '* && "$calls" != *CASK_OPTS=* ]]
}

@test "Fork hook hands off the cask replacement and enters administrator setup while CI skips reconciliation" {
  local template=home/.chezmoiscripts/run_onchange_after_09-fork-reconcile.sh.tmpl
  render_template "$template" personal \
    '{"machines_local":{"run_install_scripts":true},"packages":{"groups":{"forks":{"entries":[{"name":"prateek/forks/forkstub-app-fork","kind":"cask","replaces":"forkstub-app"}]}}}}' > "$FIXTURE/hook.sh"
  printf 'forkstub-app\n' > "$FIXTURE/brew.casks"
  run_bash 0 "$FIXTURE/hook.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/brew.calls")" == *'uninstall --cask forkstub-app'* ]]
  [[ "$(cat "$FIXTURE/brew.calls")" == *'CASK_OPTS=--no-quarantine install --cask prateek/forks/forkstub-app-fork'* ]]
  [ "$(cat "$FIXTURE/id.calls")" = -u ]
  : > "$FIXTURE/brew.calls"
  : > "$FIXTURE/id.calls"
  render_template "$template" ci > "$FIXTURE/ci.sh"
  run_bash 0 "$FIXTURE/ci.sh"
  assert_success
  assert_output --partial skipping
  [ -z "$stderr" ]
  [ ! -s "$FIXTURE/brew.calls" ]
  [ ! -s "$FIXTURE/id.calls" ]
}

@test "Brewfile subtracts an active fork's official package and restores it when no fork replaces it" {
  run -0 --separate-stderr render_template home/.chezmoitemplates/brewfile.tmpl personal \
    '{"packages":{"groups":{"forks":{"entries":[{"name":"prateek/forks/gitleaks-fork","kind":"formula","replaces":"gitleaks"}]}}}}'
  assert_success
  refute_output --partial 'brew "gitleaks"'
  assert_output --partial 'brew "git"'
  [ -z "$stderr" ]
  run -0 --separate-stderr render_template home/.chezmoitemplates/brewfile.tmpl personal
  assert_success
  assert_output --partial 'brew "gitleaks"'
  [ -z "$stderr" ]
}
