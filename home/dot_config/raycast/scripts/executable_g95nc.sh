#!/bin/bash
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title G95NC Display
# @raycast.mode compact
# @raycast.packageName Display
#
# Optional parameters:
# @raycast.icon 🖥️
# @raycast.argument1 { "type": "dropdown", "placeholder": "mode", "data": [{"title": "Sharp — HiDPI 60Hz", "value": "set"}, {"title": "Butter — HiDPI 120Hz", "value": "butter"}, {"title": "Reset — clean slate", "value": "reset"}, {"title": "Check status", "value": "check"}] }
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Set the Samsung Odyssey G95NC to sharp HiDPI 60Hz (set), butter HiDPI 120Hz (butter), reset to a native clean slate (reset), or check current state. Drives the BetterDisplay CLI.
# @raycast.author Prateek Rungta
#
# CLI: g95nc {check|set [WxH]|butter|reset}. Settings use a stable virtual EDID identity.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CLI="${BD_CLI:-betterdisplaycli}"
MATCH="${G95_MATCH:-Odyssey}"
VS_NAME="${G95_VS_NAME:-G95-HiDPI}"
VS_SERIAL="${G95_VS_SERIAL:-90570057}"
VS_MODEL="${G95_VS_MODEL:-9057}"
DOMAIN=pro.betterdisplay.BetterDisplay
COMMAND_TIMEOUT="${G95_COMMAND_TIMEOUT:-10}"
POLL_ATTEMPTS="${G95_POLL_ATTEMPTS:-10}"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/g95nc"
PHYSICAL_UUID='' VIRTUAL_UUID='' PHYSICAL_ID='' VIRTUAL_ID='' VIRTUAL_TAG='' LOCKED=0 SWITCHING=0

log() { printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$LOG_FILE"; }
say() { log "$*"; printf '%s\n' "$*"; }
fail() { say "error: $*" >&2; return 1; }

run() {
  local rc started=$SECONDS command_text
  printf -v command_text '%q ' "$@"
  log "command: $command_text"
  python3 -c '
import os, signal, subprocess, sys
p = subprocess.Popen(sys.argv[2:], start_new_session=True)
try:
    rc = p.wait(timeout=float(sys.argv[1]))
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    p.wait()
    print("command timed out", file=sys.stderr)
    rc = 124
sys.exit(rc if rc >= 0 else 128 - rc)
' "$COMMAND_TIMEOUT" "$@" > "$WORK_DIR/stdout" 2> "$WORK_DIR/stderr"
  rc=$?
  { printf 'stdout:\n'; cat "$WORK_DIR/stdout"; printf '\nstderr:\n'; cat "$WORK_DIR/stderr"; printf '\n'; } >> "$LOG_FILE"
  log "exit=$rc elapsed=$((SECONDS - started))s"
  cat "$WORK_DIR/stdout"
  return "$rc"
}
bd() { run "$CLI" "$@"; }
disp() { bd get "--UUID=$PHYSICAL_UUID" "$@"; }
vs() { bd get "--UUID=$VIRTUAL_UUID" "$@"; }
setp() { bd set "--UUID=$PHYSICAL_UUID" "$@"; }
setv() { bd set "--UUID=$VIRTUAL_UUID" "$@"; }

finish() {
  local rc=$?
  trap - EXIT
  log "finished exit=$rc"
  [ "$rc" -eq 0 ] || printf 'Debug log: %s\n' "$LOG_FILE" >&2
  rm -rf "$WORK_DIR"
  if [ "$LOCKED" -eq 1 ]; then rm -f "$LOG_DIR/lock/pid"; rmdir "$LOG_DIR/lock"; fi
  exit "$rc"
}
interrupted() {
  trap '' INT TERM
  say 'Interrupted.'
  if [ "$SWITCHING" -eq 1 ]; then cmd_reset || true; fi
  exit 130
}
init_log() {
  command -v python3 >/dev/null || { echo 'error: python3 is required' >&2; return 1; }
  umask 077
  mkdir -p "$LOG_DIR" || return 1
  chmod 700 "$LOG_DIR" || return 1
  LOG_FILE="$LOG_DIR/$(date -u '+%Y%m%dT%H%M%SZ')-$$.log"
  : > "$LOG_FILE" || return 1
  WORK_DIR="$(mktemp -d "$LOG_DIR/.run-XXXXXX")" || return 1
  trap finish EXIT
  trap interrupted INT TERM
  if ! mkdir "$LOG_DIR/lock" 2>/dev/null; then
    fail "another run holds $LOG_DIR/lock; if its pid has exited, remove that lock directory"
    return 1
  fi
  LOCKED=1
  printf '%s\n' "$$" > "$LOG_DIR/lock/pid"
  python3 -c 'import pathlib,sys; files=sorted(pathlib.Path(sys.argv[1]).glob("*.log")); [p.unlink() for p in files[:-30]]' "$LOG_DIR"
  say "Debug log: $LOG_FILE"
  log "host=$(hostname) arguments=$* script=$0"
  run sw_vers >> "$LOG_FILE" || true
}

wait_for() {
  local attempt
  for ((attempt=0; attempt<POLL_ATTEMPTS; attempt++)); do
    if "$@"; then return 0; fi
    if [ "$attempt" -lt "$((POLL_ATTEMPTS - 1))" ]; then sleep 1; fi
  done
  log "verification timed out: $*"
  return 1
}
app_stopped() { ! pgrep -x BetterDisplay >/dev/null; }
cli_ready() { bd get --identifiers >/dev/null; }

resolve() {
  local kind="$1" raw ids
  raw="$(bd get --identifiers)" || return 1
  ids="$(printf '%s' "$raw" | run python3 -c '
import json,sys
items=json.loads("["+sys.stdin.read()+"]")
kind,name,model,serial,match=sys.argv[1:]
if kind=="physical":
    items=[i for i in items if i.get("deviceType")=="Display" and match.lower() in i.get("name", "").lower()]
else:
    items=[i for i in items if i.get("deviceType")=="VirtualScreen" and i.get("name")==name and str(i.get("vendor"))=="2198" and str(i.get("model"))==model and str(i.get("serial"))==serial]
if len(items)>1:
    print("ambiguous display identity",file=sys.stderr); sys.exit(2)
if items:
    item=items[0]
    if not item.get("UUID") or not str(item.get("tagID", "")).isdigit() or int(item["tagID"])<=0:
        print("incomplete display identity",file=sys.stderr); sys.exit(2)
    if not str(item.get("displayID", "")).isdigit():
        print("incomplete macOS display identity",file=sys.stderr); sys.exit(2)
    print(item["UUID"]+"|"+str(item["displayID"])+"|"+str(item["tagID"]))
' "$kind" "$VS_NAME" "$VS_MODEL" "$VS_SERIAL" "$MATCH")" || return 2
  if [ "$kind" = physical ]; then
    PHYSICAL_UUID="${ids%%|*}"; ids="${ids#*|}"; PHYSICAL_ID="${ids%%|*}"
  else
    VIRTUAL_UUID="${ids%%|*}"; ids="${ids#*|}"; VIRTUAL_ID="${ids%%|*}"; VIRTUAL_TAG="${ids#*|}"
  fi
}
require_display() {
  resolve physical || { fail "cannot resolve exactly one physical display matching '$MATCH'"; return 1; }
  [ -n "$PHYSICAL_UUID" ] || { fail "no physical display matching '$MATCH'"; return 1; }
  disp --resolution >/dev/null || { fail 'physical display is not online'; return 1; }
}
resolve_virtual() {
  resolve virtual || return 1
  [ -n "$VIRTUAL_UUID" ]
}
virtual_online() {
  resolve_virtual && [ "$VIRTUAL_UUID" != UNKNOWN ] && [ "$VIRTUAL_ID" != 0 ]
}
virtual_absent() {
  local raw
  raw="$(bd get --identifiers)" || return 1
  printf '%s' "$raw" | run python3 -c '
import json,sys
items=json.loads("["+sys.stdin.read()+"]")
sys.exit(1 if any(str(i.get("tagID"))==sys.argv[1] for i in items) else 0)
' "$VIRTUAL_TAG"
}
ensure_8k() {
  local enabled
  enabled="$(run defaults read "$DOMAIN" enable16K)" || enabled=0
  [ "$enabled" = 1 ] && return 0
  say 'Enabling resolutions over 8K; restarting BetterDisplay.'
  run osascript -e 'tell application "BetterDisplay" to quit' >/dev/null || return 1
  wait_for app_stopped || return 1
  run defaults write "$DOMAIN" enable16K -bool true || { run open -a BetterDisplay; return 1; }
  run open -a BetterDisplay || return 1
  wait_for cli_ready || return 1
  [ "$(run defaults read "$DOMAIN" enable16K)" = 1 ] || return 1
  require_display
}

matches() {
  local selector="$1" feature="$2" expected="$3" actual
  actual="$(bd get "--UUID=$selector" "--$feature")" || return 1
  # Connected reports both virtual-screen and display facets on BetterDisplay 5.
  if [ "$feature" = connected ]; then actual="${actual//,on/}"; fi
  [ "$actual" = "$expected" ]
}
sharp_state() {
  [ -n "$VIRTUAL_UUID" ] || return 1
  matches "$VIRTUAL_UUID" resolution "$LAND" &&
    matches "$VIRTUAL_UUID" hiDPI on &&
    matches "$VIRTUAL_UUID" main true &&
    matches "$VIRTUAL_UUID" mirror on &&
    matches "$VIRTUAL_UUID" refreshRate "${RATE}Hz" &&
    matches "$PHYSICAL_UUID" hiDPI on &&
    matches "$PHYSICAL_UUID" mirror on &&
    matches "$PHYSICAL_UUID" refreshRate "${RATE}Hz" && native_mirror_state
}
native_mirror_state() {
  local raw
  raw="$(run system_profiler SPDisplaysDataType -json)" || return 1
  printf '%s' "$raw" | run python3 -c '
import json,re,sys
physical,virtual,width,height,rate=sys.argv[1:]
displays=[d for gpu in json.load(sys.stdin)["SPDisplaysDataType"] for d in gpu.get("spdisplays_ndrvs",[])]
def find(identifier):
    return next(d for d in displays if int(d["_spdisplays_displayID"],16)==int(identifier))
try:
    panel,master=find(physical),find(virtual)
    pixels=f"{int(width)*2} x {int(height)*2}"
    valid=(master["spdisplays_mirror_status"]=="spdisplays_master_mirror"
        and master["spdisplays_main"]=="spdisplays_yes"
        and panel["spdisplays_mirror_status"]=="spdisplays_hardware_mirror"
        and panel["_spdisplays_pixels"]==master["_spdisplays_pixels"]==pixels
        and all(re.search(r"^"+re.escape(f"{width} x {height}")+r"\s*@\s*"+re.escape(rate)+r"(?:\.0+)?\s*Hz", d.get("_spdisplays_resolution", "")) for d in (panel,master)))
    if not valid: raise ValueError("unexpected mirror state")
except (KeyError,ValueError,StopIteration):
    print("macOS mirror/framebuffer verification failed",file=sys.stderr); sys.exit(1)
' "$PHYSICAL_ID" "$VIRTUAL_ID" "$LAND_WIDTH" "$LAND_HEIGHT" "$RATE"
}
snapshot() {
  log 'Display state snapshot'
  bd get --identifiers >> "$LOG_FILE" || true
  if [ -n "$PHYSICAL_UUID" ]; then
    disp --resolution --hiDPI --refreshRate --main --mirror --connectionMode >> "$LOG_FILE" || true
  fi
  if [ -n "$VIRTUAL_UUID" ]; then
    vs --resolution --hiDPI --refreshRate --main --mirror >> "$LOG_FILE" || true
  fi
  run system_profiler SPDisplaysDataType >> "$LOG_FILE" || true
}
teardown() {
  resolve virtual || { fail 'cannot safely identify the managed virtual screen'; return 1; }
  if [ -n "$VIRTUAL_UUID" ]; then
    if [ "$VIRTUAL_UUID" != UNKNOWN ]; then
      setv --protectAll=off >/dev/null || true
      setv --mirror=off >/dev/null || true
    fi
    bd discard "--type=VirtualScreen" "--tagID=$VIRTUAL_TAG" >/dev/null || true
    wait_for virtual_absent || { fail 'managed virtual screen was not discarded'; return 1; }
    VIRTUAL_UUID=''
  fi
  if [ -n "$PHYSICAL_UUID" ]; then
    setp --protectAll=off >/dev/null || true
    setp --mirror=off >/dev/null || true
    setp --stream=off >/dev/null || true
    setp --pip=off >/dev/null || true
  fi
}
reset_state() {
  matches "$PHYSICAL_UUID" resolution 3840x1080 &&
    matches "$PHYSICAL_UUID" hiDPI on &&
    matches "$PHYSICAL_UUID" main true &&
    matches "$PHYSICAL_UUID" mirror off &&
    matches "$PHYSICAL_UUID" refreshRate 60Hz
}
cmd_reset() {
  say 'Resetting the managed virtual screen and panel.'
  teardown || return 1
  if [ -z "$PHYSICAL_UUID" ]; then say 'Panel disconnected; managed virtual screen cleared.'; return 0; fi
  setp --main=on >/dev/null || true
  setp --reinitialize >/dev/null || true
  setp --resolution=3840x1080 --hiDPI=on --refreshRate=60Hz >/dev/null || true
  wait_for reset_state || { snapshot; fail 'native HiDPI reset did not verify'; return 1; }
  snapshot
  say '[ok] Native 3840x1080 HiDPI at 60 Hz.'
}
select_mode() {
  local uuid="$1" resolution="$2" modes number
  modes="$(bd get "--UUID=$uuid" --displayModeList)" || return 1
  number="$(printf '%s' "$modes" | run python3 -c '
import re,sys
pattern=r"^(\d+) - "+re.escape(sys.argv[1])+r" HiDPI "+re.escape(sys.argv[2])+r"Hz(?: |$)"
for line in sys.stdin:
    match=re.match(pattern,line)
    if match:
        print(match[1]); sys.exit(0)
print("requested HiDPI refresh mode is unavailable",file=sys.stderr); sys.exit(1)
' "$resolution" "$RATE")" || return 1
  bd set "--UUID=$uuid" "--displayModeNumber=$number" >/dev/null || return 1
  matches "$uuid" resolution "$resolution" && matches "$uuid" hiDPI on && matches "$uuid" refreshRate "${RATE}Hz"
}
configure_120() {
  say 'Enabling 60/120 Hz modes for the managed virtual screen; restarting BetterDisplay.'
  run osascript -e 'tell application "BetterDisplay" to quit' >/dev/null || return 1
  wait_for app_stopped || return 1
  local rc=0
  run defaults write "$DOMAIN" "useCustomRefreshRates@VirtualScreen:$VIRTUAL_TAG" -bool true || rc=1
  run defaults write "$DOMAIN" "refreshRates@VirtualScreen:$VIRTUAL_TAG" -string '[60,120]' || rc=1
  run open -a BetterDisplay || return 1
  [ "$rc" -eq 0 ] || return 1
  wait_for cli_ready && require_display && wait_for virtual_online
}
apply_120() {
  configure_120 || return 1
  wait_for select_mode "$PHYSICAL_UUID" 3840x1080 || return 1
  wait_for select_mode "$VIRTUAL_UUID" 3840x1080 || return 1
  setv --mirror=on "--targetUUID=$PHYSICAL_UUID" >/dev/null || return 1
  setv --main=on >/dev/null || return 1
  wait_for select_mode "$PHYSICAL_UUID" 3840x1080 || return 1
  # Grow the 120 Hz mirror from a native HiDPI seed: jumping directly to the
  # final virtual size can leave the physical desktop at 60 Hz on macOS.
  local resolution
  for resolution in 4096x1152 4480x1260 "$LAND"; do
    wait_for select_mode "$VIRTUAL_UUID" "$resolution" || return 1
    run sleep 2 >/dev/null || return 1
  done
  wait_for sharp_state
}
apply_sharp() {
  teardown || return 1
  bd create --deviceType=VirtualScreen "--virtualScreenName=$VS_NAME" --aspectWidth=32 --aspectHeight=9 \
    "--virtualScreenSerial=$VS_SERIAL" "--virtualScreenModelNumber=$VS_MODEL" >/dev/null || return 1
  wait_for resolve_virtual || return 1
  # A newly created, disconnected screen reports UUID=UNKNOWN. Use its owned tag
  # until macOS has connected it and assigned the stable EDID-derived UUID.
  bd set "--tagID=$VIRTUAL_TAG" --useResolutionList=off --virtualScreenHiDPI=on >/dev/null || return 1
  bd set "--tagID=$VIRTUAL_TAG" --connected=on >/dev/null || true
  wait_for virtual_online || return 1
  wait_for matches "$VIRTUAL_UUID" connected on || return 1
  if [ "$RATE" = 120 ]; then apply_120; return $?; fi
  setp --resolution=5120x1440 --hiDPI=off --refreshRate=60Hz >/dev/null || true
  setv "--resolution=$LAND" --hiDPI=on --refreshRate=60Hz >/dev/null || true
  wait_for matches "$VIRTUAL_UUID" resolution "$LAND" || return 1
  wait_for matches "$VIRTUAL_UUID" hiDPI on || return 1
  setv --mirror=on "--targetUUID=$PHYSICAL_UUID" >/dev/null || true
  wait_for matches "$VIRTUAL_UUID" mirror on || return 1
  setv --main=on >/dev/null || true
  if ! wait_for matches "$VIRTUAL_UUID" main true; then setv --main=on >/dev/null || true; fi
  wait_for sharp_state
}
cmd_set() {
  if [ "$LAND_WIDTH" -gt 3840 ] || [ "$LAND_HEIGHT" -gt 2160 ]; then
    ensure_8k || { fail 'could not enable resolutions over 8K'; return 1; }
  fi
  resolve virtual || { fail 'ambiguous managed virtual screen'; return 1; }
  if sharp_state; then say "[ok] Already at $LAND HiDPI, mirrored at $RATE Hz."; return 0; fi
  say "Setting $LAND HiDPI at $RATE Hz (requested $WANT)."
  SWITCHING=1
  if apply_sharp; then
    SWITCHING=0
    snapshot
    say "[ok] $LABEL $LAND HiDPI mirror at $RATE Hz."
  else
    snapshot
    say 'Setup failed; attempting native HiDPI recovery.'
    cmd_reset || say 'Recovery failed; inspect the log and BetterDisplay.'
    SWITCHING=0
    return 1
  fi
}
cmd_butter() { cmd_set; }
cmd_check() {
  local enabled feature value
  say "Odyssey G95NC ($PHYSICAL_UUID)"
  for feature in resolution hiDPI refreshRate main mirror connectionMode refreshRateList; do
    value="$(disp "--$feature")" || { fail "cannot read $feature"; return 1; }
    say "$feature: $value"
  done
  enabled="$(run defaults read "$DOMAIN" enable16K)" || enabled=0
  say "Enable resolutions over 8K: $enabled"
  resolve virtual || { fail 'ambiguous managed virtual screen'; return 1; }
  say "Managed virtual screen: ${VIRTUAL_UUID:-absent}"
  if [ -n "$VIRTUAL_UUID" ]; then
    say "Virtual resolution: $(vs --resolution); HiDPI: $(vs --hiDPI)"
    say "Unplug handling: configure association with '$MATCH' in BetterDisplay's virtual-screen settings."
  fi
  snapshot
}
main() {
  init_log "$@" || return 1
  local mode="${1:-check}"
  if ! [[ "$COMMAND_TIMEOUT" =~ ^[1-9][0-9]*$ && "$POLL_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
    fail 'timeouts and poll attempts must be positive integers'; return 2
  fi
  case "$mode" in
    butter)
      [ "$#" -le 1 ] || { fail 'usage: g95nc butter'; return 2; }
      WANT=4608x1296 LAND=4608x1296 LAND_WIDTH=4608 LAND_HEIGHT=1296 RATE=120 LABEL=Butter
      ;;
    set)
      RATE=60 LABEL=Sharp
      [ "$#" -le 2 ] || { fail 'usage: g95nc set [WxH]'; return 2; }
      WANT="${2:-4864x1368}"
      [[ "$WANT" =~ ^[1-9][0-9]{0,4}x[1-9][0-9]{0,4}$ ]] || { fail 'resolution must be positive WxH'; return 2; }
      local width="${WANT%%x*}" height="${WANT#*x}" k
      width=$((10#$width)); height=$((10#$height))
      [ "$width" -le 8192 ] && [ "$height" -le 8192 ] || { fail 'HiDPI target exceeds the 16K framebuffer limit'; return 2; }
      k=$(((width + 16) / 32)); [ "$k" -ge 1 ] || k=1
      LAND_WIDTH=$((k * 32)); LAND_HEIGHT=$((k * 9)); LAND="${LAND_WIDTH}x${LAND_HEIGHT}"
      ;;
    check|reset) [ "$#" -le 1 ] || { fail 'usage: g95nc {check|set [WxH]|butter|reset}'; return 2; } ;;
    *) fail 'usage: g95nc {check|set [WxH]|butter|reset}'; return 2 ;;
  esac
  command -v "$CLI" >/dev/null || { fail "'$CLI' not found"; return 1; }
  pgrep -x BetterDisplay >/dev/null || { fail "BetterDisplay is not running; open -a BetterDisplay"; return 1; }
  wait_for cli_ready || { fail 'BetterDisplay CLI is unresponsive'; return 1; }
  bd help | head -1 >> "$LOG_FILE" || true
  if [ "$mode" = reset ]; then
    resolve physical || { fail 'cannot safely identify the physical display'; return 1; }
  else require_display || return 1; fi
  snapshot
  "cmd_$mode"
}
main "$@"
