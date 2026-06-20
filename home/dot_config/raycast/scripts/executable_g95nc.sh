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
# g95nc — drive the Samsung Odyssey G95NC (7680x2160, 32:9) on Apple Silicon
# through the BetterDisplay CLI. Doubles as a Raycast command (dropdown above)
# and a plain CLI tool: `g95nc {check|set [WxH]|reset [single|dual]}` (defaults to check).
#
# This panel renegotiates down to 60Hz on an HBR3 / DP 1.4 link and hides its higher
# modes; sharp HiDPI at the full framebuffer is bandwidth-capped to 60Hz on this cable.
#
#   set [WxH] -> sharp HiDPI via virtual-screen mirror with a working app-menu slider.
#             Cabling-aware: single-cable mirrors the whole panel (default 4352x1224);
#             dual-cable mirrors the work/DP pane (default 2900x1224) + re-asserts the
#             comms pane to RGB Full. Optional WxH snaps to nearest step; slide to tune.
#             Denser than 2x needs the GUI "Enable resolutions over 8K" toggle.
#   reset  -> clean slate, auto-detects cabling: single-cable restores the whole panel
#             to 3840x1080 HiDPI; dual-cable PBP clears overlays and leaves both panes
#             native. Drops all protections/mirrors/PIPs + virtual screens; renames kept.
#             Force with: reset single | reset dual.
#   check  -> read-only state + negotiation-trap report.
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

# Stop any mirror/stream/pip from our virtual screen and discard it. Used by every
# mode so switching modes always starts from a clean slate.
teardown_vs() {
  # stop any mirror/stream/PIP that targets the panel itself
  setp --mirror=off 2>/dev/null || true
  setp --stream=off 2>/dev/null || true
  setp --pip=off 2>/dev/null || true
  # stop and discard this script's virtual screen
  "$CLI" set --name="$VS_NAME" --pip=off 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --stream=off 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --mirror=off 2>/dev/null || true
  "$CLI" discard --nameLike="$VS_NAME" 2>/dev/null || true
}

# One line per connected G95NC pane as "UUID<TAB>name". Matches MATCH in the display's
# name field, so it survives the DP/HDMI EDID renames and ignores virtual screens/groups.
# The line count distinguishes single-cable (1) from dual-cable PBP (2).
g95_panes() {
  "$CLI" get --identifiers 2>/dev/null | awk -F'"' -v m="$MATCH" '
    $2=="UUID" { u=$4 }
    $2=="name" && tolower($4) ~ tolower(m) { print u "\t" $4 }
  '
}
g95_uuids() { g95_panes | cut -f1; }

# Force a display (selector flag, e.g. "--UUID=...") to the best SDR RGB Full connection
# mode, preferring 10-bit. HDMI/PBP panes otherwise default to washed-out YCbCr Limited;
# DP panes are already RGB Full so this is a no-op there. A protect call is attempted but
# CLI colour-mode protection is unreliable in this build, so reset re-applies on demand.
normalize_rgb_full() {
  local sel="$1" cml id
  cml="$("$CLI" get "$sel" --connectionModeList 2>/dev/null)"
  id="$(printf '%s\n' "$cml" | grep -i 'SDR' | grep -i 'RGB Full' | grep '10bit' | head -1 | awk '{print $1}')"
  [ -n "$id" ] || id="$(printf '%s\n' "$cml" | grep -i 'SDR' | grep -i 'RGB Full' | head -1 | awk '{print $1}')"
  if [ -n "$id" ]; then
    "$CLI" set "$sel" --connectionMode="$id" 2>/dev/null || true
    "$CLI" set "$sel" --protectSDRColorMode=on 2>/dev/null || true
  fi
}

require_cli() {
  command -v "$CLI" >/dev/null 2>&1 || { echo "error: '$CLI' not found in PATH" >&2; exit 1; }
  # The CLI is a thin client for the BetterDisplay app; with the app down its calls
  # hang or return empty, which masquerades as "no display". Check the app is up first.
  pgrep -x BetterDisplay >/dev/null 2>&1 || { echo "error: BetterDisplay isn't running — launch it ('open -a BetterDisplay') and retry." >&2; exit 1; }
  disp --resolution >/dev/null || { echo "error: no display matching '$MATCH' (set G95_MATCH)" >&2; exit 1; }
}

# State block + trap notes for one display. Args: $1 selector flag, $2 mode (single|dual).
report_pane() {
  local sel="$1" mode="$2" name="$3"
  local res rr hidpi main cmode depth rrlist
  res="$("$CLI" get "$sel" --resolution 2>/dev/null)"
  rr="$("$CLI" get "$sel" --refreshRate 2>/dev/null)"
  hidpi="$("$CLI" get "$sel" --hiDPI 2>/dev/null)"
  main="$("$CLI" get "$sel" --main 2>/dev/null)"
  cmode="$("$CLI" get "$sel" --connectionMode 2>/dev/null)"
  depth="$("$CLI" get "$sel" --colordepth 2>/dev/null)"
  rrlist="$("$CLI" get "$sel" --refreshRateList 2>/dev/null)"

  bar; echo "${name:-(unknown display)}"; bar
  printf '  %-22s %s\n' "Resolution (logical)" "$res"
  printf '  %-22s %s\n' "Refresh (current)"    "$rr"
  printf '  %-22s %s\n' "HiDPI"                "$hidpi"
  printf '  %-22s %s\n' "Colour depth"         "$depth"
  printf '  %-22s %s\n' "Main display"         "$main"
  printf '  %-22s %s\n' "Connection mode"      "$cmode"
  printf '  %-22s %s\n' "Refresh rates here"   "$(printf '%s' "$rrlist" | tr '\n' ' ')"
  case "$rr" in
    60Hz|59*|60.0*)
      if [ "$mode" = dual ]; then echo "  [i] 60Hz is expected for a PBP pane on this cable."
      else echo "  [!] Pinned at 60Hz — the full-panel negotiation lock."; fi ;;
    *) echo "  [ok] Running above 60Hz." ;;
  esac
  if printf '%s' "$cmode" | grep -q '10bit'; then
    echo "  [i] 10-bit colour negotiated — heavier; 8-bit frees bandwidth for higher Hz."
  fi
}

cmd_check() {
  local panes n mode u nm first sel
  panes="$(g95_panes)"
  n="$(printf '%s' "$panes" | grep -c .)"
  if [ "$n" -ge 2 ]; then mode=dual; else mode=single; fi

  bar; echo "STEP 0 — $n G95NC pane(s) detected (${mode}-cable)"; bar
  echo
  if [ "$n" -eq 0 ]; then
    report_pane "--nameLike=$MATCH" single ""
  else
    printf '%s\n' "$panes" | while IFS=$'\t' read -r u nm; do
      [ -n "$u" ] || continue
      report_pane "--UUID=$u" "$mode" "$nm"
      echo
    done
  fi

  if [ "$mode" = single ]; then
    first="$(printf '%s\n' "$panes" | head -1 | cut -f1)"
    if [ -n "$first" ]; then sel="--UUID=$first"; else sel="--nameLike=$MATCH"; fi
    echo "High-refresh signal modes the link offers (no workaround needed):"
    "$CLI" get "$sel" --connectionModeListAll 2>/dev/null \
      | grep -E '11[0-9]\.|120\.|239\.' \
      | grep -Ei '5120x1440|3840x2160|5120x2160' \
      | sed 's/^/  /' | head -10
  else
    echo "PBP note: each pane caps at ~60Hz on this cable; higher Hz needs reduced per-pane resolution."
  fi
}

# Sharp HiDPI via a mirrored virtual screen, with a working BetterDisplay scaling slider.
# Cabling-aware: single-cable mirrors the whole panel; dual-cable PBP mirrors the work
# (5120x2160 / DP) pane and re-asserts the comms pane to RGB Full. Optional target
# "looks like" resolution as the first arg (e.g. `set 3200x1350`) — snapped to the nearest
# generated step (k * aspect) so it matches a real ladder entry; the slider fine-tunes.
cmd_set() {
  local want="${1:-}"
  local panes n mode; panes="$(g95_panes)"; n="$(printf '%s' "$panes" | grep -c .)"
  if [ "$n" -ge 2 ]; then mode=dual; else mode=single; fi

  local aspectw aspecth default work=""
  if [ "$mode" = dual ]; then
    work="$(g95_uuids | while IFS= read -r u; do [ -n "$u" ] || continue
      "$CLI" get --UUID="$u" --displayModeList 2>/dev/null | grep -q '5120x2160' && { printf '%s' "$u"; break; }; done)"
    aspectw=64; aspecth=27; default=2900x1224
  else
    aspectw=32; aspecth=9; default=4352x1224
  fi
  [ -n "$want" ] || want="$default"
  case "$want" in [0-9]*x[0-9]*) : ;; *) echo ">> '$want' isn't WxH; using $default"; want="$default" ;; esac
  if [ "$mode" = dual ] && [ -z "$work" ]; then
    echo "[!] Couldn't identify the 5120x2160 work pane — run 'g95nc check'. Aborting."; return 1
  fi

  # Snap the requested width to the nearest generated step (k * aspect) so the set matches
  # a real ladder entry; the BetterDisplay slider then fine-tunes around it.
  local kw k landw landh land
  kw="${want%%x*}"
  k=$(( (kw + aspectw / 2) / aspectw )); [ "$k" -lt 1 ] && k=1
  landw=$(( k * aspectw )); landh=$(( k * aspecth )); land="${landw}x${landh}"
  echo ">> set (${mode}-cable): mirror $land HiDPI onto the work pane (requested $want); slider fine-tunes."

  # clear overlays on every pane; nuke virtual screens
  if [ "$n" -gt 0 ]; then
    g95_uuids | while IFS= read -r u; do [ -n "$u" ] || continue
      "$CLI" set --UUID="$u" --protectAll=off 2>/dev/null || true
      "$CLI" set --UUID="$u" --mirror=off 2>/dev/null || true
      "$CLI" set --UUID="$u" --pip=off 2>/dev/null || true
    done
  else
    setp --protectAll=off 2>/dev/null || true
  fi
  "$CLI" discard --type=VirtualScreen 2>/dev/null || true
  sleep 1

  # GENERATED-resolution virtual screen => the app-menu scaling slider works
  "$CLI" create --devicetype=virtualscreen --virtualscreenname="$VS_NAME" --aspectWidth="$aspectw" --aspectHeight="$aspecth"
  "$CLI" set --name="$VS_NAME" --useResolutionList=off --virtualScreenHiDPI=on
  "$CLI" set --name="$VS_NAME" --connected=on
  sleep 2

  # land on the snapped resolution, mirror onto the work pane
  if [ "$mode" = dual ]; then
    "$CLI" set --UUID="$work" --resolution=5120x2160 --hidpi=off 2>/dev/null || true
    "$CLI" set --name="$VS_NAME" --resolution="$land" --hidpi=on 2>/dev/null || true
    "$CLI" set --name="$VS_NAME" --mirror=on --targetUUID="$work"
  else
    setp --resolution=5120x1440 --hidpi=off --refreshrate=60Hz 2>/dev/null || true
    "$CLI" set --name="$VS_NAME" --resolution="$land" --hidpi=on 2>/dev/null || true
    "$CLI" set --name="$VS_NAME" --mirror=on --targetNameLike="$MATCH"
  fi
  sleep 2

  # make the mirrored work desktop the main display (at 0,0) — verify + one retry (flaky)
  "$CLI" set --name="$VS_NAME" --main=on 2>/dev/null || true
  sleep 1
  [ "$("$CLI" get --name="$VS_NAME" --main 2>/dev/null)" = "true" ] || { "$CLI" set --name="$VS_NAME" --main=on 2>/dev/null || true; sleep 1; }

  # dual: re-assert comms to RGB Full and place it at the work desktop's right edge
  if [ "$mode" = dual ]; then
    g95_uuids | while IFS= read -r u; do [ -n "$u" ] || continue
      [ "$u" = "$work" ] && continue
      normalize_rgb_full "--UUID=$u"
      "$CLI" set --UUID="$u" --placement="${landw}x0" 2>/dev/null || true
    done
  fi

  local vres vhid; vres="$("$CLI" get --name="$VS_NAME" --resolution 2>/dev/null)"; vhid="$("$CLI" get --name="$VS_NAME" --hiDPI 2>/dev/null)"
  echo ">> desktop (virtual): $vres HiDPI=$vhid  (drag BetterDisplay's Resolution slider to fine-tune)"
  if [ "$vres" = "$land" ] && [ "$vhid" = "on" ]; then
    echo "[ok] Sharp HiDPI mirror live. Flicker/freeze/panic-on-wake? run: $0 reset"
  else
    echo "[!] Didn't land at $land HiDPI (got $vres / $vhid). Going denser than 2x on a single cable needs the 'Enable resolutions over 8K' toggle. Reverting."
    cmd_reset "$mode"
  fi
}

# Clean-slate bail-out. Auto-detects cabling by counting connected panes and resets
# appropriately:
#   single-cable (1 pane) -> whole panel back to native 3840x1080 HiDPI @ 60Hz
#   dual-cable PBP (2 panes) -> clear overlays, leave both panes native (work/5120-capable
#                               pane to 5120x2160 HiDPI)
# Either way it drops all protections/mirrors/streams/PIPs and every virtual screen.
# EDID renames are left intact. Force a mode with: reset single | reset dual.
cmd_reset() {
  local mode="${1:-auto}" u uuids n first sel res hidpi work
  uuids="$(g95_uuids)"
  n="$(printf '%s' "$uuids" | grep -c .)"
  case "$mode" in
    auto)        if [ "$n" -ge 2 ]; then mode=dual; else mode=single; fi
                 echo ">> reset: detected $n G95NC pane(s) -> $mode mode" ;;
    single|dual) echo ">> reset: forced $mode mode ($n pane(s) detected)" ;;
    *)           echo "usage: $0 reset [single|dual]" >&2; return 2 ;;
  esac

  # Common teardown: drop protections + any mirror/stream/PIP on every detected pane,
  # then nuke every virtual screen (by type, so name/config drift can't hide one).
  if [ "$n" -gt 0 ]; then
    printf '%s\n' "$uuids" | while IFS= read -r u; do
      [ -n "$u" ] || continue
      "$CLI" set --UUID="$u" --protectAll=off 2>/dev/null || true
      "$CLI" set --UUID="$u" --mirror=off 2>/dev/null || true
      "$CLI" set --UUID="$u" --stream=off 2>/dev/null || true
      "$CLI" set --UUID="$u" --pip=off 2>/dev/null || true
    done
  else
    setp --protectAll=off 2>/dev/null || true
    setp --mirror=off 2>/dev/null || true
  fi
  "$CLI" discard --type=VirtualScreen 2>/dev/null || true
  sleep 1

  if [ "$mode" = single ]; then
    first="$(printf '%s\n' "$uuids" | head -1)"
    if [ -n "$first" ]; then sel="--UUID=$first"; else sel="--nameLike=$MATCH"; fi
    "$CLI" set "$sel" --main=on 2>/dev/null || true
    "$CLI" set "$sel" --reinitialize 2>/dev/null || true
    # colour depth is a connectionMode knob, not a display-mode attribute — don't force it here
    "$CLI" set "$sel" --resolution=3840x1080 2>/dev/null || true
    "$CLI" set "$sel" --hidpi=on 2>/dev/null || true
    sleep 2
    res="$("$CLI" get "$sel" --resolution 2>/dev/null)"; hidpi="$("$CLI" get "$sel" --hiDPI 2>/dev/null)"
    if [ "$res" != "3840x1080" ]; then
      "$CLI" set "$sel" --reinitialize 2>/dev/null || true; sleep 1
      "$CLI" set "$sel" --resolution=3840x1080 2>/dev/null || true
      "$CLI" set "$sel" --hidpi=on 2>/dev/null || true; sleep 2
      res="$("$CLI" get "$sel" --resolution 2>/dev/null)"; hidpi="$("$CLI" get "$sel" --hiDPI 2>/dev/null)"
    fi
    normalize_rgb_full "$sel"
    echo ">> now: $res HiDPI=$hidpi"
    case "$res" in
      3840x1080) echo "[ok] Clean slate: single display, 3840x1080 HiDPI @ 60Hz." ;;
      *) echo "[!] Not at 3840x1080 (got $res) — re-run, or 'g95nc check'." ;;
    esac
  else
    echo ">> PBP clean slate: overlays cleared; panes native + RGB Full; comms right of work; renames kept."
    work="$(printf '%s\n' "$uuids" | while IFS= read -r u; do [ -n "$u" ] || continue
      "$CLI" get --UUID="$u" --displayModeList 2>/dev/null | grep -q '5120x2160' && { printf '%s' "$u"; break; }; done)"
    if [ "$n" -gt 0 ]; then
      printf '%s\n' "$uuids" | while IFS= read -r u; do
        [ -n "$u" ] || continue
        if [ "$u" = "$work" ]; then
          "$CLI" set --UUID="$u" --resolution=5120x2160 2>/dev/null || true
          "$CLI" set --UUID="$u" --hidpi=on 2>/dev/null || true
          sleep 1
        fi
        normalize_rgb_full "--UUID=$u"
        echo "   pane: $("$CLI" get --UUID="$u" --resolution 2>/dev/null) HiDPI=$("$CLI" get --UUID="$u" --hiDPI 2>/dev/null) | $("$CLI" get --UUID="$u" --connectionMode 2>/dev/null | grep -oE '[0-9]+bit .*SRGB' | sed 's/ SRGB//')"
      done
    fi
    # work pane = main; comms to its right
    if [ -n "$work" ]; then
      "$CLI" set --UUID="$work" --main=on 2>/dev/null || true; sleep 1
      printf '%s\n' "$uuids" | while IFS= read -r u; do [ -n "$u" ] || continue
        [ "$u" = "$work" ] && continue
        "$CLI" set --UUID="$u" --placement=2560x0 2>/dev/null || true  # comms right of the 2560-wide (5120 HiDPI) work pane
      done
    fi
  fi
}

main() {
  require_cli
  case "${1:-check}" in
    check)  cmd_check ;;
    set)    cmd_set "${2:-}" ;;
    reset)  cmd_reset "${2:-auto}" ;;
    *) echo "usage: $0 {check|set [WxH]|reset [single|dual]}" >&2; exit 2 ;;
  esac
}
main "$@"
