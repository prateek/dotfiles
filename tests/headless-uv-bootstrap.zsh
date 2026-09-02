#!/usr/bin/env zsh
set -euo pipefail

ROOT="${0:A:h:h}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

die() {
  print -u2 -- "headless-uv-bootstrap test: $*"
  exit 1
}

hook="$ROOT/scripts/chezmoi-hooks/headless-uv.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$hook"
fi

export HOME="$tmp/home"
fake_bin="$tmp/bin"
mkdir -p "$fake_bin" "$HOME"
export UV_BOOTSTRAP_TEST_LOG="$tmp/calls"

cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -s) printf '%s\n' Linux ;;
  -m) printf '%s\n' x86_64 ;;
  *) exit 2 ;;
esac
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
set -eu
printf 'curl %s\n' "$*" >>"$UV_BOOTSTRAP_TEST_LOG"
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    shift
    printf '%s\n' archive >"$1"
    exit 0
  fi
  shift
done
exit 2
EOF

cat >"$fake_bin/sha256sum" <<'EOF'
#!/bin/sh
set -eu
IFS= read -r checksum
printf 'sha256sum %s\n' "$checksum" >>"$UV_BOOTSTRAP_TEST_LOG"
[ "${UV_BOOTSTRAP_TEST_CHECKSUM_FAIL:-false}" != "true" ]
EOF

cat >"$fake_bin/tar" <<'EOF'
#!/bin/sh
set -eu
destination=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-C" ]; then
    shift
    destination="$1"
  fi
  shift
done
[ -n "$destination" ]
mkdir -p "$destination/uv-x86_64-unknown-linux-gnu"
cat >"$destination/uv-x86_64-unknown-linux-gnu/uv" <<'UV'
#!/bin/sh
printf '%s\n' 'uv 0.12.9'
UV
chmod +x "$destination/uv-x86_64-unknown-linux-gnu/uv"
EOF

chmod +x "$fake_bin"/*

: >"$UV_BOOTSTRAP_TEST_LOG"
stdout="$(PATH="$fake_bin:/usr/bin:/bin" "$hook" 2>"$tmp/stderr")"
[[ -z "$stdout" ]] || die "hook polluted command stdout"
[[ -x "$HOME/.local/bin/uv" ]] || die "uv was not installed"
grep -Fq \
  "https://github.com/astral-sh/uv/releases/download/0.12.9/uv-x86_64-unknown-linux-gnu.tar.gz" \
  "$UV_BOOTSTRAP_TEST_LOG" || die "download was not version-pinned"
grep -Fq \
  "ec7a99cd05e0cd7f80243f135ce1361c76835cb0ee60055d14d20eba8eba1460" \
  "$UV_BOOTSTRAP_TEST_LOG" || die "archive checksum was not verified"

: >"$UV_BOOTSTRAP_TEST_LOG"
PATH="$fake_bin:/usr/bin:/bin" "$hook" >/dev/null
[[ ! -s "$UV_BOOTSTRAP_TEST_LOG" ]] ||
  die "an existing uv installation was downloaded again"

rm -f "$HOME/.local/bin/uv"
: >"$UV_BOOTSTRAP_TEST_LOG"
if PATH="$fake_bin:/usr/bin:/bin" \
  UV_BOOTSTRAP_TEST_CHECKSUM_FAIL=true \
  "$hook" >/dev/null 2>&1; then
  die "invalid checksum should fail closed"
fi
[[ ! -e "$HOME/.local/bin/uv" ]] || die "invalid archive was installed"

echo "OK headless-uv-bootstrap"
