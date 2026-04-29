#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "settings-coverage: $*"
  exit 1
}

assert_configured() {
  local output="$1"
  local cask="$2"
  local want="$3"
  local got

  got="$(print -r -- "$output" | awk -F '\t' -v cask="$cask" '$1 == cask { print $2 }')"
  [[ "$got" == "$want" ]] || die "expected $cask configured=$want, got ${got:-missing}"
}

DOTFILES_ROOT="${0:A:h:h}"
output="$(
  bash "$DOTFILES_ROOT/scripts/audit/settings-coverage.sh" \
    alfred \
    bettertouchtool \
    google-chrome \
    iterm2 \
    obsidian \
    tuist \
    zed
)"

assert_configured "$output" "alfred" "no"
assert_configured "$output" "bettertouchtool" "no"
assert_configured "$output" "google-chrome" "yes"
assert_configured "$output" "iterm2" "no"
assert_configured "$output" "obsidian" "no"
assert_configured "$output" "tuist" "no"
assert_configured "$output" "zed" "no"

full_output="$(bash "$DOTFILES_ROOT/scripts/audit/settings-coverage.sh")"
unexpected="$(print -r -- "$full_output" | awk -F '\t' '$2 == "yes" && $1 == "cleanshot" { print $1 }')"
[[ -z "$unexpected" ]] || die "unexpected config for non-installed cask: ${unexpected//$'\n'/, }"

app_indexes="$(find "$DOTFILES_ROOT/home/.chezmoidata/apps" -maxdepth 1 -type f -name '*.toml' | sed 's#.*/##; s#\.toml$##' | LC_ALL=C sort)"
expected_app_indexes="$(
  cat <<'EOF'
chrome
EOF
)"
[[ "$app_indexes" == "$expected_app_indexes" ]] || die "unexpected app index set:
$app_indexes"

print -- "OK settings-coverage"
