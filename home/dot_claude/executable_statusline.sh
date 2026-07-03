#!/bin/sh
# Claude Code status line, split into logical and physical halves.
#
# The pipeline:
#
#   payload JSON ──jq LOGIC──▶ logical JSON ──jq TO_SH──▶ vars ──shell──▶ ANSI line
#
# LOGIC is the whole brain: every decision (token-source selection, the
# zero-percent fix, the billing switch, severity levels, humanized numbers,
# relative times) happens there, producing a small self-describing document:
#
#   {
#     "model":     {"name": "Fable 5", "effort": "xhigh"},
#     "dir":       "dotfiles/claude-acpx",
#     "duration":  "2h50m",
#     "cost":      null,                          // "$6.84" only when API-billed
#     "ctx":       {"pct": 58, "used": "116k", "size": "200k",
#                   "level": "ok", "compactions": 2},
#     "five_hour": {"pct": 42, "level": "ok", "reset": "15m"},
#     "seven_day": null                           // {"pct", "reset"} at >= D7_SHOW
#   }
#
# Absent segment -> null. "level" is ok|warn|crit; the renderer maps it to a
# color but decides nothing. Run with --logical to print this document
# instead of rendering — that is also the testing seam.
#
# The shell half only does I/O and paint: read stdin, count compactions in
# the transcript (grep beats loading a multi-MB file into jq), then draw
# bars, colors, and separators from the flattened vars.
#
# Payload reference: https://code.claude.com/docs/en/statusline
set -u

# Severity thresholds: warn/crit per meter; the weekly meter is hidden
# entirely below D7_SHOW.
CTX_WARN=80 CTX_CRIT=90
H5_WARN=50 H5_CRIT=80
D7_SHOW=80

if ! command -v jq >/dev/null 2>&1; then
  cat >/dev/null
  printf 'statusline: jq not found\n'
  exit 0
fi

payload=$(cat)

# Compactions this session. Mentions of the marker inside message content
# don't false-match: their quotes are JSON-escaped in the transcript.
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
compacts=0
if [ -n "$transcript" ] && [ -r "$transcript" ]; then
  compacts=$(grep -c '"subtype":"compact_boundary"' "$transcript" 2>/dev/null) || compacts=0
fi

# ---------------------------------------------------------------------------
# LOGIC: payload -> logical document. Pure jq; the only outside inputs are
# the thresholds and the compaction count.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2016 # $vars below belong to jq, not the shell
LOGIC='
def level($warn; $crit): if . >= $crit then "crit" elif . >= $warn then "warn" else "ok" end;

def human:
  if . >= 1000000 then "\(. / 1000000 | floor)M"
  elif . >= 1000 then "\(. / 1000 | floor)k"
  else tostring end;

# "3h10m" from seconds.
def hm: "\(. / 3600 | floor)h\(. % 3600 / 60 | floor)m";

# "2h50m" / "50m" from milliseconds.
def duration:
  (. / 1000 | floor)
  | if . >= 3600 then hm else "\(. / 60 | floor)m" end;

# Relative time until an epoch: "42m", "3h10m", or "3d". now is floored to
# whole seconds to match integer date +%s arithmetic at minute boundaries.
def until:
  (. - (now | floor) | if . < 0 then 0 else . end)
  | if . < 3600 then "\(. / 60 | floor)m"
    elif . < 172800 then hm
    else "\((. + 43200) / 86400 | floor)d" end;

def int_or_null: if type == "number" then floor else null end;

def fmt(f): if type == "number" then f else null end;

(.context_window // {}) as $cw
| ($cw.used_percentage | int_or_null // 0) as $rawpct
| ($cw.context_window_size | int_or_null) as $size
| ($cw.current_usage
   | if type == "object"
     then (.input_tokens // 0) + (.cache_creation_input_tokens // 0)
          + (.cache_read_input_tokens // 0)
     else 0 end) as $cusum
| ($cw.total_input_tokens | int_or_null) as $total
# current_usage is per-response and resets on compaction; total_input_tokens
# was cumulative before Claude Code 2.1.132 and can exceed the window, so it
# is only trusted when it fits.
| (if $cusum > 0 then $cusum
   elif $total == null then null
   elif $size == null or $total <= $size then $total
   elif $rawpct > 0 and $rawpct <= 100 then ($rawpct * $size / 100 | floor)
   else null end) as $tokens
# A fresh session can report used_percentage 0 while real tokens are already
# loaded; an all-zero segment is noise (pct 0 -> ctx: null below).
| (if $rawpct > 0 then $rawpct
   elif $tokens != null and $tokens > 0 and ($size // 0) > 0
   then ($tokens * 100 / $size | floor)
   else 0 end) as $pct
| ((.cost.total_cost_usd // 0) * 100 | round) as $cents
| {
    model: {
      name: (.model.display_name // .model.id // "?"),
      effort: (.effort.level // null)
    },
    dir: ((.workspace.current_dir // .cwd // null)
      | if . == null then null
        else (split("/") | if length >= 2 then "\(.[-2])/\(.[-1])" else .[0] end) end),
    duration: (.cost.total_duration_ms | fmt(duration)),
    # Billing switch: subscription sessions carry rate_limits and get the
    # usage meters; only API-billed sessions show the session cost.
    cost: (if .rate_limits == null and $cents > 0
           then "$\($cents / 100 | floor).\($cents % 100 | if . < 10 then "0\(.)" else tostring end)"
           else null end),
    ctx: (if $pct <= 0 then null else {
      pct: $pct,
      used: ($tokens | fmt(human)),
      size: ($size | fmt(human)),
      level: ($pct | level($ctx_warn; $ctx_crit)),
      compactions: (if $compactions > 0 then $compactions else null end)
    } end),
    five_hour: (.rate_limits.five_hour as $w
      | ($w.used_percentage | int_or_null) as $p
      | if $p != null then {
          pct: $p,
          level: ($p | level($h5_warn; $h5_crit)),
          reset: ($w.resets_at | fmt(until))
        } else null end),
    seven_day: (.rate_limits.seven_day as $w
      | ($w.used_percentage | int_or_null) as $p
      | if $p != null and $p >= $d7_show then {
          pct: $p,
          reset: ($w.resets_at | fmt(until))
        } else null end)
  }
'

# TO_SH: logical document -> shell assignments. Mechanical; no decisions.
TO_SH='
  @sh "model=\(.model.name)",
  @sh "effort=\(.model.effort // "")",
  @sh "dir=\(.dir // "")",
  @sh "duration=\(.duration // "")",
  @sh "cost=\(.cost // "")",
  @sh "ctx_pct=\(.ctx.pct // "")",
  @sh "ctx_used=\(.ctx.used // "")",
  @sh "ctx_size=\(.ctx.size // "")",
  @sh "ctx_level=\(.ctx.level // "")",
  @sh "ctx_compacts=\(.ctx.compactions // "")",
  @sh "h5_pct=\(.five_hour.pct // "")",
  @sh "h5_level=\(.five_hour.level // "")",
  @sh "h5_reset=\(.five_hour.reset // "")",
  @sh "d7_pct=\(.seven_day.pct // "")",
  @sh "d7_reset=\(.seven_day.reset // "")"
'

run_logic() {
  printf '%s' "$payload" | jq \
    --argjson ctx_warn "$CTX_WARN" --argjson ctx_crit "$CTX_CRIT" \
    --argjson h5_warn "$H5_WARN" --argjson h5_crit "$H5_CRIT" \
    --argjson d7_show "$D7_SHOW" --argjson compactions "$compacts" \
    "$@"
}

if [ "${1:-}" = "--logical" ]; then
  run_logic "$LOGIC" 2>/dev/null || printf 'statusline: unreadable payload\n'
  exit 0
fi

# Defaults keep set -u and shellcheck satisfied; jq failure exits before eval.
model='' effort='' dir='' duration='' cost=''
ctx_pct='' ctx_used='' ctx_size='' ctx_level='' ctx_compacts=''
h5_pct='' h5_level='' h5_reset='' d7_pct='' d7_reset=''

vars=$(run_logic -r "$LOGIC | $TO_SH" 2>/dev/null) \
  || { printf 'statusline: unreadable payload\n'; exit 0; }
eval "$vars"

# ---------------------------------------------------------------------------
# Renderer: paint the flattened logical vars. Empty var -> segment hidden.
# ---------------------------------------------------------------------------
esc=$(printf '\033')
rst="${esc}[0m"
dim="${esc}[2m"
red="${esc}[31m"
grn="${esc}[32m"
ylw="${esc}[33m"
blu="${esc}[34m"
mag="${esc}[35m"

level_color() {
  case "$1" in
    crit) printf '%s' "$red" ;;
    warn) printf '%s' "$ylw" ;;
    *) printf '%s' "$grn" ;;
  esac
}

# 10-cell bar, rounded to the nearest cell.
bar() {
  filled=$(( ($1 + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  i=0
  while [ "$i" -lt 10 ]; do
    if [ "$i" -lt "$filled" ]; then printf '█'; else printf '░'; fi
    i=$(( i + 1 ))
  done
}

sep=" ${dim}|${rst} "
line=""
add() {
  [ -n "$line" ] && line="${line}${sep}"
  line="${line}$1"
}

seg="$model"
[ -n "$effort" ] && seg="${seg} ${mag}${effort}${rst}"
add "$seg"

[ -n "$dir" ] && add "${blu}${dir}${rst}"
[ -n "$duration" ] && add "${dim}${duration}${rst}"
[ -n "$cost" ] && add "${ylw}${cost}${rst}"

if [ -n "$ctx_pct" ]; then
  c=$(level_color "$ctx_level")
  seg="${dim}ctx${rst} ${c}$(bar "$ctx_pct") ${ctx_pct}%${rst}"
  [ -n "$ctx_used" ] && [ -n "$ctx_size" ] && seg="${seg} ${dim}${ctx_used}/${ctx_size}${rst}"
  [ -n "$ctx_compacts" ] && seg="${seg} ${dim}(x${ctx_compacts})${rst}"
  add "$seg"
fi

if [ -n "$h5_pct" ]; then
  c=$(level_color "$h5_level")
  seg="${dim}5h${rst} ${c}$(bar "$h5_pct") ${h5_pct}%${rst}"
  [ -n "$h5_reset" ] && seg="${seg} ${dim}(${h5_reset})${rst}"
  add "$seg"
fi

if [ -n "$d7_pct" ]; then
  seg="${red}7d ${d7_pct}%${rst}"
  [ -n "$d7_reset" ] && seg="${seg} ${dim}(${d7_reset})${rst}"
  add "$seg"
fi

printf '%s\n' "$line"
exit 0
