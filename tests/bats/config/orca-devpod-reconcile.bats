load '../../support/common'

setup() {
  setup_fixture
  export RECONCILE_LOG="$FIXTURE/calls"
  : >"$RECONCILE_LOG"
  script="$DOTFILES_ROOT/home/dot_local/bin/executable_orca-devpod-reconcile"
  version="$(sed -n 's/^readonly ORCA_VERSION="\(.*\)"$/\1/p' "$script")"
  export STUB_SESSION="$FIXTURE/tmux-session"
  deb="$XDG_CACHE_HOME/orca/$version/orca-ide_${version}_amd64.deb"
  mkdir -p "${deb%/*}"
  : >"$deb"

  stub uname 'echo Linux'
  stub flock ''
  stub pgrep 'exit 1'
  stub pkill ''
  stub getent 'echo "me:x:1000:1000::/home/me:/bin/bash"'
  stub sha256sum ''
  stub dpkg 'echo amd64'
  stub dpkg-query "printf %s $version"
  stub curl 'exit 1'
  stub sudo '"$@"'
  stub timeout 'shift; "$@"'
  stub apt-get ''
  # tmux runs the runner in the foreground and tracks one session in a file.
  stub tmux 'case "$1" in
  has-session) [[ -e "$STUB_SESSION" ]] ;;
  kill-session) rm -f "$STUB_SESSION" ;;
  new-session) : >"$STUB_SESSION"; "${@: -1}" ;;
esac'
  # The server reports ready, and makes a pairing offer unless told not to.
  stub orca-ide 'pairing=",\"pairing\":{\"url\":\"orca://pair?code=secret\"}"
[[ " $* " != *" --no-pairing "* ]] || pairing=""
printf "starting\n{\"type\":\"orca_server_ready\",\"boundEndpoint\":\"ws://0.0.0.0:6768\"%s}\n" "$pairing"'
  export ORCA_IDE_BIN="$FIXTURE/bin/orca-ide"
}

# Each stub records its name and arguments, then runs its body.
stub() {
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "${0##*/}" "$*" >>"$RECONCILE_LOG"\n%s\n' "$2" >"$FIXTURE/bin/$1"
  chmod +x "$FIXTURE/bin/$1"
}

@test "Pairing prints only the pairing URL on stdout" {
  run_bash 0 "$script" pair
  assert_success
  assert_output "orca://pair?code=secret"
  [[ "$stderr" != *"code=secret"* ]]
}

@test "A repeat start with the same runner and package changes nothing" {
  run_bash 0 "$script" start
  assert_success
  : >"$RECONCILE_LOG"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" == *"already ready on remote port 6768"* ]]
  run grep -E '^(apt-get|tmux (new|kill)-session|orca-ide) ' "$RECONCILE_LOG"
  assert_failure
}
