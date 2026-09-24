#!/usr/bin/env bats
load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  scenario="$DOTFILES_ROOT/tests/scenarios/hooks/pin-hostname.bash"
  hook="home/.chezmoitemplates/apply-preflight.sh.tmpl"
  mkdir -p "$FIXTURE/names"
  : >"$FIXTURE/sudo.log"
  # scutil reads and writes names as files; an absent file is an unset name.
  cat >"$FIXTURE/bin/scutil" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  --get) [ -s "$FIXTURE/names/$2" ] || { printf '%s: not set\n' "$2"; exit 1; }; cat "$FIXTURE/names/$2" ;;
  --set) [ "${SUDO:-}" = 1 ] || { printf 'scutil: permission denied\n' >&2; exit 1; }; printf '%s\n' "$3" >"$FIXTURE/names/$2" ;;
  *) exit 99 ;;
esac
STUB
  cat >"$FIXTURE/bin/sudo" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FIXTURE/sudo.log"
SUDO=1 exec "$@"
STUB
  # security finds the token when names/token exists and reads it unless names/locked exists.
  cat >"$FIXTURE/bin/security" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FIXTURE/security.argv"
if [ "$1" = -i ]; then
  # Interactive mode: store the -w value from the add command on stdin.
  sed -n 's/^add-generic-password -U -s op-devland-sa -a "[^"]*" -w "\([^"]*\)"$/\1/p' >"$FIXTURE/names/token"
  exit 0
fi
[ "$1" = find-generic-password ] && [ "$3" = op-devland-sa ] || exit 99
[ -e "$FIXTURE/names/token" ] || exit 44
if [ "${4:-}" = -w ]; then [ ! -e "$FIXTURE/names/locked" ] || exit 36; cat "$FIXTURE/names/token"; fi
STUB
  chmod +x "$FIXTURE/bin/scutil" "$FIXTURE/bin/sudo" "$FIXTURE/bin/security"
}

# A pseudo-terminal on stdin stands in for an operator who can answer the unlock prompt.
in_pty() {
  "$TEST_PYTHON" -c 'import os, pty, sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' "$@" </dev/null
}

@test "HostName hook pins only on machines that opt in" {
  local machine
  for machine in personal homelab; do
    render_template "$hook" "$machine" >"$FIXTURE/rendered.sh"
    run_bash 0 -n "$FIXTURE/rendered.sh"
    assert_success
    run -0 grep -Fx 'pin_hostname_reconcile "dotfiles-test-host"' "$FIXTURE/rendered.sh"
  done
  render_template "$hook" work >"$FIXTURE/rendered.sh"
  run -1 grep -F pin_hostname_reconcile "$FIXTURE/rendered.sh"
  render_template "$hook" ci >"$FIXTURE/rendered.sh"
  [ ! -s "$FIXTURE/rendered.sh" ]
  render_template "$hook" homelab '{"machines_local":{"run_install_scripts":false,"agent_session_wiki":false}}' >"$FIXTURE/rendered.sh"
  [ ! -s "$FIXTURE/rendered.sh" ]
}

@test "every apply warns when an archiving host has no wiki alias" {
  render_template "$hook" work >"$FIXTURE/rendered.sh"
  run_bash 0 "$FIXTURE/rendered.sh"
  assert_success
  assert_regex "$stderr" "warning: no wiki_host_alias for host 'dotfiles-test-host'.*\\[machines\\.host\\.dotfiles-test-host\\]"
  render_template "$hook" work '{"chezmoi":{"hostname":"M-D2N572TGQN"}}' >"$FIXTURE/rendered.sh"
  [ ! -s "$FIXTURE/rendered.sh" ]
}

@test "unset HostName is pinned to LocalHostName and aborts an apply rendered under another name" {
  printf 'prateek-personal-mbp\n' >"$FIXTURE/names/LocalHostName"
  run_bash 1 "$scenario" Mac
  assert_failure
  assert_equal "$(cat "$FIXTURE/names/HostName")" prateek-personal-mbp.local
  assert_regex "$stderr" "resolved the hostname as 'Mac'.*\[machines\.host\.prateek-personal-mbp\].*run chezmoi apply again"
}

@test "pinning continues the apply when it already rendered under LocalHostName" {
  printf 'prateek-personal-mbp\n' >"$FIXTURE/names/LocalHostName"
  run_bash 0 "$scenario" prateek-personal-mbp
  assert_success
  assert_equal "$(cat "$FIXTURE/names/HostName")" prateek-personal-mbp.local
  assert_output 'HostName pinned to prateek-personal-mbp.local.'
}

@test "an explicit HostName is left alone without asking for sudo" {
  printf 'jamf-assigned\n' >"$FIXTURE/names/HostName"
  printf 'prateek-personal-mbp\n' >"$FIXTURE/names/LocalHostName"
  run_bash 0 "$scenario" jamf-assigned
  assert_success
  assert_equal "$(cat "$FIXTURE/names/HostName")" jamf-assigned
  [ ! -s "$FIXTURE/sudo.log" ]
}

@test "missing LocalHostName warns instead of inventing a name" {
  run_bash 0 "$scenario" Mac
  assert_success
  assert_regex "$stderr" 'warning: HostName and LocalHostName are both unset'
  [ ! -e "$FIXTURE/names/HostName" ]
  [ ! -s "$FIXTURE/sudo.log" ]
}

@test "secrets-enabled preflight stops the apply until the token is readable" {
  local no_pin='{"machines_local":{"pin_hostname":false,"agent_session_wiki":false}}'
  render_template "$hook" personal "$no_pin" >"$FIXTURE/rendered.sh"
  run_bash 1 "$FIXTURE/rendered.sh"
  assert_regex "$stderr" 'error: secrets_enabled is on, but the 1Password service account token is not in the login keychain'
  printf 'secret\n' >"$FIXTURE/names/token"
  : >"$FIXTURE/names/locked"
  run_bash 1 "$FIXTURE/rendered.sh"
  assert_regex "$stderr" 'error: .*unreadable.*security unlock-keychain'
  rm "$FIXTURE/names/locked"
  run_bash 0 "$FIXTURE/rendered.sh"
  assert_success
  assert_equal "$output$stderr" ''
  render_template "$hook" personal '{"machines_local":{"pin_hostname":false,"agent_session_wiki":false,"secrets_enabled":false}}' >"$FIXTURE/rendered.sh"
  [ ! -s "$FIXTURE/rendered.sh" ]
}

@test "interactive bootstrap fills a missing token from the operator's 1Password session" {
  cat >"$FIXTURE/bin/op" <<'STUB'
#!/usr/bin/env bash
printf '%s service-account-env=%s\n' "$*" "${OP_SERVICE_ACCOUNT_TOKEN-unset}" >>"$FIXTURE/op.calls"
printf 'ops_fixtureToken123'
STUB
  chmod +x "$FIXTURE/bin/op"
  render_template "$hook" personal '{"machines_local":{"pin_hostname":false,"agent_session_wiki":false}}' >"$FIXTURE/rendered.sh"
  # A plain apply never prompts, even at a terminal.
  CHEZMOI_COMMAND=apply run in_pty bash "$FIXTURE/rendered.sh"
  assert_failure
  assert_output --partial 'Fetch it from 1Password with: chezmoi init --apply'
  [ ! -e "$FIXTURE/op.calls" ]
  [ ! -s "$FIXTURE/names/token" ]
  CHEZMOI_COMMAND=init OP_SERVICE_ACCOUNT_TOKEN=inherited run in_pty bash "$FIXTURE/rendered.sh"
  assert_success
  assert_output --partial 'Stored the 1Password service account token in the login keychain.'
  assert_equal "$(cat "$FIXTURE/names/token")" ops_fixtureToken123
  assert_equal "$(cat "$FIXTURE/op.calls")" \
    'read --no-newline op://sit2vqyvky7qzyumcj7j3mlf24/r2rps74devyaosclqz53law3py/credential service-account-env=unset'
  run -1 grep -F ops_fixtureToken123 "$FIXTURE/security.argv"
}
