#!/usr/bin/env zsh
#
# Tests home/dot_config/dotfiles/elevation.sh.tmpl: the elevation method resolves
# from machines.toml (features.tmpl), jamf_policy_id reads [data] with a fallback
# to the legacy nested [data.elevation].jamf_policy_id, and an absent policy id
# renders as an empty default — never the literal "<no value>".
#
set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "elevation-render: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
TMPL="$DOTFILES_ROOT/home/dot_config/dotfiles/elevation.sh.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

[[ -f "$TMPL" ]] || die "missing template: $TMPL"

# Empty --config isolates from this host's chezmoi config (which may carry a real
# jamf_policy_id); only --override-data and the source's .chezmoidata feed it.
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

render() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --no-tty \
    --override-data "$1" \
    execute-template --file "$TMPL"
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || die "expected output to contain: $2"$'\n'"got: $1"
}
assert_absent() {
  [[ "$1" != *"$2"* ]] || die "expected output NOT to contain: $2"$'\n'"got: $1"
}

# work, no policy id set: method resolves to jamf-self-service, policy id is an
# EMPTY default (regression guard: must not be the literal "<no value>").
out="$(render '{"machine_type":"work"}')"
assert_contains "$out" 'DOTFILES_ELEVATION_METHOD:=jamf-self-service}'
assert_contains "$out" 'DOTFILES_JAMF_POLICY_ID:=}'
assert_absent "$out" '<no value>'

# work, top-level identity policy id.
out="$(render '{"machine_type":"work","jamf_policy_id":"TOP123"}')"
assert_contains "$out" 'DOTFILES_JAMF_POLICY_ID:=TOP123}'

# work, legacy nested policy id (an already-inited machine not yet re-inited).
out="$(render '{"machine_type":"work","elevation":{"jamf_policy_id":"NEST456"}}')"
assert_contains "$out" 'DOTFILES_JAMF_POLICY_ID:=NEST456}'

# non-work: method resolves to none, still no "<no value>".
out="$(render '{"machine_type":"personal"}')"
assert_contains "$out" 'DOTFILES_ELEVATION_METHOD:=none}'
assert_absent "$out" '<no value>'

print -- "OK elevation-render"
