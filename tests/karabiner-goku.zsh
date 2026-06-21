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
[[ "$count" == 25 ]] || die "expected 25 manipulators, got $count"

assert() { jq -e "$1" "$work/manips.json" >/dev/null || die "missing behavior: $2"; }

# Mouse-mode rules are gated on variable_if pad_mouse_mode and scoped to the pad.
# Gating on the condition (not just the key) is what makes a normal/mouse mode swap fail
# here, since the same physical keys exist in both modes.
assert 'any(.[]; .from.key_code=="f" and .to[0].mouse_key.y==-1536
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode")
  and any(.conditions[]; .type=="device_if" and any(.identifiers[]; .vendor_id==11720 and .product_id==36888)))' \
  "mouse mode: d-pad up moves cursor (gated on pad_mouse_mode, pad-scoped)"
assert 'any(.[]; .from.key_code=="g" and .to[0].pointing_button=="button1"
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse mode: A = left click (gated)"
assert 'any(.[]; .from.key_code=="j" and .to[0].pointing_button=="button2"
  and any(.conditions[]; .type=="variable_if" and .name=="pad_mouse_mode"))' \
  "mouse mode: B = right click (gated)"

# The same physical keys map differently when mouse mode is OFF (variable_unless).
assert 'any(.[]; .from.key_code=="f" and .to[0].key_code=="up_arrow"
  and any(.conditions[]; .type=="variable_unless" and .name=="pad_mouse_mode"))' \
  "normal mode: d-pad up = arrow (gated)"
assert 'any(.[]; .from.key_code=="i" and .to[0].key_code=="escape"
  and any(.conditions[]; .type=="variable_unless" and .name=="pad_mouse_mode"))' \
  "normal mode: Y = escape (gated)"

# Sticky toggle on Start: enter sets pad_mouse_mode=1 + shows the indicator; exit sets 0.
# Checking the set values catches an inverted toggle.
assert 'any(.[]; .from.key_code=="o" and any(.conditions[]; .type=="variable_unless")
  and any(.to[]; .set_variable.name=="pad_mouse_mode" and .set_variable.value==1)
  and any(.to[]; .set_notification_message != null and .set_notification_message.text != ""))' \
  "Start enters mouse mode (set 1 + indicator)"
assert 'any(.[]; .from.key_code=="o" and any(.conditions[]; .type=="variable_if")
  and any(.to[]; .set_variable.name=="pad_mouse_mode" and .set_variable.value==0))' \
  "Start exits mouse mode (set 0)"

# Always-on + Apple rules.
assert 'any(.[]; .from.key_code=="k" and .to[0].mouse_key.vertical_wheel==40)' \
  "L bumper scrolls"
assert 'any(.[]; .from.key_code=="left_control" and .parameters."basic.to_if_alone_timeout_milliseconds"==200)' \
  "Apple Meh/F19 tap timeout preserved"
assert 'any(.[]; .from.key_code=="caps_lock" and .to_if_alone[0].key_code=="escape"
  and any(.conditions[]; .type=="device_if" and any(.identifiers[]; .is_built_in_keyboard==true)))' \
  "Apple caps_lock tap = escape, scoped to the built-in keyboard"

print -- "OK karabiner-goku"
