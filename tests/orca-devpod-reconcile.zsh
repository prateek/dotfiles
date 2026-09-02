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

set +e
output="$(
  HOME="$tmp/home" \
  XDG_CACHE_HOME="$tmp/home/.cache" \
  XDG_CONFIG_HOME="$tmp/home/.config" \
  XDG_STATE_HOME="$tmp/home/.local/state" \
  PATH="$fake_bin:/usr/bin:/bin" \
    /bin/bash "$reconciler" start 2>&1
)"
rc=$?
set -e

[[ $rc -ne 0 ]] || die "corrupt download should fail"
[[ "$output" == *"checksum mismatch"* ]] || die "checksum failure was not reported"
[[ ! -e "$RECONCILE_TEST_LOG" ]] || die "package installer ran after checksum failure"

installed_reconciler="$tmp/orca-devpod-reconcile"
fake_orca="$fake_bin/orca-ide"
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
printf '%s\n' '1.4.193'
EOF
printf '%s\n' "valid package" \
  >"$tmp/home/.cache/orca/1.4.193/orca-ide_1.4.193_amd64.deb"

set +e
output="$(
  HOME="$tmp/home" \
  XDG_CACHE_HOME="$tmp/home/.cache" \
  XDG_CONFIG_HOME="$tmp/home/.config" \
  XDG_STATE_HOME="$tmp/home/.local/state" \
  PATH="$fake_bin:/usr/bin:/bin" \
    /bin/bash "$installed_reconciler" start 2>&1
)"
rc=$?
set -e

[[ $rc -eq 0 ]] || die "installed Orca launch failed: $output"
[[ "$output" == *"ready on remote port 6768"* ]] ||
  die "installed Orca did not reach the tmux launch path"
[[ ! -e "$RECONCILE_FD9_MARKER" ]] ||
  die "tmux child inherited reconcile lock fd 9"

print -- "OK orca-devpod-reconcile"
