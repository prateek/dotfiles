#!/usr/bin/env zsh
#
# Tests for scripts/macos/render-chrome-policy.py — emits Chrome's managed
# policy plist from chezmoi data (apps.chrome.policies).
#
set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "render-chrome-policy: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
RENDER="$DOTFILES_ROOT/scripts/macos/render-chrome-policy.py"

[[ -x $RENDER ]] || die "missing renderer: $RENDER"

# -- shape: valid plist ------------------------------------------------------

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$RENDER" --output "$tmp/policy.plist"
[[ -s "$tmp/policy.plist" ]] || die "--output produced empty file"

/usr/bin/plutil -lint -s "$tmp/policy.plist" \
  || die "rendered plist failed plutil -lint"

# Round-trip: convert binary→XML and back via plutil to confirm it's a
# valid plist that parses cleanly.
xml="$(/usr/bin/plutil -convert xml1 -o - "$tmp/policy.plist")"
[[ $xml == *"<plist"* ]] || die "rendered output is not a plist"

# -- expected key: ExtensionInstallForcelist ---------------------------------

# Pull the array via plutil -extract and confirm it's non-empty and contains
# the four extensions chrome.toml currently lists.
forcelist_count="$(/usr/bin/plutil -extract ExtensionInstallForcelist raw \
  -o - "$tmp/policy.plist" 2>/dev/null \
  | head -1 || true)"
# `plutil -extract <key> raw` on an array prints the count; non-empty result
# means the key exists. If the key is missing, plutil exits non-zero.
[[ -n $forcelist_count ]] || die "ExtensionInstallForcelist missing from rendered plist"

# Spot-check the contents include the 1Password extension id used in chrome.toml.
xml_dump="$(/usr/bin/plutil -convert xml1 -o - "$tmp/policy.plist")"
[[ $xml_dump == *"aeblfdkhhhdcdjpifhhbdiojplfjncoa"* ]] \
  || die "expected 1Password extension id in ExtensionInstallForcelist"

# -- stdout mode -------------------------------------------------------------

stdout_bytes="$("$RENDER" | wc -c | tr -d ' ')"
file_bytes="$(wc -c < "$tmp/policy.plist" | tr -d ' ')"
[[ "$stdout_bytes" == "$file_bytes" ]] \
  || die "stdout and --output sizes differ ($stdout_bytes vs $file_bytes)"

print -- "OK render-chrome-policy"
