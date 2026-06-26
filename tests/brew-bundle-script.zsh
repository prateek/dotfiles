#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "brew-bundle-script: $*"
  exit 1
}

assert_contains() {
  local got="$1"
  local want="$2"
  [[ "$got" == *"$want"* ]] || die "expected output to contain '$want'; got: $got"
}

assert_not_contains() {
  local got="$1"
  local unwanted="$2"
  [[ "$got" != *"$unwanted"* ]] || die "expected output not to contain '$unwanted'; got: $got"
}

assert_before() {
  local got="$1"
  local first="$2"
  local second="$3"
  local first_line second_line

  first_line="$(printf '%s\n' "$got" | awk -v p="$first" 'index($0, p) { print NR; exit }')"
  second_line="$(printf '%s\n' "$got" | awk -v p="$second" 'index($0, p) { print NR; exit }')"
  [[ -n "$first_line" ]] || die "expected output to contain '$first'; got: $got"
  [[ -n "$second_line" ]] || die "expected output to contain '$second'; got: $got"
  [[ "$first_line" -lt "$second_line" ]] ||
    die "expected '$first' before '$second'; got: $got"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

render_script() {
  local script="$1"
  local machine_type="${2:-ci}"
  env -u DOTFILES_MACHINE_TYPE chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"run_install_scripts\":true,\"apply_macos_defaults\":false,\"secrets_enabled\":false,\"machine_type\":\"$machine_type\"}" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl" \
    >"$script"
}

write_stubs() {
  local dir="$1"
  mkdir -p "$dir"

  cat >"$dir/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Linux\n'
EOF

  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "tap")
    if [ -n "${BREW_INSTALLED_TAPS:-}" ]; then
      printf '%s\n' "$BREW_INSTALLED_TAPS"
    else
      printf '1password/tap\nfelixkratz/formulae\nfluffypony/yojam\nyqrashawn/goku\n'
    fi
    ;;
  tap\ *)
    printf 'tap=%s\n' "$*" >> "$BREW_CALLS"
    ;;
  "update --quiet")
    printf 'update=%s\n' "$*" >> "$BREW_CALLS"
    ;;
  "bundle install --help")
    if [ "${BREW_SUPPORTS_JOBS:-1}" = "1" ]; then
      printf '      --jobs                       install runs up to this many formula installations in parallel.\n'
    else
      printf 'usage without jobs\n'
    fi
    ;;
  bundle\ install*)
    printf 'bundle_args=%s\n' "$*" >> "$BREW_CALLS"
    printf 'download_concurrency=%s\n' "${HOMEBREW_DOWNLOAD_CONCURRENCY:-}" >> "$BREW_CALLS"
    ;;
  *)
    printf 'unexpected brew call: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "$dir/uname" "$dir/brew"
}

script="$tmp_root/brew-bundle.sh"
render_script "$script"
bash -n "$script" || die "rendered brew bundle script has invalid syntax"
script_content="$(<"$script")"
assert_contains "$script_content" 'brew "felixkratz/formulae/borders", trusted: true'
assert_contains "$script_content" 'brew "yqrashawn/goku/goku", trusted: true'

# New Homebrew: use --jobs auto and default parallel downloads.
stubs_a="$tmp_root/stubs-a"
write_stubs "$stubs_a"
calls_a="$tmp_root/calls-a.log"
BREW_CALLS="$calls_a" PATH="$stubs_a:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-a" \
  bash "$script" >/dev/null
out_a="$(<"$calls_a")"
assert_contains "$out_a" "--jobs auto"
assert_contains "$out_a" "download_concurrency=auto"

# Dotfiles env overrides win over Homebrew defaults.
stubs_b="$tmp_root/stubs-b"
write_stubs "$stubs_b"
calls_b="$tmp_root/calls-b.log"
BREW_CALLS="$calls_b" PATH="$stubs_b:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-b" \
  DOTFILES_HOMEBREW_BUNDLE_JOBS=2 \
  DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY=3 \
  bash "$script" >/dev/null
out_b="$(<"$calls_b")"
assert_contains "$out_b" "--jobs 2"
assert_contains "$out_b" "download_concurrency=3"

# Older Homebrew: omit --jobs instead of failing.
stubs_c="$tmp_root/stubs-c"
write_stubs "$stubs_c"
calls_c="$tmp_root/calls-c.log"
BREW_CALLS="$calls_c" PATH="$stubs_c:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-c" \
  BREW_SUPPORTS_JOBS=0 \
  bash "$script" >/dev/null
out_c="$(<"$calls_c")"
assert_not_contains "$out_c" "--jobs"
assert_contains "$out_c" "download_concurrency=auto"

# Trust all declared non-official tap-qualified formulae/casks, but not
# Homebrew's official namespaced formulae.
script_personal="$tmp_root/brew-bundle-personal.sh"
render_script "$script_personal" personal
bash -n "$script_personal" || die "rendered personal brew bundle script has invalid syntax"
script_personal_content="$(<"$script_personal")"
assert_contains "$script_personal_content" 'brew "eugene1g/safehouse/agent-safehouse", trusted: true'
assert_contains "$script_personal_content" 'brew "prateek/tap/agentsview", trusted: true'
assert_contains "$script_personal_content" 'cask "dagger/tap/container-use", trusted: true'
assert_contains "$script_personal_content" 'cask "mattt/tap/imcp", trusted: true'
assert_contains "$script_personal_content" 'cask "nikitabobko/tap/aerospace", trusted: true'
assert_contains "$script_personal_content" 'cask "peripheryapp/periphery/periphery", trusted: true'
assert_contains "$script_personal_content" 'cask "prateek/tap/agentsview-desktop", trusted: true'
assert_contains "$script_personal_content" 'cask "stablyai/orca/orca", trusted: true'
assert_not_contains "$script_personal_content" 'brew "homebrew/core/xcodes", args: ["force-bottle"], trusted: true'
stubs_d="$tmp_root/stubs-d"
write_stubs "$stubs_d"
calls_d="$tmp_root/calls-d.log"
BREW_CALLS="$calls_d" PATH="$stubs_d:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-d" \
  bash "$script_personal" >/dev/null
out_d="$(<"$calls_d")"
assert_before "$out_d" "tap=tap eugene1g/safehouse" "bundle_args="
assert_before "$out_d" "tap=tap stablyai/orca" "bundle_args="

print -- "OK brew-bundle-script"
