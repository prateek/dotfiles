load '../../support/common'

setup() {
  setup_fixture
  export TUNNEL_LOG="$FIXTURE/calls"
  : >"$TUNNEL_LOG"
  script="$DOTFILES_ROOT/home/dot_local/bin/executable_devbox-orca-tunnel"
  export DEVBOX_WS=me-devbox-1
  export STUB_STATE=STATE_RUNNING

  # ssh -G reports the quoted droidcli ProxyCommand that ssh-config writes;
  # the forwarding ssh returns as if the server closed the session.
  stub ssh "[[ \"\$1\" != -G ]] || echo \"proxycommand /usr/bin/env PATH=x '$FIXTURE/bin/droidcli' devpod ssh %h --proxy\""
  stub droidcli 'case "$2" in
  list) printf "[{\"name\":\"other-devbox\",\"state\":\"STATE_STOPPED\"},{\"name\":\"me-devbox-1\",\"state\":\"%s\"}]\n" "$STUB_STATE" ;;
esac'
  stub gcloud 'echo token'
  stub lsof 'exit 1'
  stub launchctl 'printf "\tstate = running\n"'
}

# Each stub records its name and arguments, then runs its body.
stub() {
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "${0##*/}" "$*" >>"$TUNNEL_LOG"\n%s\n' "$2" >"$FIXTURE/bin/$1"
  chmod +x "$FIXTURE/bin/$1"
}

@test "run starts a stopped box and then forwards to it" {
  export STUB_STATE=STATE_STOPPED
  run_bash 1 "$script" run
  assert_failure 1
  assert_line --partial 'ok    gcloud: application-default credentials valid'
  assert_line --partial 'workstation: me-devbox-1 stopped; starting it'
  assert_line --partial 'ok    workstation: me-devbox-1 started'
  run cat "$TUNNEL_LOG"
  assert_line 'droidcli devpod start --yes --log-level=error me-devbox-1'
  assert_line --regexp '^ssh -N .* -L 127\.0\.0\.1:16768:localhost:6768 me-devbox-1$'
}

@test "run leaves a running box alone and forwards to it" {
  run_bash 1 "$script" run
  assert_line --partial 'ok    workstation: me-devbox-1 running'
  assert_line --partial 'forwarding 127.0.0.1:16768 -> me-devbox-1:6768'
  run grep -c '^droidcli devpod start' "$TUNNEL_LOG"
  assert_output 0
}

@test "Expired gcloud credentials name the fix and keep launchd retrying" {
  stub gcloud 'echo "ERROR: (gcloud.auth.application-default.print-access-token) Reauthentication failed. invalid_rapt" >&2; exit 1'
  run_bash 1 "$script" run
  assert_line --partial 'FAIL  gcloud: application-default token failed: credentials need reauthentication (invalid_rapt)'
  assert_line --partial 'fix: gcloud auth application-default login'
  run grep -E '^(droidcli|ssh -N) ' "$TUNNEL_LOG"
  assert_failure
}

@test "A missing box name stops launchd retrying" {
  unset DEVBOX_WS
  run_bash 0 "$script" run
  assert_line --partial 'FAIL  box: no DEVBOX_WS in the environment or ~/.devbox.local'
  run grep -E '^(gcloud|droidcli|ssh) ' "$TUNNEL_LOG"
  assert_failure
}

@test "A box missing from the devpod list stops launchd retrying" {
  export DEVBOX_WS=gone-devbox-1
  run_bash 0 "$script" run
  assert_line --partial 'FAIL  workstation: gone-devbox-1 is not one of your devpods'
  run grep '^ssh -N ' "$TUNNEL_LOG"
  assert_failure
}

@test "run does not connect while another process holds the port" {
  stub lsof 'echo 4242'
  stub ps 'echo python3'
  run_bash 1 "$script" run
  assert_line --partial 'FAIL  port: 127.0.0.1:16768 is already held by pid 4242 (python3)'
  run grep '^ssh -N ' "$TUNNEL_LOG"
  assert_failure
}

@test "status reports a stopped box without starting it" {
  export STUB_STATE=STATE_STOPPED
  run_bash 1 "$script" status
  assert_failure 1
  assert_line 'ok    box: me-devbox-1'
  assert_line 'FAIL  workstation: me-devbox-1 stopped'
  assert_line 'FAIL  port: 127.0.0.1:16768 closed'
  run grep -c '^droidcli devpod start' "$TUNNEL_LOG"
  assert_output 0
}
