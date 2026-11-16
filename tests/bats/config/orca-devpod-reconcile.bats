load '../../support/common'

setup() {
  setup_fixture
  export RECONCILE_LOG="$FIXTURE/calls"
  : >"$RECONCILE_LOG"
  script="$DOTFILES_ROOT/home/dot_local/bin/executable_orca-devpod-reconcile"
  export STUB_SESSION="$FIXTURE/tmux-session"
  deb="$XDG_CACHE_HOME/orca/9.8.7/orca-ide_9.8.7_amd64.deb"

  # The latest release is 9.8.7, already installed, and its package is an empty
  # file, whose SHA-512 the manifest carries.
  export RELEASE_MANIFEST="$FIXTURE/latest-linux.yml" DEB_PAYLOAD=""
  export ORCA_INSTALLED="$FIXTURE/installed" CRONTAB_FILE="$FIXTURE/crontab"
  release 9.8.7
  printf 9.8.7 >"$ORCA_INSTALLED"

  stub uname 'echo Linux'
  stub flock ''
  # A process table of command lines: pgrep matches it and pkill removes from
  # it, each by the pattern in its last argument.
  export PROCESSES="$FIXTURE/processes"
  echo "/usr/bin/python3 /home/me/adc-watch.py" >"$PROCESSES"
  stub pgrep 'grep -Eq -- "${*: -1}" "$PROCESSES"'
  stub pkill 'grep -Ev -- "${*: -1}" "$PROCESSES" >"$PROCESSES.next"; mv "$PROCESSES.next" "$PROCESSES"'
  stub getent 'echo "me:x:1000:1000::/home/me:/bin/bash"'
  stub dpkg 'case "$1" in
  --print-architecture) echo amd64 ;;
  --compare-versions) [[ "$3" == lt && "$2" != "$4" && "$(printf "%s\n" "$2" "$4" | sort -V | head -n 1)" == "$2" ]] ;;
esac'
  stub dpkg-query 'cat "$ORCA_INSTALLED" 2>/dev/null'
  # Serves the manifest while it exists, and the package payload otherwise.
  stub curl 'url="${*: -1}"
while (($#)); do [[ "$1" != --output ]] || out="$2"; shift; done
case "$url" in
  */latest/download/latest-linux.yml) cp "$RELEASE_MANIFEST" "$out" 2>/dev/null || exit 22 ;;
  *) printf %s "$DEB_PAYLOAD" >"$out"; [[ -z "${DEB_FAIL:-}" ]] || exit 22 ;;
esac'
  stub sudo 'shift; "$@"'
  stub timeout 'shift; "$@"'
  # Installing a package makes dpkg-query report the version in its file name,
  # even when APT_FAIL makes the install fail after unpacking.
  stub apt-get 'package="${*: -1}"
[[ "$package" != *.deb ]] || { package="${package##*/orca-ide_}"; printf %s "${package%_amd64.deb}" >"$ORCA_INSTALLED"; }
[[ -z "${APT_FAIL:-}" ]] || exit 100'
  stub crontab '[[ -z "${CRONTAB_BROKEN:-}" ]] || { echo "crontab: cannot read the spool" >&2; exit 1; }
case "$1" in
  -l) cat "$CRONTAB_FILE" 2>/dev/null || { echo "no crontab for me" >&2; exit 1; } ;;
  -r) rm -f "$CRONTAB_FILE" ;;
  -) cat >"$CRONTAB_FILE" ;;
esac'
  # tmux runs the runner in the foreground and tracks one session in a file.
  stub tmux 'case "$1" in
  has-session) [[ -e "$STUB_SESSION" ]] ;;
  kill-session) rm -f "$STUB_SESSION" ;;
  new-session) : >"$STUB_SESSION"; "${@: -1}" ;;
esac'
  # The server refuses to start while another holds the data root. Otherwise it
  # leaves its orcad server and PTY daemon running detached, as Orca 1.4.261
  # does, reports ready, and makes a pairing offer unless told not to. An offer
  # also shows up in plain text, as a browser link carrying the code.
  stub orca-ide 'orcad="/home/me/.config/orca/orcad-artifacts/linux-x64-glibc"
if grep -q "orcad-server.js" "$PROCESSES"; then echo "orcad_instance_lock_held"; exit 3; fi
echo "$orcad/runtimes/node-1/bin/node $orcad/0.1.0+abc/orcad-server.js --bind 0.0.0.0 --port 6768" >>"$PROCESSES"
echo "$orcad/runtimes/node-1/bin/node --max-semi-space-size=4 $orcad/0.1.0+abc/daemon-entry.js --socket s" >>"$PROCESSES"
pairing=",\"pairing\":{\"url\":\"orca://pair?code=secret\"}"
link="open http://127.0.0.1:6768/#pairing=orca%3A%2F%2Fpair%3Fcode%3Dsecret"
[[ " $* " != *" --no-pairing "* ]] || { pairing=""; link=""; }
printf "starting\n%s\n{\"type\":\"orca_server_ready\",\"boundEndpoint\":\"ws://0.0.0.0:6768\"%s}\n" "$link" "$pairing"'
  export ORCA_IDE_BIN="$FIXTURE/bin/orca-ide"
}

# Publishes a release manifest naming version $1, with electron-builder's shape.
release() {
  cat >"$RELEASE_MANIFEST" <<YAML
version: $1
files:
  - url: orca-linux.AppImage
    sha512: appimage
    size: 1
  - url: orca-ide_$1_amd64.deb
    sha512: z4PhNX7vuL3xVChQ1m2AB9Yg5AULVxXcg/SpIdNs6c5H0NE8XYXysP+DGNKHfuwvY7kxvUdBeoGlODJ6+SfaPg==
    size: 0
path: orca-linux.AppImage
sha512: appimage
YAML
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

@test "Pairing keeps the code out of the serve log and leaves no offer behind" {
  run_bash 0 "$script" pair
  assert_success
  assert_output "orca://pair?code=secret"
  state="$XDG_STATE_HOME/orca-headless"
  run grep -c orca_server_ready "$state/serve.log"
  assert_output 1
  run grep -E 'secret|code%3D' "$state/serve.log"
  assert_failure
  [[ ! -e "$state/pairing-offer" ]]
}

@test "Start closes a pairing window and removes an unclaimed offer" {
  state="$XDG_STATE_HOME/orca-headless"
  mkdir -p "$state"
  printf 'orca://pair?code=stale\n' >"$state/pairing-offer"
  run_bash 0 "$script" start
  assert_success
  [[ ! -e "$state/pairing-offer" ]]
  run grep -- '--no-pairing' "$state/run"
  assert_success
}

@test "Start installs the release the manifest names and drops older packages" {
  old="$XDG_CACHE_HOME/orca/9.8.6/orca-ide_9.8.6_amd64.deb"
  mkdir -p "${old%/*}"
  : >"$old"
  printf 9.8.6 >"$ORCA_INSTALLED"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" == *"installing Orca 9.8.7 over 9.8.6"* ]]
  run grep -E '^(curl .*/download/|apt-get install)' "$RECONCILE_LOG"
  assert_line --index 0 --partial "https://github.com/stablyai/orca/releases/latest/download/latest-linux.yml"
  assert_line --index 1 --partial "https://github.com/stablyai/orca/releases/download/v9.8.7/orca-ide_9.8.7_amd64.deb"
  assert_line --index 2 "apt-get install -y --reinstall $deb"
  [[ -f "$deb" && ! -e "${old%/*}" ]]
  run grep -c '^orca-ide serve ' "$RECONCILE_LOG"
  assert_output 1
}

@test "A package that fails the manifest checksum is not installed" {
  export DEB_PAYLOAD="tampered"
  printf 9.8.6 >"$ORCA_INSTALLED"
  run_bash 1 "$script" start
  [[ "$stderr" == *"checksum mismatch for downloaded Orca package"* ]]
  run grep -E '^(apt-get install|orca-ide) ' "$RECONCILE_LOG"
  assert_failure
  [[ ! -e "$deb" ]]
}

@test "Start reuses the last manifest when the release cannot be fetched" {
  rm "$RELEASE_MANIFEST"
  run_bash 1 "$script" start
  [[ "$stderr" == *"cannot read the latest Orca release"* ]]

  cp "$BATS_TEST_DIRNAME/../../../README.md" "$RELEASE_MANIFEST"
  run_bash 1 "$script" start
  [[ "$stderr" == *"cannot read the latest Orca release"* ]]

  cat >"$RELEASE_MANIFEST" <<'YAML'
version: 9.8.7
files:
  - url: orca-ide_9.8.7_amd64.deb
    sha512: z4PhNX7vuL3xVChQ1m2AB9Yg5AULVxXcg/SpIdNs6c5H0NE8XYXysP+DGNKHfuwvY7kxvUdBeoGlODJ6+SfaPg==
YAML
  run_bash 0 "$script" start
  rm "$RELEASE_MANIFEST"
  rm -rf "$XDG_STATE_HOME/orca-headless" "$STUB_SESSION"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" == *"reusing the cached one"* ]]
  [[ "$stderr" == *"ready on remote port 6768"* ]]

  # A fetch that returns something else does not replace the cached manifest.
  echo '<html>rate limited</html>' >"$RELEASE_MANIFEST"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" == *"reusing the cached one"* ]]
  run grep -c '^version: 9.8.7$' "$XDG_CACHE_HOME/orca/latest-linux.yml"
  assert_output 1
}

@test "A manifest whose package fails to download is not kept for the fallback" {
  run_bash 0 "$script" start
  release 9.8.8
  DEB_FAIL=1 run_bash 1 "$script" start
  [[ "$stderr" == *"could not download Orca 9.8.8"* ]]
  [[ ! -e "$XDG_CACHE_HOME/orca/9.8.8" ]]
  run grep -c '^version: 9.8.7$' "$XDG_CACHE_HOME/orca/latest-linux.yml"
  assert_output 1
  # The running server and its package are untouched.
  [[ -e "$STUB_SESSION" && -f "$deb" ]]
}

@test "A corrupt cached package is downloaded again before it is installed" {
  mkdir -p "${deb%/*}"
  echo corrupt >"$deb"
  printf 9.8.6 >"$ORCA_INSTALLED"
  run_bash 0 "$script" start
  assert_success
  run grep -c '^curl .*/releases/download/v9.8.7/orca-ide_9.8.7_amd64.deb$' "$RECONCILE_LOG"
  assert_output 1
  [[ -f "$deb" && ! -s "$deb" ]]
}

@test "A newer release restarts a running server, even after its install failed partway" {
  run_bash 0 "$script" start
  release 9.8.8
  # apt unpacks 9.8.8, then fails: dpkg reports the new version from here on.
  APT_FAIL=1 run_bash 100 "$script" start
  : >"$RECONCILE_LOG"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" != *"already ready"* ]]
  run grep -cE '^(tmux kill-session|orca-ide serve) ' "$RECONCILE_LOG"
  assert_output 2
  [[ ! -e "$deb" && -f "$XDG_CACHE_HOME/orca/9.8.8/orca-ide_9.8.8_amd64.deb" ]]
}

@test "Stop ends the detached server and PTY daemon, and nothing else" {
  run_bash 0 "$script" start
  echo "/opt/Orca/orca-ide /opt/Orca/resources/app.asar.unpacked/out/main/daemon-entry.js --socket old" >>"$PROCESSES"
  run grep -c . "$PROCESSES"
  assert_output 4
  run_bash 0 "$script" stop
  assert_success
  run cat "$PROCESSES"
  assert_output "/usr/bin/python3 /home/me/adc-watch.py"
}

@test "A withdrawn release does not downgrade or restart the running server" {
  release 9.8.8
  printf 9.8.8 >"$ORCA_INSTALLED"
  run_bash 0 "$script" start
  release 9.8.7
  : >"$RECONCILE_LOG"
  run_bash 0 "$script" start
  assert_success
  [[ "$stderr" == *"latest release 9.8.7 is older than installed 9.8.8; keeping it"* ]]
  [[ "$stderr" == *"already ready on remote port 6768"* ]]
  run grep -E '^(apt-get|tmux (new|kill)-session|orca-ide) ' "$RECONCILE_LOG"
  assert_failure
  [[ -f "$XDG_CACHE_HOME/orca/9.8.8/orca-ide_9.8.8_amd64.deb" ]]
  run grep -c '^version: 9.8.8$' "$XDG_CACHE_HOME/orca/latest-linux.yml"
  assert_output 1
}

@test "Start closes a pairing window even when the install then fails" {
  run_bash 0 "$script" pair
  release 9.8.8
  DEB_FAIL=1 run_bash 1 "$script" start
  [[ "$stderr" == *"closing the pairing window"* ]]
  [[ ! -e "$STUB_SESSION" && ! -e "$XDG_STATE_HOME/orca-headless/run" ]]
}

@test "A crontab that cannot be read is left alone, and stop still stops the server" {
  printf '* * * * * other-job\n' >"$CRONTAB_FILE"
  CRONTAB_BROKEN=1 run_bash 1 "$script" start
  [[ "$stderr" == *"cannot read the crontab, so it is unchanged: crontab: cannot read the spool"* ]]
  CRONTAB_BROKEN=1 run_bash 1 "$script" stop
  [[ ! -e "$STUB_SESSION" ]]
  run cat "$CRONTAB_FILE"
  assert_output '* * * * * other-job'
  run grep -c '^crontab -$' "$RECONCILE_LOG"
  assert_output 0
}

@test "Start schedules one daily update beside other cron entries, and stop removes it" {
  printf '* * * * * other-job\n' >"$CRONTAB_FILE"
  # Cron runs the installed script by path, so install it as chezmoi does.
  install -m 755 "$script" "$HOME/orca-devpod-reconcile"
  script="$HOME/orca-devpod-reconcile"
  run_bash 0 "$script" start
  run_bash 0 "$script" start
  assert_success
  run grep -c 'orca-devpod-reconcile daily update' "$CRONTAB_FILE"
  assert_output 1
  run grep -c 'other-job' "$CRONTAB_FILE"
  assert_output 1

  # The scheduled command is a start that logs to the state directory.
  entry="$(grep 'orca-devpod-reconcile daily update' "$CRONTAB_FILE")"
  # It asks for the account's login shell, which would drop the stubs from
  # PATH here.
  [[ "$entry" == "0 9 * * * /bin/bash -lc "* ]]
  : >"$RECONCILE_LOG"
  run_without_reporting_fds 0 sh -c "bash -c ${entry#0 9 \* \* \* /bin/bash -lc }"
  assert_success
  run cat "$XDG_STATE_HOME/orca-headless/update.log"
  assert_output --partial "already ready on remote port 6768"

  run_bash 0 "$script" stop
  assert_success
  run cat "$CRONTAB_FILE"
  assert_output '* * * * * other-job'
}
