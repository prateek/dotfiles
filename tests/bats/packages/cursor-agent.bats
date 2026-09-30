load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset TEST_INSTALLER_STATUS TEST_CURL_STATUS
  template=home/.chezmoiscripts/run_after_07-cursor-agent.sh.tmpl
  render_template "$template" work '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"

  cat > "$FIXTURE/fake-install.sh" <<'STUB'
#!/bin/sh
{
  printf 'PATH=%s\n' "$PATH"
  printf 'ARGS=%s\n' "$*"
} > "$FIXTURE/installer.env"
[ "${TEST_INSTALLER_STATUS:-0}" = 0 ] || exit "${TEST_INSTALLER_STATUS}"
versions="$HOME/.local/share/cursor-agent/versions/2026.09.30-abc1234"
mkdir -p "$versions" "$HOME/.local/bin"
printf '#!/bin/sh\nprintf "2026.09.30-abc1234\\n"\n' > "$versions/cursor-agent"
chmod +x "$versions/cursor-agent"
ln -sfn "$versions/cursor-agent" "$HOME/.local/bin/cursor-agent"
ln -sfn "$versions/cursor-agent" "$HOME/.local/bin/agent"
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

  # The hook's failure paths depend on whether any cursor-agent is left on
  # PATH, so the fixture must not inherit the developer's own install.
  render_path="$PATH"
  export PATH="$FIXTURE/bin:/usr/bin:/bin"
}

@test "Cursor CLI installs through Cursor's installer with a PATH that leaves managed shell startup files alone" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'ok: Cursor CLI is installed.'
  [ -x "$HOME/.local/bin/cursor-agent" ]
  [ -x "$HOME/.local/bin/agent" ]
  [[ "$(cat "$FIXTURE/curl.calls")" == *'https://cursor.com/install'* ]]
  local recorded
  recorded="$(cat "$FIXTURE/installer.env")"
  [[ "$recorded" == *"PATH=$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"* ]]
  [[ "$recorded" != *"$FIXTURE/bin"* ]]
}

@test "Cursor CLI installation is skipped once the launcher answers" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  : > "$FIXTURE/curl.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'ok: Cursor CLI is installed.'
  [ ! -s "$FIXTURE/curl.calls" ]
}

@test "a failed Cursor CLI install only warns while a cursor-agent is still on PATH" {
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/cursor-agent"
  chmod +x "$FIXTURE/bin/cursor-agent"
  export TEST_INSTALLER_STATUS=1
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'Cursor CLI install failed'* ]]
  [[ "$stderr" == *'next chezmoi apply retries'* ]]
}

@test "a failed Cursor CLI install with no cursor-agent on PATH stops the apply and names the manual command" {
  export TEST_CURL_STATUS=22
  run_bash 1 "$FIXTURE/install.sh"
  [[ "$stderr" == *'Could not download https://cursor.com/install.'* ]]
  [[ "$stderr" == *'curl -fsSL https://cursor.com/install | bash'* ]]
  [ ! -e "$HOME/.local/bin/cursor-agent" ]
}

@test "Cursor CLI installation is limited to machines that list cursor-agent in agent_clis" {
  local machine data
  for machine in personal ci work; do
    data='{"machines_local":{"run_install_scripts":true}}'
    [ "$machine" != work ] || data='{"machines_local":{"run_install_scripts":true,"agent_clis":["claude"]}}'
    PATH="$render_path" render_template "$template" "$machine" "$data" > "$FIXTURE/excluded.sh"
    run_bash 0 "$FIXTURE/excluded.sh"
    assert_success
    assert_output ''
    [ -z "$stderr" ]
    [ ! -e "$HOME/.local/bin/cursor-agent" ]
    [ ! -s "$FIXTURE/curl.calls" ]
  done
}
