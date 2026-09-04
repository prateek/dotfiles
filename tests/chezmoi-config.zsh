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

HOME="$tmp_home" \
XDG_CONFIG_HOME="$tmp_home/.config" \
XDG_CACHE_HOME="$tmp_home/.cache" \
XDG_STATE_HOME="$tmp_home/.local/state" \
  chezmoi --no-tty \
    --config "$tmp_config" \
    --cache "$tmp_cache" \
    --persistent-state "$tmp_state" \
    init --promptDefaults --promptChoice 'machine_type=ci' --source "$DOTFILES_ROOT"

config_text="$(<"$tmp_config")"
assert_contains "$config_text" 'pager = ""'
# --promptChoice 'machine_type=ci' above must persist as the single identity axis;
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

# Re-init migration: a config that still nests jamf_policy_id under the legacy
# [data.elevation] must have that value carried up to the top-level [data] key on
# re-init (work), not dropped. Guards the `or (dig ...) (dig "elevation" ...)`
# reuse in .chezmoi.toml.tmpl.
legacy_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$legacy_home"' EXIT
legacy_config="$legacy_home/.config/chezmoi/chezmoi.toml"
mkdir -p "$legacy_home/.config/chezmoi" "$legacy_home/.cache/chezmoi" "${legacy_home}/.local/state/chezmoi"
cat >"$legacy_config" <<'EOF'
[data]
machine_type = "work"

[data.elevation]
jamf_policy_id = "LEGACY777"
EOF

HOME="$legacy_home" \
XDG_CONFIG_HOME="$legacy_home/.config" \
XDG_CACHE_HOME="$legacy_home/.cache" \
XDG_STATE_HOME="$legacy_home/.local/state" \
  chezmoi --no-tty \
    --config "$legacy_config" \
    --cache "$legacy_home/.cache/chezmoi" \
    --persistent-state "$legacy_home/.local/state/chezmoi/state.boltdb" \
    init --promptDefaults --source "$DOTFILES_ROOT"

legacy_text="$(<"$legacy_config")"
assert_contains "$legacy_text" 'machine_type = "work"'
assert_contains "$legacy_text" 'jamf_policy_id = "LEGACY777"'

print -- "OK chezmoi-config"
