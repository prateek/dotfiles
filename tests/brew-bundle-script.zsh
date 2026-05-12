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

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

render_script() {
  local script="$1"
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data '{"run_install_scripts":true,"apply_macos_defaults":false,"secrets_enabled":false,"install_profile":"core","manage_zinit_external":false}' \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl" \
    >"$script"
}

write_stubs() {
  local dir="$1"
  mkdir -p "$dir"

  cat >"$dir/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${BREW_STUB_UNAME:-Linux}"
EOF

  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  bundle\ check*)
    printf 'check_args=%s\n' "$*" >> "$BREW_CALLS"
    printf 'check_no_auto_update=%s\n' "${HOMEBREW_NO_AUTO_UPDATE:-}" >> "$BREW_CALLS"
    [ "${BREW_BUNDLE_SATISFIED:-0}" = "1" ]
    ;;
  "update --quiet")
    printf 'update=%s\n' "$*" >> "$BREW_CALLS"
    ;;
  "tap")
    printf '1password/tap\nfelixkratz/formulae\n'
    ;;
  "bundle install --help")
    if [ "${BREW_SUPPORTS_JOBS:-1}" = "1" ]; then
      printf '      --jobs                       install runs up to this many formula installations in parallel.\n'
    else
      printf 'usage without jobs\n'
    fi
    ;;
  bundle\ install*)
    printf 'args=%s\n' "$*" >> "$BREW_CALLS"
    printf 'download_concurrency=%s\n' "${HOMEBREW_DOWNLOAD_CONCURRENCY:-}" >> "$BREW_CALLS"
    ;;
  *)
    printf 'unexpected brew call: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

  cat >"$dir/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo=%s\n' "$*" >> "$BREW_CALLS"
exit 1
EOF

  chmod +x "$dir/uname" "$dir/brew" "$dir/sudo"
}

script="$tmp_root/brew-bundle.sh"
render_script "$script"
bash -n "$script" || die "rendered brew bundle script has invalid syntax"

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

# Already-satisfied Brewfiles should not run install at all.
stubs_d="$tmp_root/stubs-d"
write_stubs "$stubs_d"
calls_d="$tmp_root/calls-d.log"
BREW_CALLS="$calls_d" PATH="$stubs_d:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-d" \
  BREW_BUNDLE_SATISFIED=1 \
  bash "$script" >/dev/null
out_d="$(<"$calls_d")"
assert_contains "$out_d" "check_args=bundle check --no-upgrade --verbose --file"
assert_contains "$out_d" "check_no_auto_update=1"
assert_not_contains "$out_d" "args=bundle install"
assert_not_contains "$out_d" "--jobs"

# Darwin cask installs are owned by Homebrew; the dotfiles wrapper must not
# pre-warm sudo before invoking brew because brew resets the sudo timestamp.
stubs_e="$tmp_root/stubs-e"
write_stubs "$stubs_e"
calls_e="$tmp_root/calls-e.log"
BREW_CALLS="$calls_e" PATH="$stubs_e:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$tmp_root/home-e" \
  BREW_STUB_UNAME=Darwin \
  bash "$script" >/dev/null
out_e="$(<"$calls_e")"
assert_contains "$out_e" "args=bundle install"
assert_not_contains "$out_e" "sudo="

print -- "OK brew-bundle-script"
