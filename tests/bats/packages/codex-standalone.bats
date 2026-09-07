load '../../support/common'
load '../../support/chezmoi'
load '../../support/brew'

setup() {
  setup_fixture
  setup_brew_state
  template=home/.chezmoiscripts/run_after_07-codex-standalone.sh.tmpl
  render_template "$template" personal '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"

  cat > "$FIXTURE/fake-install.sh" <<'STUB'
#!/bin/sh
{
  printf 'PATH=%s\n' "$PATH"
  printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}"
  printf 'CODEX_NON_INTERACTIVE=%s\n' "${CODEX_NON_INTERACTIVE:-}"
} > "$FIXTURE/installer.env"
[ "${TEST_INSTALLER_STATUS:-0}" = 0 ] || exit "${TEST_INSTALLER_STATUS}"
standalone="${CODEX_HOME:-$HOME/.codex}/packages/standalone"
release="$standalone/releases/1.2.3"
mkdir -p "$release/bin" "$HOME/.local/bin"
printf '#!/bin/sh\nprintf "codex-cli 1.2.3\\n"\n' > "$release/bin/codex"
chmod +x "$release/bin/codex"
ln -sf bin/codex "$release/codex"
ln -sfn "$release" "$standalone/current"
ln -sf "$standalone/current/bin/codex" "$HOME/.local/bin/codex"
STUB

  cat > "$FIXTURE/bin/curl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/curl.calls"
[ "${TEST_CURL_STATUS:-0}" = 0 ] || exit "${TEST_CURL_STATUS}"
output=""
while [ "$#" -gt 0 ]; do
  [ "$1" = -o ] && output="$2"
  shift
done
cp "$FIXTURE/fake-install.sh" "$output"
STUB
  chmod +x "$FIXTURE/bin/curl"
  : > "$FIXTURE/curl.calls"
}

@test "Codex CLI installs into the machine's normal home without touching managed shell startup files" {
  export CODEX_HOME="$FIXTURE/orca-account/home"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [ -x "$HOME/.codex/packages/standalone/current/codex" ]
  [ -x "$HOME/.local/bin/codex" ]
  [ ! -e "$CODEX_HOME" ]
  [ ! -e "$HOME/.zprofile" ]
  local recorded
  recorded="$(cat "$FIXTURE/installer.env")"
  [[ "$recorded" == *"CODEX_HOME=$HOME/.codex"* ]]
  [[ "$recorded" == *'CODEX_NON_INTERACTIVE=1'* ]]
  # The installer only edits a shell profile when its install directory is off
  # PATH or another Codex is on it; the hook must hand it neither situation.
  [[ "$recorded" == *"PATH=$HOME/.local/bin:"* ]]
  [[ "$recorded" != *homebrew* ]]
  [[ "$recorded" != *"$FIXTURE/bin"* ]]
}

@test "Codex CLI installation is skipped once the standalone package is present" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  : > "$FIXTURE/curl.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'ok: Codex CLI standalone package is installed.'
  [ ! -s "$FIXTURE/curl.calls" ]
}

@test "Failed Codex CLI installation keeps the Homebrew cask and stops the apply before its retirement" {
  printf 'codex\n' > "$FIXTURE/brew.casks"
  export TEST_INSTALLER_STATUS=1
  run_bash 1 "$FIXTURE/install.sh"
  assert_failure
  [[ "$stderr" == *'leaving the Homebrew cask installed'* ]]
  [ ! -e "$HOME/.local/bin/codex" ]
  [[ "$(cat "$FIXTURE/brew.calls")" != *uninstall* ]]
}

@test "Failed Codex CLI installation only warns once no Homebrew Codex is left to protect" {
  export TEST_CURL_STATUS=1
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'Could not download https://chatgpt.com/codex/install.sh.'* ]]
  [[ "$stderr" == *'the next chezmoi apply retries'* ]]
}

@test "Codex CLI installation is limited to machine types that select the codex group" {
  local machine
  for machine in work ci; do
    render_template "$template" "$machine" '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/excluded.sh"
    run_bash 0 "$FIXTURE/excluded.sh"
    assert_success
    assert_output ''
    [ -z "$stderr" ]
    [ ! -e "$HOME/.local/bin/codex" ]
    [ ! -s "$FIXTURE/curl.calls" ]
  done
}
