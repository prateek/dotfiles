#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "chezmoi-local-ignores: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "expected output not to contain: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

home="$tmp_root/home"
mkdir -p \
  "$home/.config/chezmoi" \
  "$home/.config/cmux" \
  "$home/.config/op" \
  "$home/.gnupg" \
  "$home/.ssh"

touch \
  "$home/.zprofile.local" \
  "$home/.zshrc.local" \
  "$home/.config/chezmoi/chezmoi.toml" \
  "$home/.config/cmux/settings.json" \
  "$home/.config/op/config" \
  "$home/.gnupg/gpg.conf" \
  "$home/.ssh/config" \
  "$home/.local-unmanaged-marker"

unmanaged="$(
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data '{"manage_zinit_external":false}' \
    unmanaged \
    --path-style relative
)"

assert_not_contains "$unmanaged" ".zprofile.local"
assert_not_contains "$unmanaged" ".zshrc.local"
assert_not_contains "$unmanaged" ".config/chezmoi"
assert_not_contains "$unmanaged" ".config/cmux/settings.json"
assert_not_contains "$unmanaged" ".config/op"
assert_not_contains "$unmanaged" ".gnupg"
assert_not_contains "$unmanaged" ".ssh"
assert_contains "$unmanaged" ".local-unmanaged-marker"

print -- "OK chezmoi-local-ignores"
