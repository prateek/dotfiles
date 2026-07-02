#!/bin/sh
# Claude Code status line (statusLine.command in the managed settings
# fragment points here). Self-contained renderer over the statusline JSON
# payload on stdin. One line.
#
# Subscription session (rate_limits present -> usage meters, no cost;
# weekly appears only at >=80%):
#   Fable 5 xhigh | dotfiles/claude-acpx | ⏱ 2h50m | ctx ██████░░░░ 58% 116k/200k | 5h ████░░░░░░ 42% (15m) | 7d 85% (3d)
# API-billed session (no rate_limits -> session cost instead of meters):
#   Fable 5 xhigh | dotfiles/claude-acpx | ⏱ 2h50m | $6.84 | ctx ██████░░░░ 58% 116k/200k
#
# Payload reference: https://code.claude.com/docs/en/statusline
set -u

if ! command -v jq >/dev/null 2>&1; then
  cat >/dev/null
  printf 'statusline: jq not found\n'
  exit 0
fi

# Defaults keep set -u and shellcheck satisfied; jq failure exits before eval,
# and an empty payload leaves these in place.
model='?' effort='' dir='' dur_ms='' cost_c='' has_rl=''
ctx_pct='' ctx_tok='' ctx_size='' h5_pct='' h5_reset='' d7_pct='' d7_reset=''

# All numerics are normalized to integers (or "") here so the shell never
# touches floats.
vars=$(jq -r '
  def int: if type == "number" then floor else "" end;
  @sh "model=\(.model.display_name // .model.id // "?")",
  @sh "effort=\(.effort.level // "")",
  @sh "dir=\(.workspace.current_dir // .cwd // "")",
  @sh "dur_ms=\(.cost.total_duration_ms // "" | int)",
  @sh "cost_c=\(.cost.total_cost_usd // "" | if type == "number" then (. * 100 | round) else "" end)",
  @sh "has_rl=\(if .rate_limits then 1 else "" end)",
  @sh "ctx_pct=\(.context_window.used_percentage // "" | int)",
  @sh "ctx_tok=\(.context_window.total_input_tokens // "" | int)",
  @sh "ctx_size=\(.context_window.context_window_size // "" | int)",
  @sh "h5_pct=\(.rate_limits.five_hour.used_percentage // "" | int)",
  @sh "h5_reset=\(.rate_limits.five_hour.resets_at // "" | int)",
  @sh "d7_pct=\(.rate_limits.seven_day.used_percentage // "" | int)",
  @sh "d7_reset=\(.rate_limits.seven_day.resets_at // "" | int)"
' 2>/dev/null) || { printf 'statusline: unreadable payload\n'; exit 0; }
eval "$vars"

esc=$(printf '\033')
rst="${esc}[0m"
dim="${esc}[2m"
red="${esc}[31m"
grn="${esc}[32m"
ylw="${esc}[33m"
blu="${esc}[34m"
mag="${esc}[35m"

# Green below $2 percent, yellow from $2, red from $3.
pct_color() {
  p=$1
  if [ "$p" -ge "$3" ]; then
    printf '%s' "$red"
  elif [ "$p" -ge "$2" ]; then
    printf '%s' "$ylw"
  else
    printf '%s' "$grn"
  fi
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

human_tokens() {
  if [ "$1" -ge 1000000 ]; then
    printf '%sM' "$(( $1 / 1000000 ))"
  elif [ "$1" -ge 1000 ]; then
    printf '%sk' "$(( $1 / 1000 ))"
  else
    printf '%s' "$1"
  fi
}

# "2h50m" / "50m" from milliseconds.
duration() {
  s=$(( $1 / 1000 ))
  h=$(( s / 3600 ))
  m=$(( (s % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then printf '%sh%sm' "$h" "$m"; else printf '%sm' "$m"; fi
}

# Relative time until an epoch: "42m", "3h10m", or "3d".
until_epoch() {
  diff=$(( $1 - now ))
  [ "$diff" -lt 0 ] && diff=0
  if [ "$diff" -lt 3600 ]; then
    printf '%sm' "$(( diff / 60 ))"
  elif [ "$diff" -lt 172800 ]; then
    printf '%sh%sm' "$(( diff / 3600 ))" "$(( (diff % 3600) / 60 ))"
  else
    printf '%sd' "$(( (diff + 43200) / 86400 ))"
  fi
}

is_num() {
  case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac
}

now=$(date +%s)
sep=" ${dim}|${rst} "
line=""
add() {
  [ -n "$line" ] && line="${line}${sep}"
  line="${line}$1"
}

seg="$model"
[ -n "$effort" ] && seg="${seg} ${mag}${effort}${rst}"
add "$seg"

if [ -n "$dir" ]; then
  case "$dir" in
    */*) short="${dir%/*}"; short="${short##*/}/${dir##*/}" ;;
    *) short=$dir ;;
  esac
  add "${blu}${short}${rst}"
fi

is_num "$dur_ms" && add "${dim}⏱ $(duration "$dur_ms")${rst}"

# Billing switch: subscription sessions carry rate_limits and get the usage
# meters; API-billed sessions get the session cost instead. Cost arrives as
# integer cents from jq: float printf misparses under comma-decimal locales.
# The -gt 0 also hides the bogus $0.00 a subscription session reports before
# its first API response populates rate_limits.
if [ -z "$has_rl" ] && is_num "$cost_c" && [ "$cost_c" -gt 0 ]; then
  add "${ylw}$(printf '$%d.%02d' "$(( cost_c / 100 ))" "$(( cost_c % 100 ))")${rst}"
fi

if is_num "$ctx_pct"; then
  c=$(pct_color "$ctx_pct" 80 90)
  seg="${dim}ctx${rst} ${c}$(bar "$ctx_pct") ${ctx_pct}%${rst}"
  if is_num "$ctx_tok" && is_num "$ctx_size"; then
    seg="${seg} ${dim}$(human_tokens "$ctx_tok")/$(human_tokens "$ctx_size")${rst}"
  fi
  add "$seg"
fi

if is_num "$h5_pct"; then
  c=$(pct_color "$h5_pct" 50 80)
  seg="${dim}5h${rst} ${c}$(bar "$h5_pct") ${h5_pct}%${rst}"
  is_num "$h5_reset" && seg="${seg} ${dim}($(until_epoch "$h5_reset"))${rst}"
  add "$seg"
fi

if is_num "$d7_pct" && [ "$d7_pct" -ge 80 ]; then
  seg="${red}7d ${d7_pct}%${rst}"
  is_num "$d7_reset" && seg="${seg} ${dim}($(until_epoch "$d7_reset"))${rst}"
  add "$seg"
fi

printf '%s\n' "$line"
exit 0
