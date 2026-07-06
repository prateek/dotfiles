#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
script="$REPO_ROOT/home/dot_pi/agent/executable_statusline.sh"

strip_ansi() {
  sed $'s/\033\[[0-9;]*m//g'
}

die() {
  print -u2 "$1"
  exit 1
}

base='{
  "model": {"id": "claude-fable-5", "display_name": "Fable 5"},
  "workspace": {"current_dir": "/Users/prungta/code/worktrees/dotfiles/pi-status-line-configure"},
  "cost": {"total_duration_ms": 10200000},
  "context_window": {
    "used_percentage": 1,
    "total_input_tokens": 45000,
    "total_output_tokens": 9000,
    "context_window_size": 300000,
    "current_usage": {
      "input_tokens": 3000,
      "output_tokens": 600,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0
    }
  },
  "pi": {"session_file": null}
}'

# Pi's statusline adapter sends aggregate total_input_tokens and latest-response
# current_usage. The aggregate is the useful context-used value for the footer.
out=$(printf '%s' "$base" | sh "$script" | strip_ansi)
for want in "Fable 5" "dotfiles/pi-status-line-configure" "2h50m" \
  "ctx ██░░░░░░░░ 15% 45k/300k"; do
  [[ "$out" == *"$want"* ]] || die "missing '$want' in: $out"
done

# If Pi's aggregate token total grows beyond the active context window, fall
# back to the adapter percentage instead of rendering impossible totals.
over_window=$(printf '%s' "$base" | jq -c '.context_window.used_percentage = 58
  | .context_window.total_input_tokens = 800000')
out=$(printf '%s' "$over_window" | sh "$script" | strip_ansi)
[[ "$out" == *"ctx ██████░░░░ 58% 174k/300k"* ]] || die "over-window tokens not derived from pct: $out"
[[ "$out" != *"800k"* ]] || die "over-window token count leaked: $out"
unknown_window=$(printf '%s' "$over_window" | jq -c '.context_window.used_percentage = 0')
out=$(printf '%s' "$unknown_window" | sh "$script" | strip_ansi)
[[ "$out" != *"ctx"* ]] || die "unknown over-window context should stay hidden: $out"

# Pi session files record compactions as type=compaction entries.
pi_session=$(mktemp)
trap 'rm -f "$pi_session"' EXIT
{
  print -r -- '{"type":"message","message":{"role":"user"}}'
  print -r -- '{"type":"compaction","summary":"first"}'
  print -r -- '{"type":"message","message":{"role":"assistant"}}'
  print -r -- '{"type": "compaction", "summary": "second"}'
} > "$pi_session"
compacted=$(printf '%s' "$base" | jq -c --arg t "$pi_session" '.pi.session_file = $t')
out=$(printf '%s' "$compacted" | sh "$script" | strip_ansi)
[[ "$out" == *"45k/300k (x2)"* ]] || die "missing pi compaction count: $out"

# Empty or zero-token context hides the context segment.
empty=$(printf '%s' "$base" | jq -c '.context_window = {
  used_percentage: 0,
  total_input_tokens: 0,
  context_window_size: 300000
}')
out=$(printf '%s' "$empty" | sh "$script" | strip_ansi)
[[ "$out" != *"ctx"* ]] || die "empty context segment not hidden: $out"

# Minimal payload renders one line and exits cleanly.
minimal='{"model": {"display_name": "Fable 5"}, "workspace": {"current_dir": "/tmp"}}'
out=$(printf '%s' "$minimal" | sh "$script" | strip_ansi)
[[ "$out" == "Fable 5 | /tmp" ]] || die "unexpected minimal render: $out"

# Malformed stdin must not crash or hang.
out=$(printf 'not json' | sh "$script")
[[ "$out" == "pi-statusline: unreadable payload" ]] || die "unexpected garbage render: $out"
out=$(printf 'not json' | sh "$script" --logical)
[[ "$out" == "pi-statusline: unreadable payload" ]] || die "unexpected garbage logical: $out"

# --logical is the testing seam: the computed document as JSON, no ANSI.
logical=$(printf '%s' "$base" | sh "$script" --logical)
for probe in '.model.name == "Fable 5"' '.ctx.pct == 15' '.ctx.used == "45k"' \
  '.ctx.size == "300k"' '.ctx.level == "ok"'; do
  printf '%s' "$logical" | jq -e "$probe" >/dev/null \
    || die "logical probe failed: $probe in: $logical"
done

print "pi-statusline: OK"
