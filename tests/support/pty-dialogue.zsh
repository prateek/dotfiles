#!/bin/zsh
set -euo pipefail
zmodload zsh/datetime
zmodload zsh/zpty
zmodload zsh/zselect
zmodload zsh/system
owner_pid="$sysparams[pid]"

transcript="$1"
prompt="$2"
response="$3"
shift 3
name="dialogue_${$}"
output=''
chunk=''
rm -f "$transcript.pid" "$transcript.status"
TRAPEXIT() {
  [[ "$sysparams[pid]" == "$owner_pid" ]] || return 0
  zpty -d "$name" 2>/dev/null || true
  print -rn -- "$output" > "$transcript"
}
TRAPTERM() { exit 143; }
TRAPINT() { exit 130; }

command=(/bin/zsh -f -c '
  transcript="$1"; shift
  print -r -- $$ > "$transcript.pid"
  "$@"
  print -r -- $? > "$transcript.status"
' _ "$transcript" "$@")
# zpty evaluates its arguments as shell text; preserve each literal argument.
zpty -b "$name" "${(q)command[@]}"
start=$EPOCHREALTIME
until [[ "$output" == *"$prompt"* ]]; do
  if zpty -rt "$name" chunk; then
    output+="$chunk"
  fi
  if [[ -f "$transcript.status" ]] && ! zpty -t "$name"; then
    print -u2 -- "command exited before prompt"
    exit 1
  fi
  if (( EPOCHREALTIME - start > 3 )); then
    print -u2 -- "prompt deadline exceeded"
    exit 124
  fi
  zselect -t 1 || true
done
zpty -w -n "$name" "$response"$'\n'
start=$EPOCHREALTIME
while [[ ! -f "$transcript.status" ]] || zpty -t "$name"; do
  if zpty -rt "$name" chunk; then
    output+="$chunk"
  fi
  if (( EPOCHREALTIME - start > 5 )); then
    print -u2 -- "completion deadline exceeded"
    exit 124
  fi
  zselect -t 1 || true
done
while zpty -rt "$name" chunk; do
  output+="$chunk"
done
exit "$(<"$transcript.status")"
