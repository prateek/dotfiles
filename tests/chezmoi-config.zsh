#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "chezmoi-config: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "missing expected text: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

tmp_config="$tmp_home/.config/chezmoi/chezmoi.toml"
tmp_cache="$tmp_home/.cache/chezmoi"
tmp_state="$tmp_home/.local/state/chezmoi/state.boltdb"
mkdir -p "$tmp_home/.config/chezmoi" "$tmp_cache" "${tmp_state:h}"

DOTFILES_MACHINE_TYPE=ci \
DOTFILES_RUN_INSTALL_SCRIPTS=false \
DOTFILES_APPLY_DEFAULTS=false \
DOTFILES_SECRETS_ENABLED=false \
HOME="$tmp_home" \
XDG_CONFIG_HOME="$tmp_home/.config" \
XDG_CACHE_HOME="$tmp_home/.cache" \
XDG_STATE_HOME="$tmp_home/.local/state" \
  chezmoi --no-tty \
    --config "$tmp_config" \
    --cache "$tmp_cache" \
    --persistent-state "$tmp_state" \
    init --promptDefaults --source "$DOTFILES_ROOT"

config_text="$(<"$tmp_config")"
assert_contains "$config_text" 'pager = ""'
# DOTFILES_MACHINE_TYPE=ci above must persist as the single package-selection axis;
# the retired install_profile must not reappear in the rendered config.
assert_contains "$config_text" 'machine_type = "ci"'
[[ "$config_text" != *install_profile* ]] || die "install_profile should no longer be persisted to chezmoi.toml"

dump="$(
  chezmoi \
    --config "$tmp_config" \
    --cache "$tmp_cache" \
    --persistent-state "$tmp_state" \
    dump-config
)"
assert_contains "$dump" '"pager": ""'
assert_contains "$dump" '"machine_type": "ci"'

print -- "OK chezmoi-config"
