#!/usr/bin/env zsh
#
# Tests for scripts/packages/render-brewfile (the focused Brewfile
# renderer that wraps home/.chezmoitemplates/brewfile.tmpl).
#
set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "render-brewfile: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
RENDER="$DOTFILES_ROOT/scripts/packages/render-brewfile"

[[ -x $RENDER ]] || die "missing renderer: $RENDER"

# -- shape: required sections ------------------------------------------------

core_out="$("$RENDER" --profile core)"
[[ -n $core_out ]] || die "core profile rendered empty"
[[ $core_out == *'tap "1password/tap"'* ]] || die "core: missing 1password/tap"
[[ $core_out == *'brew "git"'* ]] || die "core: missing git brew"
[[ $core_out != *'brew "crit"'* ]] || die "core: crit should be managed by mise, not Homebrew"
[[ $core_out == *'cask "1password", args: { appdir: "/Applications" }'* ]] \
  || die "core: 1password cask appdir args missing or malformed"
rg -q '"go:github.com/tomasz-tomczyk/crit" = "latest"' "$DOTFILES_ROOT/home/dot_config/mise/conf.d/clis.toml" \
  || die "crit should be declared as a mise Go CLI"

# -- MAS opt-in gating -------------------------------------------------------

full_no_mas="$("$RENDER" --profile full)"
full_with_mas="$("$RENDER" --profile full --include-mas)"

if [[ $full_no_mas == *'mas "'* ]]; then
  die "full without --include-mas should not contain mas entries"
fi
[[ $full_with_mas == *'mas "Things", id: 904280696'* ]] \
  || die "full --include-mas: missing expected MAS entry"
[[ $full_no_mas == *'brew "aria2"'* ]] || die "full: missing aria2"
[[ $full_no_mas != *'brew "crit"'* ]] || die "full: crit should be managed by mise, not Homebrew"
[[ $full_no_mas != *'tap "xcodesorg/made"'* ]] || die "full: should not tap source-building xcodesorg/made"
[[ $full_no_mas == *'brew "homebrew/core/xcodes", args: ["force-bottle"]'* ]] \
  || die "full: missing bottled Homebrew core xcodes"
[[ $full_no_mas != *'facebook/fb/idb-companion'* ]] \
  || die "full Brewfile should not install idb-companion before Xcode setup"
[[ $full_no_mas != *'brew "swiftlint"'* ]] \
  || die "full Brewfile should not install swiftlint before Xcode setup"

# -- profile error reporting -------------------------------------------------

set +e
err_out="$("$RENDER" --profile bogus 2>&1)"
err_rc=$?
set -e
[[ $err_rc -ne 0 ]] || die "unknown profile should exit non-zero"
[[ $err_out == *"unknown package profile"* ]] \
  || die "unknown profile error message missing 'unknown package profile'"

# -- --output writes a file --------------------------------------------------

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
"$RENDER" --profile core --output "$tmp"
[[ -s $tmp ]] || die "--output produced empty file"
diff <("$RENDER" --profile core) "$tmp" >/dev/null \
  || die "--output content differs from stdout content"

# -- single trailing newline -------------------------------------------------

# Output must end with exactly one trailing newline. brew bundle parses
# either way, but stable shape keeps test diffs honest.
# Note: $(tail -c 1) strips trailing newlines via command substitution, so
# an empty result means the last byte WAS a newline.
[[ -z "$(tail -c 1 < "$tmp")" ]] || die "output does not end with a newline"

# -- section ordering: taps before brews before casks ------------------------

awk_check() {
  local section_first
  section_first="$(printf '%s\n' "$core_out" | awk '
    /^tap "/ { if (!seen) { seen="tap"; exit } }
    /^brew "/ { if (!seen) { seen="brew"; exit } }
    /^cask "/ { if (!seen) { seen="cask"; exit } }
    END { print seen }
  ')"
  [[ $section_first == "tap" ]] || die "first non-empty section should be tap, got: $section_first"
}
awk_check

print -- "OK render-brewfile"
