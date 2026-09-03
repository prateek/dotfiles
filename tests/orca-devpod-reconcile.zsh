#!/usr/bin/env zsh

set -euo pipefail

die() {
  print -u2 -- "orca-devpod-reconcile: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
reconciler="$DOTFILES_ROOT/home/dot_local/bin/executable_orca-devpod-reconcile"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
mkdir -p "$fake_bin" "$tmp/home"
export RECONCILE_TEST_LOG="$tmp/calls"
export RECONCILE_TMUX_STATE="$tmp/tmux-state"
export RECONCILE_FD9_MARKER="$tmp/fd9-inherited"

run_reconciler() {
  local executable="$1"
  shift

  HOME="$tmp/home" \
  XDG_CACHE_HOME="$tmp/home/.cache" \
  XDG_CONFIG_HOME="$tmp/home/.config" \
  XDG_STATE_HOME="$tmp/home/.local/state" \
  PATH="$fake_bin:/usr/bin:/bin" \
    /bin/bash "$executable" "$@"
}

cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo Linux
EOF
cat >"$fake_bin/flock" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/sh
[ "${1:-}" = "--print-architecture" ] && echo amd64
EOF
cat >"$fake_bin/dpkg-query" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    shift
    printf 'corrupt package\n' >"$1"
    exit 0
  fi
  shift
done
exit 2
EOF
cat >"$fake_bin/sha256sum" <<'EOF'
#!/bin/bash
set -eu
IFS= read -r line
file="${line#*  }"
[[ -f "$file" && "$(<"$file")" == "valid package" ]]
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/sh
echo sudo >>"$RECONCILE_TEST_LOG"
exit 0
EOF
for command in apt-get ss; do
  cat >"$fake_bin/$command" <<'EOF'
#!/bin/sh
exit 0
EOF
done
cat >"$fake_bin/tmux" <<'EOF'
#!/bin/bash
set -eu
case "${1:-}" in
  has-session)
    [[ -e "$RECONCILE_TMUX_STATE" ]]
    ;;
  kill-session)
    rm -f "$RECONCILE_TMUX_STATE"
    ;;
  new-session)
    if (: >&9) 2>/dev/null; then
      touch "$RECONCILE_FD9_MARKER"
    fi
    touch "$RECONCILE_TMUX_STATE"
    mkdir -p "$XDG_STATE_HOME/orca-headless"
    printf '%s\n' \
      '{"type":"orca_server_ready","boundEndpoint":"ws://0.0.0.0:6768"}' \
      >"$XDG_STATE_HOME/orca-headless/serve.log"
    ;;
esac
EOF
chmod +x "$fake_bin"/*

if output="$(run_reconciler "$reconciler" start 2>&1)"; then
  die "corrupt download should fail"
fi
[[ "$output" == *"checksum mismatch"* ]] || die "checksum failure was not reported"
[[ ! -e "$RECONCILE_TEST_LOG" ]] || die "package installer ran after checksum failure"

installed_reconciler="$tmp/orca-devpod-reconcile"
fake_orca="$fake_bin/orca-ide"
export RECONCILE_INSTALLED_VERSION="$tmp/installed-version"
export RECONCILE_ORCA_BINARY="$fake_orca"
cat >"$fake_orca" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fake_orca"
python3 - "$reconciler" "$installed_reconciler" "$fake_orca" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
path = pathlib.Path(sys.argv[2])
path.write_text(source.replace("/usr/bin/orca-ide", sys.argv[3]))
path.chmod(0o755)
PY
cat >"$fake_bin/dpkg-query" <<'EOF'
#!/bin/sh
[ -f "$RECONCILE_INSTALLED_VERSION" ] || exit 1
cat "$RECONCILE_INSTALLED_VERSION"
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
set -eu
printf 'sudo %s\n' "$*" >>"$RECONCILE_TEST_LOG"
printf '%s\n' '1.4.193' >"$RECONCILE_INSTALLED_VERSION"
chmod +x "$RECONCILE_ORCA_BINARY"
EOF
chmod +x "$fake_bin/dpkg-query" "$fake_bin/sudo"
printf '%s\n' '1.4.193' >"$RECONCILE_INSTALLED_VERSION"
printf '%s\n' "valid package" \
  >"$tmp/home/.cache/orca/1.4.193/orca-ide_1.4.193_amd64.deb"

if ! output="$(run_reconciler "$installed_reconciler" start 2>&1)"; then
  die "installed Orca launch failed: $output"
fi
[[ "$output" == *"ready on remote port 6768"* ]] ||
  die "installed Orca did not reach the tmux launch path"
[[ ! -e "$RECONCILE_FD9_MARKER" ]] ||
  die "tmux child inherited reconcile lock fd 9"

run_reconciler "$installed_reconciler" disable-pairing >/dev/null

pairing_marker="$tmp/home/.config/orca/pairing-complete"
[[ -f "$pairing_marker" ]] || die "disable-pairing did not create the marker"
python3 - "$pairing_marker" <<'PY' || die "pairing marker mode is not 0600"
import pathlib
import stat
import sys

mode = stat.S_IMODE(pathlib.Path(sys.argv[1]).stat().st_mode)
raise SystemExit(0 if mode == 0o600 else 1)
PY
grep -Fq -- " --no-pairing --json" "$tmp/home/.local/state/orca-headless/run" ||
  die "disable-pairing did not restart Orca with --no-pairing"

printf '%s\n' '9.9.9' >"$RECONCILE_INSTALLED_VERSION"
: >"$RECONCILE_TEST_LOG"
run_reconciler "$installed_reconciler" start >/dev/null
grep -Fq -- "--allow-downgrades" "$RECONCILE_TEST_LOG" ||
  die "newer installed versions cannot be downgraded"
grep -Fq -- "--reinstall" "$RECONCILE_TEST_LOG" ||
  die "an installed package is not repaired during version reconciliation"

printf '%s\n' '1.4.193' >"$RECONCILE_INSTALLED_VERSION"
chmod -x "$fake_orca"
: >"$RECONCILE_TEST_LOG"
run_reconciler "$installed_reconciler" start >/dev/null
grep -Fq -- "--reinstall" "$RECONCILE_TEST_LOG" ||
  die "a broken pinned installation was not reinstalled"
[[ -x "$fake_orca" ]] || die "reinstall did not restore the Orca binary"

print -- "OK orca-devpod-reconcile"
