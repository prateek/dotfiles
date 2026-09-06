#!/bin/zsh
set -euo pipefail
zmodload zsh/datetime
zmodload zsh/zselect
zmodload zsh/system
owner="$sysparams[pid]"
keepalive=''
TRAPEXIT() {
  [[ "$sysparams[pid]" == "$owner" ]] || return 0
  if [[ -z "$keepalive" && -f "$FIXTURE/helper-pid" ]]; then
    keepalive="$(<"$FIXTURE/helper-pid")"
  fi
  if [[ -n "$keepalive" ]] && kill -0 "$keepalive" 2>/dev/null; then
    kill "$keepalive"
    local start=$EPOCHREALTIME
    while kill -0 "$keepalive" 2>/dev/null; do
      (( EPOCHREALTIME - start < 3 )) || return 1
      zselect -t 1 || true
    done
  fi
}
TRAPTERM() { exit 143; }
TRAPINT() { exit 130; }
bash -c 'bash -s; :' <<'INNER'
set -euo pipefail
source "$FIXTURE/script_lib.sh"
dotfiles_sudo_start 'parent-exit cleanup'
pid_file="$(dotfiles_sudo_pid_file)"
printf '%s\n' "$pid_file" > "$FIXTURE/pid-file"
cat "$pid_file" > "$FIXTURE/helper-pid"
kill -0 "$(cat "$pid_file")"
INNER
keepalive="$(cat "$FIXTURE/helper-pid")"
pid_file="$(cat "$FIXTURE/pid-file")"
start=$EPOCHREALTIME
while kill -0 "$keepalive" 2>/dev/null || [[ -e "$pid_file" ]]; do
  if (( EPOCHREALTIME - start > 5 )); then
    print -u2 -- "parent-exit cleanup failed: helper $keepalive or its state survived"
    exit 1
  fi
  zselect -t 1 || true
done
[[ ! -e "${pid_file:h}/parent.pid" && ! -e "${pid_file:h}/preexisting" ]]
[[ ! -e "$FIXTURE/warmed" ]]
