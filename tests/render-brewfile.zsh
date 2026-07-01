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

# -- shape: required sections (ci = core-only minimal tier) --------------

ci_out="$("$RENDER" --machine-type ci)"
[[ -n $ci_out ]] || die "ci machine type rendered empty"
[[ $ci_out == *'tap "1password/tap"'* ]] || die "ci: missing 1password/tap"
[[ $ci_out == *'brew "git"'* ]] || die "ci: missing git brew"
[[ $ci_out != *'brew "crit"'* ]] || die "ci: crit should be managed by mise, not Homebrew"
[[ $ci_out == *'cask "1password-cli"'* ]] || die "ci: missing 1password CLI cask"
# ci is the core layer; it must not pull GUI, dev, Apple, or overlay groups.
[[ $ci_out != *'cask "1password", args: { appdir: "/Applications" }'* ]] \
  || die "ci: should not include the interactive 1Password app"
[[ $ci_out != *'brew "aria2"'* ]] || die "ci: should not include developer-tools (aria2 leaked)"
[[ $ci_out != *'cask "tailscale-app"'* ]] || die "ci: should not include homelab overlay apps"
rg -q '"go:github.com/tomasz-tomczyk/crit" = "latest"' "$DOTFILES_ROOT/home/dot_config/mise/conf.d/clis.toml" \
  || die "crit should be declared as a mise Go CLI"

# -- personal machine type: core + interactive + dev + Apple + personal --

personal_no_mas="$("$RENDER" --machine-type personal)"
personal_with_mas="$("$RENDER" --machine-type personal --include-mas)"

if [[ $personal_no_mas == *'mas "'* ]]; then
  die "personal without --include-mas should not contain mas entries"
fi
[[ $personal_with_mas == *'mas "Things", id: 904280696'* ]] \
  || die "personal --include-mas: missing expected MAS entry"
[[ $personal_with_mas == *'mas "Okta Verify", id: 490179405'* ]] \
  || die "personal --include-mas: missing shared Okta Verify MAS entry"
[[ $personal_no_mas == *'brew "aria2"'* ]] || die "personal: missing aria2 (developer-tools group)"
[[ $personal_no_mas != *'brew "crit"'* ]] || die "personal: crit should be managed by mise, not Homebrew"
[[ $personal_no_mas != *'tap "xcodesorg/made"'* ]] || die "personal: should not tap source-building xcodesorg/made"
[[ $personal_no_mas == *'brew "homebrew/core/xcodes", args: ["force-bottle"]'* ]] \
  || die "personal: missing bottled Homebrew core xcodes (apple-development group)"
[[ $personal_no_mas == *'brew "cirruslabs/cli/tart", trusted: true'* ]] \
  || die "personal: missing Tart VM CLI (apple-development group)"
[[ $personal_no_mas == *'brew "f/mcptools/mcp", trusted: true'* ]] \
  || die "personal: missing MCP CLI (developer-tools group)"
[[ $personal_no_mas != *'facebook/fb/idb-companion'* ]] \
  || die "personal Brewfile should not install idb-companion before Xcode setup"
[[ $personal_no_mas != *'brew "swiftlint"'* ]] \
  || die "personal Brewfile should not install swiftlint before Xcode setup"

# -- overlays are scoped by role ---------------------------------------------

for app in arq voiceink; do
  [[ $personal_no_mas == *"cask \"$app\""* ]] || die "personal: missing personal app cask $app"
done
[[ $personal_no_mas == *'cask "google-drive"'* ]] || die "personal: missing shared laptop cask google-drive"
[[ $personal_no_mas == *'cask "jump-desktop"'* ]] || die "personal: missing Jump Desktop viewer"
[[ $personal_no_mas != *'cask "tailscale-app"'* ]] || die "personal: should not install homelab remote app tailscale-app"
work_out="$("$RENDER" --machine-type work)"
work_with_mas="$("$RENDER" --machine-type work --include-mas)"
[[ $work_out == *'brew "aria2"'* ]] || die "work: missing aria2 (work keeps developer-tools)"
[[ $work_out != *'brew "homebrew/core/xcodes"'* ]] || die "work should not include xcodes (no apple-development group)"
[[ $work_out != *'brew "fastlane"'* ]] || die "work should not include the Apple development toolchain (fastlane leaked)"
[[ $work_out != *'brew "cirruslabs/cli/tart"'* ]] || die "work should not include Tart (no apple-development group)"
[[ $work_out == *'brew "f/mcptools/mcp", trusted: true'* ]] || die "work: missing MCP CLI (developer-tools group)"
[[ $work_out == *'cask "slack"'* ]] || die "work: missing work overlay cask slack"
[[ $work_out == *'cask "google-drive"'* ]] || die "work: missing shared laptop cask google-drive"
[[ $work_with_mas == *'mas "Okta Verify", id: 490179405'* ]] \
  || die "work --include-mas: missing shared Okta Verify MAS entry"
for app in tailscale-app arq voiceink; do
  [[ $work_out != *"cask \"$app\""* ]] || die "work should not install non-work overlay cask $app"
done
homelab_out="$("$RENDER" --machine-type homelab)"
[[ $homelab_out == *'brew "homebrew/core/xcodes", args: ["force-bottle"]'* ]] \
  || die "homelab: missing Apple development xcodes"
[[ $homelab_out == *'brew "cirruslabs/cli/tart", trusted: true'* ]] \
  || die "homelab: missing Tart VM CLI"
[[ $homelab_out == *'brew "f/mcptools/mcp", trusted: true'* ]] \
  || die "homelab: missing MCP CLI"
[[ $homelab_out != *'brew "mas"'* ]] || die "homelab: should not include MAS CLI without Mac desktop/MAS apps"
[[ $homelab_out == *'cask "tailscale-app"'* ]] || die "homelab: missing homelab remote cask tailscale-app"
[[ $homelab_out == *'cask "jump-desktop"'* ]] || die "homelab: missing Jump Desktop viewer"
[[ $homelab_out != *'cask "setapp"'* ]] || die "homelab: should not include personal GUI/licensed app setapp"
[[ $homelab_out != *'cask "ghostty"'* ]] || die "homelab: should not include interactive desktop cask ghostty"
[[ $homelab_out != *'cask "google-drive"'* ]] || die "homelab: should not include shared interactive cask google-drive"

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
