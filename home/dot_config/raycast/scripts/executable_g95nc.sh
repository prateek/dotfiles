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
# and a plain CLI tool: `g95nc {check|set|fast|reset}` (defaults to check).
#
# This panel renegotiates down to 60Hz on an HBR3 / DP 1.4 link and hides its
# higher modes. On this cable you can't have sharp + 120Hz at once, so:
#
#   set    -> sharp HiDPI @ 60Hz       full workspace; lands at 4352x1224 (85% of 1440p)
#             but the app-menu slider scales the whole HiDPI ladder (virtual-screen
#             mirror; needs the GUI "Enable resolutions over 8K" toggle). Daily driver.
#   fast   -> 5120x1440 LoDPI @ 120Hz  smooth motion, slightly soft text (native).
#   reset  -> 3840x1080 HiDPI @ 60Hz   native safe fallback / bail-out.
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

require_cli() {
  command -v "$CLI" >/dev/null 2>&1 || { echo "error: '$CLI' not found in PATH" >&2; exit 1; }
  disp --resolution >/dev/null || { echo "error: no display matching '$MATCH' (set G95_MATCH)" >&2; exit 1; }
}

cmd_check() {
  local res rr hidpi main cmode depth rrlist
  res="$(disp --resolution)"; rr="$(disp --refreshRate)"; hidpi="$(disp --hiDPI)"
  main="$(disp --main)"; cmode="$(disp --connectionMode)"; depth="$(disp --colordepth)"
  rrlist="$(disp --refreshRateList)"

  bar; echo "STEP 0 — current state & negotiation traps"; bar
  printf '  %-22s %s\n' "Resolution (logical)" "$res"
  printf '  %-22s %s\n' "Refresh (current)"    "$rr"
  printf '  %-22s %s\n' "HiDPI"                "$hidpi"
  printf '  %-22s %s\n' "Colour depth"         "$depth"
  printf '  %-22s %s\n' "Main display"         "$main"
  printf '  %-22s %s\n' "Connection mode"      "$cmode"
  echo "  Refresh rates exposed at THIS mode:"
  printf '%s\n' "$rrlist" | sed 's/^/      /'

  echo; echo "Trap checks:"
  case "$rr" in 60Hz|59*|60.0*) echo "  [!] Pinned at 60Hz." ;; *) echo "  [ok] Above 60Hz." ;; esac
  if printf '%s' "$cmode" | grep -q '10bit'; then
    echo "  [!] Link negotiated 10-bit colour — bandwidth-heavy; 8-bit frees headroom for higher Hz."
  fi
  if [ "$(printf '%s\n' "$rrlist" | grep -c Hz)" -le 1 ]; then
    echo "  [!] Only one refresh rate offered at this mode (the classic G95NC 60Hz lock)."
  fi

  echo; echo "High-refresh signal modes the link actually offers (no workaround needed):"
  disp --connectionModeListAll \
    | grep -E '11[0-9]\.|120\.|239\.' \
    | grep -Ei '5120x1440|3840x2160' \
    | sed 's/^/  /'
}

# Daily driver: sharp HiDPI @ 60Hz via a mirrored virtual screen. Lands at
# DEFAULT_HIDPI; the app-menu slider scales the rest of the ladder. True
# 5120x1440 HiDPI needs a 10240px framebuffer, which exceeds Apple Silicon's
# 7680px native cap — so it only exists on a virtual screen with over-8K enabled.
cmd_set() {
  echo ">> set: $DEFAULT_HIDPI HiDPI @ 60Hz (sharp) via virtual-screen mirror; slider scales from here."
  setp --protectAll=off 2>/dev/null || true   # let the mirror reconfigure the panel

  "$CLI" discard --nameLike="$VS_NAME" 2>/dev/null || true
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
  setp --protectAll=off 2>/dev/null || true              # drop any protections/mirror from `set`
  "$CLI" set --name="$VS_NAME" --mirror=off 2>/dev/null || true
  "$CLI" discard --nameLike="$VS_NAME" 2>/dev/null || true
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

# Safe fallback / bail-out: native 3840x1080 HiDPI @ 60Hz.
cmd_reset() {
  echo ">> reset: clear protections, stop mirror, discard virtual screen, restore 3840x1080 HiDPI @ 60Hz"
  setp --protectAll=off 2>/dev/null || true
  "$CLI" set --name="$VS_NAME" --mirror=off 2>/dev/null || true
  "$CLI" discard --nameLike="$VS_NAME" 2>/dev/null || true
  setp --main=on 2>/dev/null || true
  setp --reinitialize 2>/dev/null || true
  # colour depth is a connectionMode knob, NOT a display-mode attribute — forcing it here fails the match
  setp --resolution=3840x1080 --hidpi=on --refreshrate=60Hz || true
  sleep 2
  echo ">> now: $(disp --resolution) @ $(disp --refreshRate), HiDPI $(disp --hiDPI)"
}

main() {
  require_cli
  case "${1:-check}" in
    check)  cmd_check ;;
    set)    cmd_set ;;
    fast)   cmd_fast ;;
    reset)  cmd_reset ;;
    *) echo "usage: $0 {check|set|fast|reset}" >&2; exit 2 ;;
  esac
}
main "$@"
