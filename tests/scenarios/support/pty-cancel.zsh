#!/bin/zsh
set -euo pipefail
zmodload zsh/datetime
zmodload zsh/zselect
runner="$1"
signal="${2:-TERM}"
expected="${3:-143}"
transcript="$FIXTURE/cancel-transcript"
/bin/zsh -f "$runner" "$transcript" '[Y/n]' '' /bin/zsh -f -c 'print -r -- $$ > "$FIXTURE/actual-child"; print -r -- ready > "$FIXTURE/ready"; read answer' 3>&- &
driver=$!
TRAPEXIT() {
  (( ZSH_SUBSHELL == 0 )) || return 0
  if kill -0 "$driver" 2>/dev/null; then
    kill -TERM "$driver"
    wait "$driver" || true
  fi
}
start=$EPOCHREALTIME
until [[ -s "$FIXTURE/ready" && -s "$transcript.pid" ]]; do
  (( EPOCHREALTIME - start < 3 )) || exit 1
  zselect -t 1 || true
done
kill -"$signal" "$driver"
if wait "$driver"; then
  rc=0
else
  rc=$?
fi
[[ $rc == "$expected" ]]
child="$(cat "$transcript.pid")"
start=$EPOCHREALTIME
while kill -0 "$child" 2>/dev/null; do
  (( EPOCHREALTIME - start < 3 )) || exit 1
  zselect -t 1 || true
done
child="$(cat "$FIXTURE/actual-child")"
while kill -0 "$child" 2>/dev/null; do
  (( EPOCHREALTIME - start < 3 )) || exit 1
  zselect -t 1 || true
done
[[ -f "$transcript" ]]
