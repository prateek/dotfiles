#!/bin/sh
# Pi status line rendered from pi-statusline's Claude-like command payload.
#
# This intentionally stays separate from the Claude Code statusline: Pi's
# adapter has different token and compaction semantics.
set -u

CTX_WARN=80 CTX_CRIT=90

if ! command -v jq >/dev/null 2>&1; then
  cat >/dev/null
  printf 'pi-statusline: jq not found\n'
  exit 0
fi

payload=$(cat)

pi_session=$(printf '%s' "$payload" | jq -r '.pi.session_file // empty' 2>/dev/null)
compacts=0
if [ -n "$pi_session" ] && [ -r "$pi_session" ]; then
  compacts=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"compaction"' "$pi_session" 2>/dev/null) || compacts=0
fi

# shellcheck disable=SC2016 # $vars below belong to jq, not the shell
LOGIC='
def level($warn; $crit): if . >= $crit then "crit" elif . >= $warn then "warn" else "ok" end;

def human:
  if . >= 1000000 then "\(. / 1000000 | floor)M"
  elif . >= 1000 then "\(. / 1000 | floor)k"
  else tostring end;

def hm: "\(. / 3600 | floor)h\(. % 3600 / 60 | floor)m";

def duration:
  (. / 1000 | floor)
  | if . >= 3600 then hm else "\(. / 60 | floor)m" end;

def int_or_null: if type == "number" then floor else null end;

def fmt(f): if type == "number" then f else null end;

(.context_window // {}) as $cw
| ($cw.context_window_size | int_or_null) as $size
| ($cw.total_input_tokens | int_or_null) as $total
| (($cw.used_percentage | int_or_null) // 0) as $rawpct
| (if $total == null then null
   elif $size == null or $total <= $size then $total
   elif $rawpct > 0 and $rawpct <= 100 and $size != null then ($rawpct * $size / 100 | floor)
   else null end) as $tokens
| (if $rawpct > 0 and $rawpct <= 100 and $total != null and $size != null and $total > $size
   then $rawpct
   elif $tokens != null and $tokens > 0 and ($size // 0) > 0
   then ($tokens * 100 / $size | floor)
   elif $rawpct > 0 then $rawpct
   else 0 end) as $pct
| {
    model: {
      name: (.model.display_name // .model.id // "?"),
      effort: (.effort.level // null)
    },
    dir: ((.workspace.current_dir // .cwd // null)
      | if . == null then null
        else (split("/") | if length >= 2 then "\(.[-2])/\(.[-1])" else .[0] end) end),
    duration: (.cost.total_duration_ms | fmt(duration)),
    ctx: (if $pct <= 0 then null else {
      pct: $pct,
      used: ($tokens | fmt(human)),
      size: ($size | fmt(human)),
      level: ($pct | level($ctx_warn; $ctx_crit)),
      compactions: (if $compactions > 0 then $compactions else null end)
    } end)
  }
'

TO_SH='
  @sh "model=\(.model.name)",
  @sh "effort=\(.model.effort // "")",
  @sh "dir=\(.dir // "")",
  @sh "duration=\(.duration // "")",
  @sh "ctx_pct=\(.ctx.pct // "")",
  @sh "ctx_used=\(.ctx.used // "")",
  @sh "ctx_size=\(.ctx.size // "")",
  @sh "ctx_level=\(.ctx.level // "")",
  @sh "ctx_compacts=\(.ctx.compactions // "")"
'

run_logic() {
  printf '%s' "$payload" | jq \
    --argjson ctx_warn "$CTX_WARN" --argjson ctx_crit "$CTX_CRIT" \
    --argjson compactions "$compacts" \
    "$@"
}

if [ "${1:-}" = "--logical" ]; then
  run_logic "$LOGIC" 2>/dev/null || printf 'pi-statusline: unreadable payload\n'
  exit 0
fi

model='' effort='' dir='' duration=''
ctx_pct='' ctx_used='' ctx_size='' ctx_level='' ctx_compacts=''

vars=$(run_logic -r "$LOGIC | $TO_SH" 2>/dev/null) \
  || { printf 'pi-statusline: unreadable payload\n'; exit 0; }
eval "$vars"

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

if [ -n "$ctx_pct" ]; then
  c=$(level_color "$ctx_level")
  seg="${dim}ctx${rst} ${c}$(bar "$ctx_pct") ${ctx_pct}%${rst}"
  [ -n "$ctx_used" ] && [ -n "$ctx_size" ] && seg="${seg} ${dim}${ctx_used}/${ctx_size}${rst}"
  [ -n "$ctx_compacts" ] && seg="${seg} ${dim}(x${ctx_compacts})${rst}"
  add "$seg"
fi

printf '%s\n' "$line"
exit 0
