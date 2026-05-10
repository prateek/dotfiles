#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "sudo-keepalive: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin" "$tmp_root/run"

export SUDO_LOG="$tmp_root/sudo.log"
export SUDO_WARMED="$tmp_root/sudo-warmed"
export XDG_RUNTIME_DIR="$tmp_root/run"

cat >"$stub_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SUDO_LOG"

case "$*" in
  "-n -v")
    [ -e "$SUDO_WARMED" ]
    ;;
  "-v")
    : > "$SUDO_WARMED"
    ;;
  "-k")
    rm -f "$SUDO_WARMED"
    ;;
  *)
    ;;
esac
EOF
chmod +x "$stub_bin/sudo"

run_helper_case() {
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  bash <<'EOF'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

dotfiles_sudo_start "test phase needs sudo"
dotfiles_sudo_start "second phase should reuse sudo"

pid_file="$(dotfiles_sudo_pid_file)"
[ -s "$pid_file" ]
pid="$(cat "$pid_file")"
kill -0 "$pid"

dotfiles_sudo_stop
[ ! -e "$pid_file" ]
EOF
}

# Cold sudo cache: one real validation, reused by the second start, then cleared.
: > "$SUDO_LOG"
rm -f "$SUDO_WARMED"
run_helper_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 1 ]] || die "cold cache should run sudo -v once"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 1 ]] || die "cold cache should be cleared on stop"

# Warm sudo cache: keepalive may refresh, but stop must not invalidate it.
: > "$SUDO_LOG"
: > "$SUDO_WARMED"
run_helper_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 0 ]] || die "warm cache should not prompt with sudo -v"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 0 ]] || die "warm cache should not be invalidated"
[[ -e "$SUDO_WARMED" ]] || die "warm cache marker should survive stop"

print -- "OK sudo-keepalive"
