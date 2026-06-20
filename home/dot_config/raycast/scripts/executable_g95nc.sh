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
# @raycast.argument1 { "type": "dropdown", "placeholder": "mode", "data": [{"title": "Sharp — HiDPI 60Hz", "value": "set"}, {"title": "Fast — 120Hz", "value": "fast"}, {"title": "Reset — 1080p HiDPI", "value": "reset"}, {"title": "Check status", "value": "check"}] }
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Switch the Samsung Odyssey G95NC between sharp HiDPI 60Hz (set), smooth 120Hz (fast), and the native 1080p-HiDPI fallback (reset); or check current state. Drives the BetterDisplay CLI.
# @raycast.author Prateek Rungta
#
# g95nc — drive the Samsung Odyssey G95NC (7680x2160, 32:9) on Apple Silicon
# through the BetterDisplay CLI. Doubles as a Raycast command (dropdown above)
# and a plain CLI tool: `g95nc {check|set|fast|reset [single|dual]}` (defaults to check).
#
# This panel renegotiates down to 60Hz on an HBR3 / DP 1.4 link and hides its
# higher modes. On this cable you can't have sharp + 120Hz at once, so:
#
#   set    -> sharp HiDPI @ 60Hz       full workspace; lands at 4352x1224 (85% of 1440p)
#             but the app-menu slider scales the whole HiDPI ladder (virtual-screen
#             mirror; needs the GUI "Enable resolutions over 8K" toggle). Daily driver.
#   fast   -> 5120x1440 LoDPI @ 120Hz  smooth motion, slightly soft text (native).
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
DEFAULT_HIDPI="${G95_HIDPI:-4352x1224}" # default 'looks like' size for `set` — 85% of 5120x1440 (1440p ultrawide)

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

# Daily driver: sharp HiDPI @ 60Hz via a mirrored virtual screen. Lands at
# DEFAULT_HIDPI; the app-menu slider scales the rest of the ladder. True
# 5120x1440 HiDPI needs a 10240px framebuffer, which exceeds Apple Silicon's
# 7680px native cap — so it only exists on a virtual screen with over-8K enabled.
cmd_set() {
  echo ">> set: $DEFAULT_HIDPI HiDPI @ 60Hz (sharp) via virtual-screen mirror; slider scales from here."
  setp --protectAll=off 2>/dev/null || true   # let the mirror reconfigure the panel
  teardown_vs

  "$CLI" create --devicetype=virtualscreen --virtualscreenname="$VS_NAME" --aspectWidth=32 --aspectHeight=9
  # Generated resolutions (not a fixed list) so the app-menu slider scales the full
  # HiDPI ladder live. It lands on DEFAULT_HIDPI below; drag the slider to taste.
  "$CLI" set --name="$VS_NAME" --useResolutionList=off --virtualScreenHiDPI=on
  "$CLI" set --name="$VS_NAME" --connected=on
  sleep 2

  # prove over-8K actually yielded the HiDPI mode before touching the live screen
  if ! "$CLI" get --name="$VS_NAME" --displayModeList 2>/dev/null | grep -Eiq '10240x2880|5120x1440.*hidpi'; then
    echo "[!] No 5120x1440 HiDPI mode — enable Settings > Displays > Additional settings… > 'Enable resolutions over 8K'. Cleaning up, no live change."
    "$CLI" discard --nameLike="$VS_NAME" 2>/dev/null || true
    return 1
  fi
  echo "[ok] Virtual screen exposes 5120x1440 HiDPI."

  # base the panel on a 5120x1440 signal, mirror VS -> panel, make VS the desktop
  setp --resolution=5120x1440 --hidpi=off --refreshrate=60Hz 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --resolution="$DEFAULT_HIDPI" --hidpi=on 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --mirror=on --targetNameLike="$MATCH"
  "$CLI" set --name="$VS_NAME" --main=on
  sleep 3

  local vres vhid
  vres="$("$CLI" get --name="$VS_NAME" --resolution 2>/dev/null)"
  vhid="$("$CLI" get --name="$VS_NAME" --hiDPI 2>/dev/null)"
  echo ">> desktop (virtual): $vres HiDPI=$vhid   physical: $(disp --resolution) @ $(disp --refreshRate)"
  if [ "$vres" = "$DEFAULT_HIDPI" ] && [ "$vhid" = "on" ]; then
    echo "[ok] Sharp $DEFAULT_HIDPI HiDPI @ 60Hz active. Virtual-screen mode — red/purple flicker, freezes, or panic on wake? run: $0 reset (or $0 fast)"
  else
    echo "[!] HiDPI mirror didn't come up cleanly — reverting."; cmd_reset
  fi
}

# Motion mode: native 5120x1440 LoDPI @ 120Hz (slightly soft text, rock solid).
cmd_fast() {
  setp --protectAll=off 2>/dev/null || true
  teardown_vs
  setp --main=on 2>/dev/null || true

  echo ">> fast: 5120x1440 @ 120Hz (LoDPI). The screen will blank/flicker briefly."
  # Colour depth is a connectionMode knob, NOT a display-mode attribute — don't force it here.
  setp --resolution=5120x1440 --hidpi=off --refreshrate=120Hz || true
  sleep 3
  local rr; rr="$(disp --refreshRate)"
  if [[ "$rr" != 120* && "$rr" != 119* ]]; then
    local m; m="$(disp --displayModeList | awk '/5120x1440 120Hz/{print $1; exit}')"
    [ -n "$m" ] && { echo ">> retry via display mode #$m"; setp --displayModeNumber="$m" || true; sleep 3; rr="$(disp --refreshRate)"; }
  fi
  if [[ "$rr" != 120* && "$rr" != 119* ]]; then
    echo ">> 10-bit 120Hz didn't hold ($rr); dropping to 8-bit and retrying"
    setp --connectionMode=bpc:8 2>/dev/null || true
    setp --resolution=5120x1440 --hidpi=off --refreshrate=120Hz || true; sleep 3; rr="$(disp --refreshRate)"
  fi
  case "$rr" in
    120*|119*)
      # Lock BOTH refresh and resolution — refresh-only protection lets the panel drift back down.
      setp --protectRefreshRate=on --protectResolution=on 2>/dev/null || true
      echo "[ok] now: $(disp --resolution) @ $(disp --refreshRate) ($(disp --colordepth)bpc); refresh+resolution protected. Text is non-Retina here (expected)." ;;
    *) echo "[!] Did not reach 120Hz (got $rr) — reverting to known-good."; cmd_reset ;;
  esac
}

# Clean-slate bail-out. Auto-detects cabling by counting connected panes and resets
# appropriately:
#   single-cable (1 pane) -> whole panel back to native 3840x1080 HiDPI @ 60Hz
#   dual-cable PBP (2 panes) -> clear overlays, leave both panes native (work/5120-capable
#                               pane to 5120x2160 HiDPI)
# Either way it drops all protections/mirrors/streams/PIPs and every virtual screen.
# EDID renames are left intact. Force a mode with: reset single | reset dual.
cmd_reset() {
  local mode="${1:-auto}" u uuids n first sel res hidpi
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
    echo ">> PBP clean slate: overlays cleared; panes native + normalized to RGB Full; renames kept."
    if [ "$n" -gt 0 ]; then
      printf '%s\n' "$uuids" | while IFS= read -r u; do
        [ -n "$u" ] || continue
        if "$CLI" get --UUID="$u" --displayModeList 2>/dev/null | grep -q '5120x2160'; then
          "$CLI" set --UUID="$u" --resolution=5120x2160 2>/dev/null || true
          "$CLI" set --UUID="$u" --hidpi=on 2>/dev/null || true
          sleep 1
        fi
        normalize_rgb_full "--UUID=$u"
        echo "   pane: $("$CLI" get --UUID="$u" --resolution 2>/dev/null) HiDPI=$("$CLI" get --UUID="$u" --hiDPI 2>/dev/null) | $("$CLI" get --UUID="$u" --connectionMode 2>/dev/null | grep -oE '[0-9]+bit .*SRGB' | sed 's/ SRGB//')"
      done
    fi
  fi
}

main() {
  require_cli
  case "${1:-check}" in
    check)  cmd_check ;;
    set)    cmd_set ;;
    fast)   cmd_fast ;;
    reset)  cmd_reset "${2:-auto}" ;;
    *) echo "usage: $0 {check|set|fast|reset [single|dual]}" >&2; exit 2 ;;
  esac
}
main "$@"
