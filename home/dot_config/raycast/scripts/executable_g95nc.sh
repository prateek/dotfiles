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
# @raycast.argument1 { "type": "dropdown", "placeholder": "mode", "data": [{"title": "Sharp — HiDPI 60Hz", "value": "set"}, {"title": "Reset — clean slate", "value": "reset"}, {"title": "Check status", "value": "check"}] }
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Set the Samsung Odyssey G95NC to sharp HiDPI 60Hz (set), reset to a native clean slate (reset), or check current state. Drives the BetterDisplay CLI.
# @raycast.author Prateek Rungta
#
# g95nc — drive the Samsung Odyssey G95NC (7680x2160, 32:9) on Apple Silicon over a
# single DisplayPort cable, through the BetterDisplay CLI. Doubles as a Raycast command
# (dropdown above) and a plain CLI tool: `g95nc {check|set [WxH]|reset}` (defaults to check).
#
# This panel renegotiates down to 60Hz on an HBR3 / DP 1.4 link and hides its higher
# modes; sharp HiDPI at the full framebuffer is bandwidth-capped to 60Hz on this cable.
#
#   set [WxH] -> sharp HiDPI via a mirrored virtual screen, with a working app-menu
#                scaling slider. Mirrors the whole panel (default 4352x1224); an optional
#                target "looks like" WxH snaps to the nearest generated step (k * 32:9).
#                Going denser than 2x needs the GUI "Enable resolutions over 8K" toggle.
#   reset     -> clean-slate bail-out: drops all protections/mirrors/streams/PIPs and
#                every virtual screen, then restores the panel to native 3840x1080 HiDPI.
#   check     -> read-only state + negotiation-trap report.
#
# Note: deliberately NOT `set -e` — betterdisplaycli returns non-zero on some
# benign mode switches, and we handle failures explicitly with verify + revert.

set -uo pipefail

# Raycast runs with a minimal PATH; make sure Homebrew bins (betterdisplaycli) resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CLI="${BD_CLI:-betterdisplaycli}"
MATCH="${G95_MATCH:-Odyssey}"           # nameLike match for the physical G95NC
VS_NAME="${G95_VS_NAME:-G95-HiDPI}"     # virtual screen used by the sharp mode

disp()  { "$CLI" get --nameLike="$MATCH" "$@" 2>/dev/null; }
setp()  { "$CLI" set --nameLike="$MATCH" "$@"; }
bar()   { printf '%s\n' "------------------------------------------------------------"; }

# Drop every overlay we might have set and discard all virtual screens, so each mode
# starts from a clean slate. Discards by type so name/config drift can't hide one.
teardown() {
  setp --protectAll=off 2>/dev/null || true
  setp --mirror=off 2>/dev/null || true
  setp --stream=off 2>/dev/null || true
  setp --pip=off 2>/dev/null || true
  "$CLI" discard --type=VirtualScreen 2>/dev/null || true
  sleep 1
}

require_cli() {
  command -v "$CLI" >/dev/null 2>&1 || { echo "error: '$CLI' not found in PATH" >&2; exit 1; }
  # The CLI is a thin client for the BetterDisplay app; with the app down its calls
  # hang or return empty, which masquerades as "no display". Check the app is up first.
  pgrep -x BetterDisplay >/dev/null 2>&1 || { echo "error: BetterDisplay isn't running — launch it ('open -a BetterDisplay') and retry." >&2; exit 1; }
  disp --resolution >/dev/null || { echo "error: no display matching '$MATCH' (set G95_MATCH)" >&2; exit 1; }
}

cmd_check() {
  local res rr hidpi main cmode depth rrlist
  res="$(disp --resolution)"
  rr="$(disp --refreshRate)"
  hidpi="$(disp --hiDPI)"
  main="$(disp --main)"
  cmode="$(disp --connectionMode)"
  depth="$(disp --colordepth)"
  rrlist="$(disp --refreshRateList)"

  bar; echo "Odyssey G95NC — current state"; bar
  printf '  %-22s %s\n' "Resolution (logical)" "$res"
  printf '  %-22s %s\n' "Refresh (current)"    "$rr"
  printf '  %-22s %s\n' "HiDPI"                "$hidpi"
  printf '  %-22s %s\n' "Colour depth"         "$depth"
  printf '  %-22s %s\n' "Main display"         "$main"
  printf '  %-22s %s\n' "Connection mode"      "$cmode"
  printf '  %-22s %s\n' "Refresh rates here"   "$(printf '%s' "$rrlist" | tr '\n' ' ')"
  case "$rr" in
    60Hz|59*|60.0*) echo "  [!] Pinned at 60Hz — the full-panel negotiation lock." ;;
    *)              echo "  [ok] Running above 60Hz." ;;
  esac
  if printf '%s' "$cmode" | grep -q '10bit'; then
    echo "  [i] 10-bit colour negotiated — heavier; 8-bit frees bandwidth for higher Hz."
  fi
  echo
  echo "High-refresh signal modes the link offers (no workaround needed):"
  disp --connectionModeListAll \
    | grep -E '11[0-9]\.|120\.|239\.' \
    | grep -Ei '5120x1440|3840x2160|5120x2160|7680x2160' \
    | sed 's/^/  /' | head -10
}

# Sharp HiDPI via a mirrored virtual screen, with a working BetterDisplay scaling slider.
# Mirrors the whole panel. Optional target "looks like" resolution as the first arg
# (e.g. `set 5120x1440`) — snapped to the nearest generated step (k * 32:9) so it matches
# a real ladder entry; the BetterDisplay slider then fine-tunes around it.
cmd_set() {
  local want="${1:-}"
  local aspectw=32 aspecth=9 default=4352x1224
  [ -n "$want" ] || want="$default"
  case "$want" in [0-9]*x[0-9]*) : ;; *) echo ">> '$want' isn't WxH; using $default"; want="$default" ;; esac

  # Snap the requested width to the nearest generated step (k * aspect) so the set matches
  # a real ladder entry; the BetterDisplay slider then fine-tunes around it.
  local kw k landw landh land
  kw="${want%%x*}"
  k=$(( (kw + aspectw / 2) / aspectw )); [ "$k" -lt 1 ] && k=1
  landw=$(( k * aspectw )); landh=$(( k * aspecth )); land="${landw}x${landh}"
  echo ">> set: mirror $land HiDPI onto the panel (requested $want); slider fine-tunes."

  teardown

  # GENERATED-resolution virtual screen => the app-menu scaling slider works
  "$CLI" create --devicetype=virtualscreen --virtualscreenname="$VS_NAME" --aspectWidth="$aspectw" --aspectHeight="$aspecth"
  "$CLI" set --name="$VS_NAME" --useResolutionList=off --virtualScreenHiDPI=on
  "$CLI" set --name="$VS_NAME" --connected=on
  sleep 2

  # land on the snapped resolution, mirror onto the panel
  setp --resolution=5120x1440 --hidpi=off --refreshrate=60Hz 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --resolution="$land" --hidpi=on 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --mirror=on --targetNameLike="$MATCH"
  sleep 2

  # make the mirrored desktop the main display — verify + one retry (it's flaky)
  "$CLI" set --name="$VS_NAME" --main=on 2>/dev/null || true
  sleep 1
  [ "$("$CLI" get --name="$VS_NAME" --main 2>/dev/null)" = "true" ] || { "$CLI" set --name="$VS_NAME" --main=on 2>/dev/null || true; sleep 1; }

  local vres vhid; vres="$("$CLI" get --name="$VS_NAME" --resolution 2>/dev/null)"; vhid="$("$CLI" get --name="$VS_NAME" --hiDPI 2>/dev/null)"
  echo ">> desktop (virtual): $vres HiDPI=$vhid  (drag BetterDisplay's Resolution slider to fine-tune)"
  if [ "$vres" = "$land" ] && [ "$vhid" = "on" ]; then
    echo "[ok] Sharp HiDPI mirror live. Flicker/freeze/panic-on-wake? run: $0 reset"
  else
    echo "[!] Didn't land at $land HiDPI (got $vres / $vhid). Going denser than 2x needs the 'Enable resolutions over 8K' toggle. Reverting."
    cmd_reset
  fi
}

# Clean-slate bail-out: drop all protections/mirrors/streams/PIPs and every virtual
# screen, then restore the panel to native 3840x1080 HiDPI @ 60Hz. The guaranteed
# way back from any state.
cmd_reset() {
  local sel="--nameLike=$MATCH" res hidpi
  echo ">> reset: clearing overlays + virtual screens, restoring native 3840x1080 HiDPI"
  teardown

  "$CLI" set "$sel" --main=on 2>/dev/null || true
  "$CLI" set "$sel" --reinitialize 2>/dev/null || true
  # colour depth is a connectionMode knob, not a display-mode attribute — don't force it here
  "$CLI" set "$sel" --resolution=3840x1080 2>/dev/null || true
  "$CLI" set "$sel" --hidpi=on 2>/dev/null || true
  sleep 2
  res="$(disp --resolution)"; hidpi="$(disp --hiDPI)"
  if [ "$res" != "3840x1080" ]; then
    "$CLI" set "$sel" --reinitialize 2>/dev/null || true; sleep 1
    "$CLI" set "$sel" --resolution=3840x1080 2>/dev/null || true
    "$CLI" set "$sel" --hidpi=on 2>/dev/null || true; sleep 2
    res="$(disp --resolution)"; hidpi="$(disp --hiDPI)"
  fi
  echo ">> now: $res HiDPI=$hidpi"
  case "$res" in
    3840x1080) echo "[ok] Clean slate: 3840x1080 HiDPI @ 60Hz." ;;
    *)         echo "[!] Not at 3840x1080 (got $res) — re-run, or 'g95nc check'." ;;
  esac
}

main() {
  require_cli
  case "${1:-check}" in
    check)  cmd_check ;;
    set)    cmd_set "${2:-}" ;;
    reset)  cmd_reset ;;
    *) echo "usage: $0 {check|set [WxH]|reset}" >&2; exit 2 ;;
  esac
}
main "$@"
