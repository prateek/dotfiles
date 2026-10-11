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
# @raycast.argument1 { "type": "dropdown", "placeholder": "mode", "data": [{"title": "Sharp — HiDPI 60Hz", "value": "sharp"}, {"title": "Butter — HiDPI 120Hz", "value": "butter"}, {"title": "Reset — clear settings, 3840×1080 HiDPI 120Hz", "value": "reset"}, {"title": "Check status", "value": "check"}] }
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Sharp HiDPI 60Hz, Butter HiDPI 120Hz, reset ALL BetterDisplay preferences and virtual displays, or check current state.
# @raycast.author Prateek Rungta
#
# CLI: g95nc {check|sharp [WxH]|set [WxH]|butter|reset}.
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
ensure_preferences() {
  local enabled hidden visible
  enabled="$(run defaults read "$DOMAIN" enable16K)" || enabled=0
  hidden="$(run defaults read "$DOMAIN" hideMenuIcon)" || hidden=0
  visible="$(run defaults read "$DOMAIN" 'NSStatusItem VisibleCC Item-0')" || visible=1
  [ "$enabled" = 1 ] && [ "$hidden" != 1 ] && [ "$visible" != 0 ] && return 0
  say 'Enabling resolutions over 8K and the menu icon; restarting BetterDisplay.'
  run osascript -e 'tell application "BetterDisplay" to quit' >/dev/null || return 1
  wait_for app_stopped || return 1
  local rc=0
  run defaults write "$DOMAIN" enable16K -bool true || rc=1
  run defaults write "$DOMAIN" hideMenuIcon -bool false || rc=1
  run defaults write "$DOMAIN" 'NSStatusItem VisibleCC Item-0' -bool true || rc=1
  run open -g -a BetterDisplay || return 1
  [ "$rc" -eq 0 ] || return 1
  wait_for cli_ready || return 1
  [ "$(run defaults read "$DOMAIN" enable16K)" = 1 ] || return 1
  require_display
}

matches() {
  local selector="$1" feature="$2" expected="$3" actual
  actual="$(bd get "--UUID=$selector" "--$feature")" || return 1
  # Connected reports both virtual-screen and display facets on BetterDisplay 5.
  if [ "$feature" = connected ]; then actual="${actual//,on/}"; fi
  if [ "$feature" = refreshRate ]; then
    run python3 -c '
import re,sys
values=[re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)Hz", x) for x in sys.argv[1:]]
sys.exit(0 if all(values) and abs(float(values[0][1])-float(values[1][1])) <= 0.2 else 1)
' "$actual" "$expected" >/dev/null
    return $?
  fi
  [ "$actual" = "$expected" ]
}
output_modes() {
  run python3 -c '
import re,sys
rate=float(sys.argv[1])
for line in sys.stdin:
    match=re.match(r"^(\d+) - 7680x2160 ([0-9.]+)Hz .* SDR (?:RGB Full|YCbCr 4:4:4 (?:Full|Limited))(?: |$)",line)
    if match and abs(float(match[2])-rate)<=0.2:
        print(match[1]); sys.exit(0)
print("native 7680x2160 SDR RGB/4:4:4 output at the requested refresh is unavailable",file=sys.stderr)
sys.exit(1)
' "$RATE"
}
output_state() {
  local actual
  actual="$(disp --connectionMode)" || return 1
  printf '%s\n' "$actual" | output_modes >/dev/null
}
native_seed() {
  local modes number
  setp --hdr=off >/dev/null || return 1
  wait_for select_mode "$PHYSICAL_UUID" 3840x1080 || return 1
  output_state && return 0
  modes="$(disp --connectionModeList)" || return 1
  number="$(printf '%s\n' "$modes" | output_modes)" || return 1
  setp "--connectionMode=$number" >/dev/null || return 1
  wait_for output_state
}
preflight() {
  local modes
  modes="$(disp --connectionModeListAll)" || return 1
  printf '%s\n' "$modes" | output_modes >/dev/null || {
    fail "connection cannot supply 7680x2160 SDR RGB/4:4:4 at approximately $RATE Hz; check the cable/adapter and monitor input settings. No settings changed."
    return 1
  }
  mode_number "$PHYSICAL_UUID" 3840x1080 >/dev/null || {
    fail "native 3840x1080 HiDPI seed at approximately $RATE Hz is unavailable. No settings changed."
    return 1
  }
}
sharp_state() {
  [ -n "$VIRTUAL_UUID" ] || return 1
  if [ "$RATE" = 120 ]; then
    [ "$(run defaults read "$DOMAIN" "useCustomRefreshRates@VirtualScreen:$VIRTUAL_TAG")" = 1 ] || return 1
    [ "$(run defaults read "$DOMAIN" "refreshRates@VirtualScreen:$VIRTUAL_TAG")" = '[60,120]' ] || return 1
  fi
  matches "$VIRTUAL_UUID" resolution "$LAND" &&
    matches "$VIRTUAL_UUID" hiDPI on &&
    matches "$VIRTUAL_UUID" main true &&
    matches "$VIRTUAL_UUID" mirror on &&
    matches "$VIRTUAL_UUID" refreshRate "${RATE}Hz" &&
    matches "$PHYSICAL_UUID" hiDPI on &&
    matches "$PHYSICAL_UUID" mirror on &&
    matches "$PHYSICAL_UUID" refreshRate "${RATE}Hz" && output_state && native_mirror_state
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
def correct_timing(display):
    match=re.fullmatch(re.escape(f"{width} x {height}")+r"\s*@\s*([0-9.]+)\s*Hz", display.get("_spdisplays_resolution", ""))
    return match is not None and abs(float(match[1])-float(rate))<=0.2
try:
    panel,master=find(physical),find(virtual)
    pixels=f"{int(width)*2} x {int(height)*2}"
    valid=(master["spdisplays_mirror_status"]=="spdisplays_master_mirror"
        and master["spdisplays_main"]=="spdisplays_yes"
        and panel["spdisplays_mirror_status"]=="spdisplays_hardware_mirror"
        and panel["_spdisplays_pixels"]==master["_spdisplays_pixels"]==pixels
        and all(correct_timing(d) for d in (panel,master)))
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
preference_domain_exists() {
  run defaults export "$DOMAIN" "$WORK_DIR/preferences.plist" >/dev/null || return 2
  run python3 -c '
import plistlib,sys
try:
    with open(sys.argv[1],"rb") as source: preferences=plistlib.load(source)
    if not isinstance(preferences,dict): raise ValueError("expected a preference dictionary")
except (OSError,ValueError,plistlib.InvalidFileException):
    sys.exit(2)
sys.exit(0 if preferences else 1)
' "$WORK_DIR/preferences.plist"
}
restore_factory_edid() {
  local uuid="$1" required="$2" factory current
  if ! factory="$(bd get "--UUID=$uuid" --i2cEDID)" || [ -z "$factory" ]; then
    [ "$required" = 0 ]; return $?
  fi
  current="$(bd get "--UUID=$uuid" --osEDID)" || return 1
  [ "$current" = "$factory" ] && return 0
  bd perform "--UUID=$uuid" --applyFactoryEDID >/dev/null || return 1
  wait_for matches "$uuid" osEDID "$factory"
}
reset_displays() {
  local raw uuids uuid odyssey modes number
  local RATE=120
  raw="$(bd get --identifiers)" || return 1
  uuids="$(printf '%s' "$raw" | run python3 -c '
import json,sys
devices=json.loads("["+sys.stdin.read()+"]")
if any(d.get("deviceType")=="VirtualScreen" for d in devices):
    print("virtual screens remain after app reset",file=sys.stderr); sys.exit(1)
for d in devices:
    if d.get("deviceType")=="Display" and str(d.get("displayID","0"))!="0":
        if not d.get("UUID") or d["UUID"]=="UNKNOWN": sys.exit(1)
        print(d["UUID"]+"|"+str(int(sys.argv[1].lower() in d.get("name", "").lower())))
' "$MATCH")" || return 1
  while IFS='|' read -r uuid odyssey; do
    [ -n "$uuid" ] || continue
    restore_factory_edid "$uuid" "$odyssey" || { fail 'factory EDID did not verify'; return 1; }
    bd set "--UUID=$uuid" --protectAll=off --mirror=off >/dev/null || return 1
    if [ "$odyssey" = 1 ]; then
      wait_for select_mode "$uuid" 3840x1080 || {
        fail 'reset requires an available 3840x1080 HiDPI at 120 Hz mode'; return 1;
      }
      bd set "--UUID=$uuid" --main=on >/dev/null || return 1
      wait_for matches "$uuid" main true || return 1
      wait_for matches "$uuid" mirror off || return 1
      say 'Reset desktop: 3840x1080 HiDPI at 120 Hz; no virtual screen.'
      say "Physical output: $(bd get "--UUID=$uuid" --connectionMode)"
      continue
    fi
    modes="$(bd get "--UUID=$uuid" --displayModeList)" || return 1
    number="$(printf '%s' "$modes" | run python3 -c '
import re,sys
for line in sys.stdin:
    match=re.match(r"^(\d+) - .*\bDefault\b",line)
    if match: print(match[1]); sys.exit(0)
print("no advertised default display mode",file=sys.stderr); sys.exit(1)
')" || return 1
    bd set "--UUID=$uuid" "--displayModeNumber=$number" >/dev/null || return 1
    wait_for matches "$uuid" displayModeNumber "$number" || return 1
    wait_for matches "$uuid" mirror off || return 1
  done <<< "$uuids"
}
cmd_reset() {
  local exists backup
  say 'Resetting ALL BetterDisplay preferences and virtual screens.'
  if ! app_stopped; then
    run osascript -e 'tell application "BetterDisplay" to quit' >/dev/null || return 1
    wait_for app_stopped || { fail 'BetterDisplay did not stop; settings retained'; return 1; }
  fi
  preference_domain_exists; exists=$?
  [ "$exists" -le 1 ] || { fail 'cannot inspect preference domain'; return 1; }
  if [ "$exists" -eq 0 ]; then
    mkdir -p "$LOG_DIR/backups" || return 1
    backup="$LOG_DIR/backups/$(basename "$LOG_FILE" .log).plist"
    run defaults export "$DOMAIN" "$backup" >/dev/null || { fail 'preference backup failed; settings retained'; return 1; }
    chmod 600 "$backup" || return 1
    say "Preference backup: $backup"
    run defaults delete "$DOMAIN" >/dev/null || { fail 'preference reset failed'; return 1; }
  fi
  preference_domain_exists; exists=$?
  [ "$exists" -eq 1 ] || { fail 'preference domain was not cleared'; return 1; }
  PHYSICAL_UUID='' VIRTUAL_UUID=''
  run open -g -a BetterDisplay || return 1
  wait_for cli_ready || { fail 'BetterDisplay did not become ready after reset'; return 1; }
  reset_displays || { fail 'app preferences cleared, but reset display state did not verify'; return 1; }
  say '[ok] BetterDisplay preferences reset; no virtual screens; reset display modes verified.'
}
mode_number() {
  local uuid="$1" resolution="$2" modes number
  modes="$(bd get "--UUID=$uuid" --displayModeList)" || return 1
  number="$(printf '%s' "$modes" | run python3 -c '
import re,sys
pattern=r"^(\d+) - "+re.escape(sys.argv[1])+r" HiDPI ([0-9.]+)Hz(?: |$)"
for line in sys.stdin:
    match=re.match(pattern,line)
    if match and abs(float(match[2])-float(sys.argv[2]))<=0.2:
        print(match[1]); sys.exit(0)
print("requested HiDPI refresh mode is unavailable",file=sys.stderr); sys.exit(1)
' "$resolution" "$RATE")" || return 1
  printf '%s\n' "$number"
}
select_mode() {
  local uuid="$1" resolution="$2" number
  number="$(mode_number "$uuid" "$resolution")" || return 1
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
  run open -g -a BetterDisplay || return 1
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
  native_seed || { fail 'native output did not verify after selecting the HiDPI seed'; return 1; }
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
  setv "--resolution=$LAND" --hiDPI=on --refreshRate=60Hz >/dev/null || return 1
  wait_for matches "$VIRTUAL_UUID" resolution "$LAND" || return 1
  wait_for matches "$VIRTUAL_UUID" hiDPI on || return 1
  setv --mirror=on "--targetUUID=$PHYSICAL_UUID" >/dev/null || true
  wait_for matches "$VIRTUAL_UUID" mirror on || return 1
  setv --main=on >/dev/null || true
  if ! wait_for matches "$VIRTUAL_UUID" main true; then setv --main=on >/dev/null || true; fi
  wait_for sharp_state
}
cmd_set() {
  resolve virtual || { fail 'ambiguous managed virtual screen'; return 1; }
  preflight || return 1
  SWITCHING=1
  if ! ensure_preferences; then
    cmd_reset || say 'Recovery failed; inspect the log and BetterDisplay.'
    SWITCHING=0
    fail 'could not configure BetterDisplay preferences'
    return 1
  fi
  if sharp_state; then
    SWITCHING=0
    say "[ok] Already at $LAND HiDPI, mirrored at $RATE Hz with native 7680x2160 output."
    return 0
  fi
  say "Setting $LAND HiDPI at $RATE Hz (requested $WANT)."
  if apply_sharp; then
    SWITCHING=0
    snapshot
    say "[ok] $LABEL $LAND HiDPI mirror at $RATE Hz with native 7680x2160 output."
  else
    snapshot
    say 'Setup failed; restoring BetterDisplay defaults.'
    cmd_reset || say 'Recovery failed; inspect the log and BetterDisplay.'
    SWITCHING=0
    fail "$LABEL setup failed; requested mode is not active"
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
    set|sharp)
      mode='set'
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
    check|reset) [ "$#" -le 1 ] || { fail 'usage: g95nc {check|sharp [WxH]|set [WxH]|butter|reset}'; return 2; } ;;
    *) fail 'usage: g95nc {check|sharp [WxH]|set [WxH]|butter|reset}'; return 2 ;;
  esac
  command -v "$CLI" >/dev/null || { fail "'$CLI' not found"; return 1; }
  if [ "$mode" = reset ]; then cmd_reset; return $?; fi
  if app_stopped; then
    [ "$mode" != check ] || { fail 'BetterDisplay is not running'; return 1; }
    run open -g -a BetterDisplay || return 1
  fi
  wait_for cli_ready || { fail 'BetterDisplay CLI is unresponsive'; return 1; }
  bd help | head -1 >> "$LOG_FILE" || true
  require_display || return 1
  snapshot
  "cmd_$mode"
}
main "$@"
