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

wait_for_file_gone() {
  local path="$1"
  local attempt

  for attempt in {1..100}; do
    [[ ! -e "$path" ]] && return 0
    /bin/sleep 0.05
  done

  return 1
}

run_helper_case() {
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  bash <<'EOF'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

dotfiles_sudo_start "test phase needs sudo"
dotfiles_sudo_start "second phase should reuse sudo"

pid_file="$(dotfiles_sudo_pid_file)"
parent_pid_file="$(dotfiles_sudo_parent_pid_file)"
[ -s "$pid_file" ]
[ -s "$parent_pid_file" ]
pid="$(cat "$pid_file")"
kill -0 "$pid"

dotfiles_sudo_stop
[ ! -e "$pid_file" ]
[ ! -e "$parent_pid_file" ]
EOF
}

run_auto_cleanup_case() {
  local pid_file_record="$tmp_root/auto-pid-file"
  local keepalive_pid_record="$tmp_root/auto-keepalive-pid"
  local parent_pid_file pid_file preexisting_file

  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  AUTO_PID_FILE_RECORD="$pid_file_record" \
  AUTO_KEEPALIVE_PID_RECORD="$keepalive_pid_record" \
  bash <<'EOF'
set -euo pipefail

bash <<'INNER'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

dotfiles_sudo_start "test phase needs sudo"

pid_file="$(dotfiles_sudo_pid_file)"
[ -s "$pid_file" ]
pid="$(cat "$pid_file")"
kill -0 "$pid"

printf '%s\n' "$pid_file" >"$AUTO_PID_FILE_RECORD"
printf '%s\n' "$pid" >"$AUTO_KEEPALIVE_PID_RECORD"
INNER
EOF

  [[ -s "$pid_file_record" ]] || die "automatic cleanup case did not record pid file"
  [[ -s "$keepalive_pid_record" ]] || die "automatic cleanup case did not record keepalive pid"

  pid_file="$(<"$pid_file_record")"
  parent_pid_file="${pid_file:h}/parent.pid"
  preexisting_file="${pid_file:h}/preexisting"

  wait_for_file_gone "$pid_file" || die "parent-exit cleanup should remove sudo pid file"
  [[ ! -e "$parent_pid_file" ]] || die "parent-exit cleanup should remove sudo parent marker"
  [[ ! -e "$preexisting_file" ]] || die "parent-exit cleanup should remove sudo preexisting marker"
}

run_chezmoi_parent_case() {
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  bash -c 'exec -a chezmoi bash -s' <<'EOF'
set -euo pipefail

run_managed_script() {
  bash -c 'bash -s; :' <<'INNER'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

dotfiles_sudo_start "managed script needs sudo"
INNER
}

run_managed_script
/bin/sleep 2
run_managed_script

source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"
dotfiles_sudo_stop
EOF
}

run_stale_parent_case() {
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  bash <<'EOF'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

state_dir="$(dotfiles_sudo_state_dir)"
pid_file="$(dotfiles_sudo_pid_file)"
parent_pid_file="$(dotfiles_sudo_parent_pid_file)"
preexisting_file="$(dotfiles_sudo_preexisting_file)"
mkdir -p "$state_dir"

/bin/sleep 30 &
stale_pid="$!"
printf '%s\n' "$stale_pid" >"$pid_file"
printf '%s\n' 999999 >"$parent_pid_file"
printf '%s\n' 1 >"$preexisting_file"

dotfiles_sudo_start "stale parent should restart"

new_pid="$(cat "$pid_file")"
[ "$new_pid" != "$stale_pid" ]
! kill -0 "$stale_pid" 2>/dev/null
[ -s "$parent_pid_file" ]

dotfiles_sudo_stop
[ ! -e "$pid_file" ]
[ ! -e "$parent_pid_file" ]
EOF
}

run_missing_parent_marker_case() {
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  bash <<'EOF'
set -euo pipefail
source "$DOTFILES_ROOT/home/.chezmoitemplates/script_lib.sh"

state_dir="$(dotfiles_sudo_state_dir)"
pid_file="$(dotfiles_sudo_pid_file)"
parent_pid_file="$(dotfiles_sudo_parent_pid_file)"
preexisting_file="$(dotfiles_sudo_preexisting_file)"
mkdir -p "$state_dir"

/bin/sleep 30 &
stale_pid="$!"
printf '%s\n' "$stale_pid" >"$pid_file"
printf '%s\n' 1 >"$preexisting_file"
rm -f "$parent_pid_file"

dotfiles_sudo_start "missing parent marker should restart"

new_pid="$(cat "$pid_file")"
[ "$new_pid" != "$stale_pid" ]
! kill -0 "$stale_pid" 2>/dev/null
[ -s "$parent_pid_file" ]

dotfiles_sudo_stop
[ ! -e "$pid_file" ]
[ ! -e "$parent_pid_file" ]
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

# Separate chezmoi run scripts share one sudo validation through the long-lived
# chezmoi apply process, even when short shell wrappers exit between scripts.
: > "$SUDO_LOG"
rm -f "$SUDO_WARMED"
run_chezmoi_parent_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 1 ]] || die "chezmoi parent should prompt once across managed scripts"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 1 ]] || die "chezmoi parent should clear a cold cache once"

# A live helper whose parent process has exited is stale and must be replaced
# before a new apply reuses the shared sudo state.
: > "$SUDO_LOG"
: > "$SUDO_WARMED"
run_stale_parent_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 0 ]] || die "stale parent restart should reuse warm sudo"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 0 ]] || die "stale parent restart should not invalidate warm sudo"
[[ -e "$SUDO_WARMED" ]] || die "stale parent restart should preserve the warm marker"

# State written by older helpers without a parent marker is stale under the new
# cleanup contract.
: > "$SUDO_LOG"
: > "$SUDO_WARMED"
run_missing_parent_marker_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 0 ]] || die "missing parent marker restart should reuse warm sudo"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 0 ]] || die "missing parent marker restart should not invalidate warm sudo"
[[ -e "$SUDO_WARMED" ]] || die "missing parent marker restart should preserve the warm marker"

# The keepalive cleans itself up shortly after the chezmoi parent process exits.
# This case uses the production `sleep` command so the test exercises the real
# parent-polling interval instead of forcing the keepalive out of sleep.
: > "$SUDO_LOG"
rm -f "$SUDO_WARMED"
run_auto_cleanup_case >/dev/null
[[ "$(grep -c -- '^-v$' "$SUDO_LOG")" -eq 1 ]] || die "parent-exit cleanup should prompt once for a cold cache"
[[ "$(grep -c -- '^-k$' "$SUDO_LOG")" -eq 1 ]] || die "parent-exit cleanup should clear a cold cache"
[[ ! -e "$SUDO_WARMED" ]] || die "parent-exit cleanup should clear the warm marker"

print -- "OK sudo-keepalive"
