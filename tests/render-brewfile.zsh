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

# -- shape: required sections (ci = base-only minimal tier) ------------------

ci_out="$("$RENDER" --machine-type ci)"
[[ -n $ci_out ]] || die "ci machine type rendered empty"
[[ $ci_out == *'tap "1password/tap"'* ]] || die "ci: missing 1password/tap"
[[ $ci_out == *'brew "git"'* ]] || die "ci: missing git brew"
[[ $ci_out != *'brew "crit"'* ]] || die "ci: crit should be managed by mise, not Homebrew"
[[ $ci_out == *'cask "1password", args: { appdir: "/Applications" }'* ]] \
  || die "ci: 1password cask appdir args missing or malformed"
# ci is the lean base; it must not pull the dev toolchain or personal apps.
[[ $ci_out != *'brew "aria2"'* ]] || die "ci: should not include the dev group (aria2 leaked)"
[[ $ci_out != *'cask "tailscale-app"'* ]] || die "ci: should not include personal apps"
rg -q '"go:github.com/tomasz-tomczyk/crit" = "latest"' "$DOTFILES_ROOT/home/dot_config/mise/conf.d/clis.toml" \
  || die "crit should be declared as a mise Go CLI"

# -- dev machine types (personal): base + dev + dev-apple + personal-apps -----

personal_no_mas="$("$RENDER" --machine-type personal)"
personal_with_mas="$("$RENDER" --machine-type personal --include-mas)"

if [[ $personal_no_mas == *'mas "'* ]]; then
  die "personal without --include-mas should not contain mas entries"
fi
[[ $personal_with_mas == *'mas "Things", id: 904280696'* ]] \
  || die "personal --include-mas: missing expected MAS entry"
[[ $personal_no_mas == *'brew "aria2"'* ]] || die "personal: missing aria2 (dev group)"
[[ $personal_no_mas != *'brew "crit"'* ]] || die "personal: crit should be managed by mise, not Homebrew"
[[ $personal_no_mas != *'tap "xcodesorg/made"'* ]] || die "personal: should not tap source-building xcodesorg/made"
[[ $personal_no_mas == *'brew "homebrew/core/xcodes", args: ["force-bottle"]'* ]] \
  || die "personal: missing bottled Homebrew core xcodes (dev-apple group)"
[[ $personal_no_mas != *'facebook/fb/idb-companion'* ]] \
  || die "personal Brewfile should not install idb-companion before Xcode setup"
[[ $personal_no_mas != *'brew "swiftlint"'* ]] \
  || die "personal Brewfile should not install swiftlint before Xcode setup"

# -- personal apps are present on personal, absent on work --------------------

for app in tailscale-app arq voiceink; do
  [[ $personal_no_mas == *"cask \"$app\""* ]] || die "personal: missing personal app cask $app"
done
work_out="$("$RENDER" --machine-type work)"
[[ $work_out == *'brew "aria2"'* ]] || die "work: missing aria2 (work keeps the dev group)"
[[ $work_out == *'brew "homebrew/core/xcodes"'* ]] || die "work: missing xcodes (work keeps dev-apple)"
for app in tailscale-app arq voiceink; do
  [[ $work_out != *"cask \"$app\""* ]] || die "work should not install personal app cask $app"
done

# -- machine-type error reporting --------------------------------------------

set +e
err_out="$("$RENDER" --machine-type bogus 2>&1)"
err_rc=$?
set -e
[[ $err_rc -ne 0 ]] || die "unknown machine type should exit non-zero"
[[ $err_out == *"unknown machine type"* ]] \
  || die "unknown machine type error message missing 'unknown machine type'"

# -- --output writes a file --------------------------------------------------

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
"$RENDER" --machine-type ci --output "$tmp"
[[ -s $tmp ]] || die "--output produced empty file"
diff <("$RENDER" --machine-type ci) "$tmp" >/dev/null \
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
  section_first="$(printf '%s\n' "$ci_out" | awk '
    /^tap "/ { if (!seen) { seen="tap"; exit } }
    /^brew "/ { if (!seen) { seen="brew"; exit } }
    /^cask "/ { if (!seen) { seen="cask"; exit } }
    END { print seen }
  ')"
  [[ $section_first == "tap" ]] || die "first non-empty section should be tap, got: $section_first"
}
awk_check

print -- "OK render-brewfile"
