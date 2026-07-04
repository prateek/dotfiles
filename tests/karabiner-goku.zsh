#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die()  { print -u2 -- "karabiner-goku: $*"; exit 1; }
skip() { print -- "SKIP karabiner-goku: $*"; exit 0; }

DOTFILES_ROOT="${0:A:h:h}"
src="$DOTFILES_ROOT/home/dot_config/karabiner.edn.tmpl"
[[ -f "$src" ]] || die "missing source: $src"

# Needs the goku toolchain and a karabiner.json with a "Default" profile (created by
# the apply step). Skips cleanly otherwise, mirroring tests/kanata-config.zsh.
command -v goku    >/dev/null 2>&1 || skip "goku not installed (brew install yqrashawn/goku/goku)"
command -v jq      >/dev/null 2>&1 || skip "jq not installed"
command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

kbjson="$HOME/.config/karabiner/karabiner.json"
[[ -f "$kbjson" ]] || skip "no karabiner.json yet (run: chezmoi apply)"
jq -e '.profiles[] | select(.name == "Default")' "$kbjson" >/dev/null 2>&1 \
  || skip "no \"Default\" profile in karabiner.json yet (run: chezmoi apply)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Render the committed EDN (resolves {{ .chezmoi.homeDir }}) and compile it. --dry-run-all
# writes the merged config to stdout only; it never mutates the live karabiner.json.
chezmoi execute-template -S "$DOTFILES_ROOT" < "$src" > "$work/karabiner.edn" \
  || die "chezmoi failed to render the EDN template"
GOKU_EDN_CONFIG_FILE="$work/karabiner.edn" goku --dry-run-all > "$work/out.json" 2>"$work/err" || true
jq -e . "$work/out.json" >/dev/null 2>&1 \
  || die "goku produced invalid JSON: $(cat "$work/err" 2>/dev/null)"

jq '[.profiles[] | select(.name == "Default").complex_modifications.rules[].manipulators[]]' \
  "$work/out.json" > "$work/manips.json"

count="$(jq 'length' "$work/manips.json")"
[[ "$count" == 33 ]] || die "expected 33 manipulators, got $count"

assert() { jq -e "$1" "$work/manips.json" >/dev/null || die "missing behavior: $2"; }

# Mouse-overlay rules are gated on variable_if pad_mouse_mode and scoped to the pad, and
# emitted before the base layer so they win by order while the toggle is on. Held rotated,
# the face diamond reads A=up, B=right, Y=down, X=left; the d-pad scrolls; bumpers click.
assert 'any(.[]; .from.key_code=="g" and .to[0].mouse_key.y==-1536
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode")
  and any(.conditions[]; .type=="device_if" and any(.identifiers[]; .vendor_id==11720 and .product_id==36888)))' \
  "mouse overlay: A moves cursor up (gated on pad_mouse_mode, pad-scoped)"
assert 'any(.[]; .from.key_code=="f" and .to[0].mouse_key.vertical_wheel==-40
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse overlay: d-pad up scrolls up (gated)"
assert 'any(.[]; .from.key_code=="c" and .to[0].mouse_key.horizontal_wheel==40
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse overlay: d-pad left scrolls left (gated)"
assert 'any(.[]; .from.key_code=="m" and .to[0].pointing_button=="button1"
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse overlay: R bumper = left click (gated)"
assert 'any(.[]; .from.key_code=="k" and .to[0].pointing_button=="button2"
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse overlay: L bumper = right click (gated)"

# The base layer is the unconditional default: device-scoped only, with NO variable gate
# (the overlay above shadows it when the toggle is on). Asserting the absence of a variable
# condition pins the default-plus-overlay structure. The bumpers/select are inert here.
assert 'any(.[]; .from.key_code=="f" and .to[0].key_code=="up_arrow"
  and any(.conditions[]; .type=="device_if" and any(.identifiers[]; .vendor_id==11720 and .product_id==36888))
  and (any(.conditions[]; .type | startswith("variable")) | not))' \
  "base layer: d-pad up = arrow (pad-scoped, no variable gate)"
assert 'any(.[]; .from.key_code=="i" and .to[0].key_code=="escape"
  and (any(.conditions[]; .type | startswith("variable")) | not))' \
  "base layer: Y = escape (no variable gate)"
assert 'any(.[]; .from.key_code=="m" and .to[0].key_code=="vk_none"
  and (any(.conditions[]; .type | startswith("variable")) | not))' \
  "base layer: R bumper inert (no scroll)"
assert 'any(.[]; .from.key_code=="n" and .to[0].key_code=="vk_none")' \
  "base layer: Select inert"

# Ordering is load-bearing: the mouse overlay must be emitted before the base layer so its
# gated rules win while the toggle is on. If a reorder shadowed the overlay (base's
# device-only f -> up_arrow ahead of the gated f -> scroll), the overlay would be dead.
assert '([.[] | (.from.key_code=="f" and .to[0].mouse_key.vertical_wheel==-40)] | index(true)) as $o
  | ([.[] | (.from.key_code=="f" and .to[0].key_code=="up_arrow")] | index(true)) as $b
  | ($o != null and $b != null and $o < $b)' \
  "ordering: mouse overlay precedes base layer (overlay wins by rule order)"

# Sticky toggle on Start: enter sets pad_mouse_mode=1 and shows the indicator; exit sets 0
# and clears it. Checking the set values + notification catches an inverted or silent toggle.
assert 'any(.[]; .from.key_code=="o" and any(.conditions[]; .type=="variable_unless" and .name=="pad_mouse_mode")
  and any(.to[]; .set_variable.name=="pad_mouse_mode" and .set_variable.value==1)
  and any(.to[]; .set_notification_message.id=="pad_mouse_mode" and .set_notification_message.text != ""))' \
  "Start enters mouse mode (set 1 + notification)"
assert 'any(.[]; .from.key_code=="o" and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode")
  and any(.to[]; .set_variable.name=="pad_mouse_mode" and .set_variable.value==0)
  and any(.to[]; .set_notification_message.id=="pad_mouse_mode" and .set_notification_message.text==""))' \
  "Start exits mouse mode (set 0 + clears notification)"

# Apple rules.
assert 'any(.[]; .from.key_code=="left_control" and .parameters."basic.to_if_alone_timeout_milliseconds"==200)' \
  "Apple Meh/F19 tap timeout preserved"
assert 'any(.[]; .from.key_code=="caps_lock" and .to_if_alone[0].key_code=="escape"
  and any(.conditions[]; .type=="device_if" and any(.identifiers[]; .is_built_in_keyboard==true)))' \
  "Apple caps_lock tap = escape, scoped to the built-in keyboard"

# Tap-⌘-for-Leader-Key: both command keys stay ⌘ when held (lazy) and emit F18 on a clean
# tap. Ungated, so no device/variable condition. F18 is Leader Key's activation hotkey.
assert 'any(.[]; .from.key_code=="left_command" and .to[0].key_code=="left_command"
  and .to[0].lazy==true and .to_if_alone[0].key_code=="f18"
  and .parameters."basic.to_if_alone_timeout_milliseconds"==200
  and (has("conditions") | not))' \
  "left ⌘: hold = ⌘ (lazy), tap = F18, ungated"
assert 'any(.[]; .from.key_code=="right_command" and .to[0].key_code=="right_command"
  and .to[0].lazy==true and .to_if_alone[0].key_code=="f18")' \
  "right ⌘: hold = ⌘ (lazy), tap = F18"

print -- "OK karabiner-goku"
