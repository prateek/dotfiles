#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=home/.chezmoitemplates/script_lib.sh
source "$FIXTURE/script_lib.sh"

pid_file="$(dotfiles_sudo_pid_file)"
parent_file="$(dotfiles_sudo_parent_pid_file)"
preexisting_file="$(dotfiles_sudo_preexisting_file)"
owner="$BASHPID"
stale_pid=''
cleanup() {
  [[ "$BASHPID" == "$owner" ]] || return 0
  dotfiles_sudo_stop
  if [[ -n "$stale_pid" ]]; then
    kill "$stale_pid" 2>/dev/null || true
    wait "$stale_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

case "$1" in
  reuse)
    dotfiles_sudo_start 'first phase'
    first_pid="$(cat "$pid_file")"
    kill -0 "$first_pid"
    dotfiles_sudo_start 'second phase'
    [[ "$(cat "$pid_file")" == "$first_pid" ]]
    [[ -s "$parent_file" ]]
    dotfiles_sudo_stop
    ! kill -0 "$first_pid" 2>/dev/null
    ;;
  stale|missing)
    mkdir -p "$(dirname "$pid_file")"
    /bin/sleep 30 &
    stale_pid="$!"
    printf '%s\n' "$stale_pid" > "$pid_file"
    printf '1\n' > "$preexisting_file"
    if [[ "$1" == stale ]]; then
      printf '999999\n' > "$parent_file"
    fi
    dotfiles_sudo_start 'replace stale state'
    new_pid="$(cat "$pid_file")"
    [[ "$new_pid" != "$stale_pid" ]]
    ! kill -0 "$stale_pid" 2>/dev/null
    kill -0 "$new_pid"
    [[ -s "$parent_file" ]]
    dotfiles_sudo_stop
    ! kill -0 "$new_pid" 2>/dev/null
    ;;
  shared)
    bash -c 'exec -a chezmoi bash -s' <<'SHARED'
set -euo pipefail
source "$FIXTURE/script_lib.sh"
trap dotfiles_sudo_stop EXIT
run_managed_script() {
  bash -c 'bash -s; :' <<'MANAGED'
set -euo pipefail
source "$FIXTURE/script_lib.sh"
dotfiles_sudo_start 'managed script'
cat "$(dotfiles_sudo_pid_file)" >> "$FIXTURE/shared-pids"
MANAGED
}
run_managed_script
/bin/sleep 2
run_managed_script
SHARED
    [[ "$(sort -u "$FIXTURE/shared-pids" | wc -l | tr -d ' ')" == 1 ]]
    [[ "$(wc -l < "$FIXTURE/shared-pids" | tr -d ' ')" == 2 ]]
    ! kill -0 "$(head -1 "$FIXTURE/shared-pids")" 2>/dev/null
    ;;
  race)
    export DOTFILES_TEST_SELF_PID="$$" DOTFILES_TEST_PARENT_PID="$PPID"
    dotfiles_sudo_start 'parent lookup race'
    [[ "$(cat "$parent_file")" == "$PPID" ]]
    dotfiles_sudo_stop
    ;;
  *) exit 2 ;;
esac
[[ ! -e "$pid_file" && ! -e "$parent_file" && ! -e "$preexisting_file" ]]
