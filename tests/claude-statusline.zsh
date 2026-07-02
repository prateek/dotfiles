#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
script="$REPO_ROOT/home/dot_claude/executable_statusline.sh"

strip_ansi() {
  sed $'s/\033\[[0-9;]*m//g'
}

die() {
  print -u2 "$1"
  exit 1
}

base='{
  "model": {"id": "claude-fable-5", "display_name": "Fable 5"},
  "effort": {"level": "xhigh"},
  "workspace": {"current_dir": "/Users/prungta/code/worktrees/dotfiles/claude-acpx"},
  "cost": {"total_cost_usd": 6.8412, "total_duration_ms": 10200000},
  "context_window": {"used_percentage": 58, "total_input_tokens": 116000, "context_window_size": 200000}
}'
# 930s renders 15m for any test-vs-script clock skew under 30s; bare 900
# sits on the 14m/15m boundary and flakes.
h5_reset=$(( $(date +%s) + 930 ))
d7_reset=$(( $(date +%s) + 250000 ))  # ~2.9d out

# Subscription session below the weekly threshold: meters, no cost, no weekly.
sub=$(printf '%s' "$base" | jq -c --argjson h "$h5_reset" --argjson d "$d7_reset" \
  '.rate_limits = {five_hour: {used_percentage: 42, resets_at: $h}, seven_day: {used_percentage: 63, resets_at: $d}}')
out=$(printf '%s' "$sub" | sh "$script" | strip_ansi)
for want in "Fable 5 xhigh" "dotfiles/claude-acpx" "⏱ 2h50m" \
  "ctx ██████░░░░ 58% 116k/200k" "5h ████░░░░░░ 42% (15m)"; do
  [[ "$out" == *"$want"* ]] || die "missing '$want' in: $out"
done
for absent in '$' "7d"; do
  [[ "$out" != *"$absent"* ]] || die "unexpected '$absent' in subscription render: $out"
done
[[ $(printf '%s\n' "$out" | wc -l) -eq 1 ]] || die "expected 1 line: $out"

# Weekly meter appears only at >= 80%.
hot=$(printf '%s' "$sub" | jq -c '.rate_limits.seven_day.used_percentage = 85.4')
out=$(printf '%s' "$hot" | sh "$script" | strip_ansi)
[[ "$out" == *"7d 85% (3d)"* ]] || die "missing weekly meter in: $out"

# API-billed session (no rate_limits): cost replaces the meters.
out=$(printf '%s' "$base" | sh "$script" | strip_ansi)
[[ "$out" == *'$6.84'* ]] || die "missing cost in API render: $out"
for absent in "5h" "7d"; do
  [[ "$out" != *"$absent "* ]] || die "unexpected '$absent' in API render: $out"
done

# Pre-2.1.132 payloads report total_input_tokens as a cumulative session
# total. current_usage wins when present; otherwise the count is derived
# from used_percentage instead of showing an over-window number.
cumulative=$(printf '%s' "$base" | jq -c '.context_window.total_input_tokens = 800000
  | .context_window.current_usage = {input_tokens: 100000, cache_creation_input_tokens: 6000, cache_read_input_tokens: 10000}')
out=$(printf '%s' "$cumulative" | sh "$script" | strip_ansi)
[[ "$out" == *"58% 116k/200k"* ]] || die "current_usage not preferred: $out"
cumulative=$(printf '%s' "$base" | jq -c '.context_window.total_input_tokens = 800000')
out=$(printf '%s' "$cumulative" | sh "$script" | strip_ansi)
[[ "$out" == *"58% 116k/200k"* ]] || die "cumulative tokens not derived from pct: $out"
[[ "$out" != *"800k"* ]] || die "over-window token count leaked: $out"

# used_percentage 0 with real tokens loaded recomputes the percentage;
# 0 with no tokens hides the segment.
zeroed=$(printf '%s' "$base" | jq -c '.context_window = {used_percentage: 0,
  total_input_tokens: 20000, context_window_size: 200000}')
out=$(printf '%s' "$zeroed" | sh "$script" | strip_ansi)
[[ "$out" == *"ctx █░░░░░░░░░ 10% 20k/200k"* ]] || die "zero pct not recomputed: $out"
empty=$(printf '%s' "$base" | jq -c '.context_window = {used_percentage: 0,
  total_input_tokens: 0, context_window_size: 200000}')
out=$(printf '%s' "$empty" | sh "$script" | strip_ansi)
[[ "$out" != *"ctx"* ]] || die "empty context segment not hidden: $out"

# Compaction count comes from transcript compact_boundary entries; the same
# string inside message content is JSON-escaped and must not count.
transcript=$(mktemp)
trap 'rm -f "$transcript"' EXIT
{
  print -r -- '{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"auto"}}'
  print -r -- '{"type":"user","message":{"content":"discussing \"subtype\":\"compact_boundary\" markers"}}'
  print -r -- '{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"manual"}}'
} > "$transcript"
compacted=$(printf '%s' "$base" | jq -c --arg t "$transcript" '.transcript_path = $t')
out=$(printf '%s' "$compacted" | sh "$script" | strip_ansi)
[[ "$out" == *"116k/200k (✂2)"* ]] || die "missing compaction count: $out"
out=$(printf '%s' "$base" | sh "$script" | strip_ansi)
[[ "$out" != *"✂"* ]] || die "compaction marker without transcript: $out"

# Minimal payload renders one line and exits cleanly.
minimal='{"model": {"display_name": "Fable 5"}, "workspace": {"current_dir": "/tmp"}}'
out=$(printf '%s' "$minimal" | sh "$script" | strip_ansi)
[[ "$out" == "Fable 5 | /tmp" ]] || die "unexpected minimal render: $out"

# The script targets plain /bin/sh; prove it also renders under dash.
if command -v dash >/dev/null; then
  out=$(printf '%s' "$minimal" | dash "$script" | strip_ansi)
  [[ "$out" == "Fable 5 | /tmp" ]] || die "dash render differs: $out"
fi

# Malformed stdin must not crash or hang.
out=$(printf 'not json' | sh "$script")
[[ "$out" == "statusline: unreadable payload" ]] || die "unexpected garbage render: $out"
out=$(printf 'not json' | sh "$script" --logical)
[[ "$out" == "statusline: unreadable payload" ]] || die "unexpected garbage logical: $out"

# --logical is the testing seam: the computed document as JSON, no ANSI.
logical=$(printf '%s' "$sub" | sh "$script" --logical)
for probe in '.model.name == "Fable 5"' '.model.effort == "xhigh"' \
  '.ctx.pct == 58' '.ctx.used == "116k"' '.ctx.level == "ok"' \
  '.cost == null' '.five_hour.pct == 42' '.seven_day == null'; do
  printf '%s' "$logical" | jq -e "$probe" >/dev/null \
    || die "logical probe failed: $probe in: $logical"
done

# The managed settings fragment points at the applied script path.
command=$(chezmoi --source "$REPO_ROOT/home" execute-template \
  --file "$REPO_ROOT/home/.chezmoitemplates/claude-settings-managed.json.tmpl" \
  | jq -r '.statusLine.command')
[[ "$command" == "~/.claude/statusline.sh" ]] || \
  die "managed statusLine.command is '$command'"

print "claude-statusline: OK"
