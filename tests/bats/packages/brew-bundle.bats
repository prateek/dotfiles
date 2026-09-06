load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset HOMEBREW_BUNDLE_JOBS HOMEBREW_DOWNLOAD_CONCURRENCY
  unset DOTFILES_HOMEBREW_BUNDLE_JOBS DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY
  export DOTFILES_INSTALL_MAS_APPS=false
  template=home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl
  render_bundle ci
  cat > "$FIXTURE/bin/uname" <<'STUB'
#!/bin/sh
printf 'Linux\n'
STUB
  cat > "$FIXTURE/bin/brew" <<'STUB'
#!/bin/sh
set -eu
case "$*" in
  tap) printf '1password/tap\n' ;;
  tap\ *|"update --quiet") printf '%s\n' "$*" >> "$FIXTURE/brew.calls" ;;
  "bundle install --help")
    if [ "${TEST_BREW_JOBS:-1}" = 1 ]; then
      printf 'usage: bundle install --jobs N\n'
    else
      printf 'usage: bundle install\n'
    fi ;;
  bundle\ install*)
    printf 'bundle\n' >> "$FIXTURE/brew.calls"
    printf '%s\n' "$@" > "$FIXTURE/bundle.args"
    printf '%s\n' "${HOMEBREW_DOWNLOAD_CONCURRENCY:-}" > "$FIXTURE/downloads"
    while [ "$#" -gt 0 ]; do
      if [ "$1" = --file ]; then cp "$2" "$FIXTURE/Brewfile"; fi
      shift
    done ;;
  *) printf 'unexpected brew call: %s\n' "$*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/uname" "$FIXTURE/bin/brew"
}

render_bundle() {
  render_template "$template" "$1" '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
}

@test "Brew Bundle uses automatic concurrency and the CI package selection" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/bundle.args")" == *$'--jobs\nauto' ]]
  [ "$(cat "$FIXTURE/downloads")" = auto ]
  local brewfile
  brewfile="$(cat "$FIXTURE/Brewfile")"
  [[ "$brewfile" == *'cask "1password-cli"'* ]]
  [[ "$brewfile" != *'felixkratz/formulae'* && "$brewfile" != *'yqrashawn/goku'* ]]
}

@test "Brew Bundle dotfiles concurrency overrides take precedence over Homebrew values" {
  export DOTFILES_HOMEBREW_BUNDLE_JOBS=2 DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY=3
  export HOMEBREW_BUNDLE_JOBS=7 HOMEBREW_DOWNLOAD_CONCURRENCY=8
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/bundle.args")" == *$'--jobs\n2' ]]
  [ "$(cat "$FIXTURE/downloads")" = 3 ]
}

@test "Brew Bundle supports Homebrew without the jobs flag" {
  export TEST_BREW_JOBS=0
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/bundle.args")" != *--jobs* ]]
  [ "$(cat "$FIXTURE/downloads")" = auto ]
}

@test "Brew Bundle trusts selected third-party packages and creates their taps before installation" {
  render_bundle personal
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'Mac App Store installs disabled'* ]]
  local brewfile entry before
  brewfile="$(cat "$FIXTURE/Brewfile")"
  for entry in 'brew "eugene1g/safehouse/agent-safehouse", trusted: true' \
    'cask "dagger/tap/container-use", trusted: true' 'tap "mattt/tap"' \
    'cask "mattt/tap/imcp", trusted: true' 'cask "nikitabobko/tap/aerospace", trusted: true' \
    'cask "stablyai/orca/orca", trusted: true'; do
    [[ "$brewfile" == *"$entry"* ]]
  done
  for entry in 'cask "peripheryapp/periphery/periphery", trusted: true' \
    'brew "homebrew/core/xcodes"' 'brew "fastlane"' 'brew "cirruslabs/cli/tart"'; do
    [[ "$brewfile" != *"$entry"* ]]
  done
  before="$(cat "$FIXTURE/brew.calls")"
  [[ "$before" == *bundle* ]]
  before="${before%%bundle*}"
  for entry in eugene1g/safehouse mattt/tap stablyai/orca; do
    [[ "$before" == *"tap $entry"* ]]
  done

  render_bundle work
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$(cat "$FIXTURE/Brewfile")" != *mattt/tap* ]]
}
