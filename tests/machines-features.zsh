#!/usr/bin/env zsh
#
# Tests for the machines.toml layered resolver (home/.chezmoitemplates/features.tmpl):
# layer precedence, list replacement, machine_type resolution, machines_local
# overrides, and fail-on-unknown-type.
#
set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "machines-features: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
FEATURES="$DOTFILES_ROOT/home/.chezmoitemplates/features.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

[[ -f "$FEATURES" ]] || die "missing resolver: $FEATURES"

# Empty config so this host's ambient [data] (e.g. machine_type) does not leak;
# only --override-data and the source's .chezmoidata feed the resolver.
empty_config="$tmp_root/chezmoi.toml"
: >"$empty_config"

# Render features.tmpl with the given --override-data JSON; emits the feature JSON.
resolve() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --no-tty \
    --override-data "$1" \
    execute-template --file "$FEATURES"
}

# assert_json <override> <python-expr-using-f> [label]
# f is the parsed feature dict; the expression must evaluate truthy.
assert_json() {
  local override="$1" expr="$2" label="${3:-$2}"
  local js
  js="$(resolve "$override")"
  FEATURES_JSON="$js" python3 -c '
import json, os, sys
f = json.loads(os.environ["FEATURES_JSON"])
expr, label = sys.argv[1], sys.argv[2]
if not eval(expr, {"f": f}):
    sys.stderr.write(f"machines-features: assertion failed: {label}\n  features={json.dumps(f)}\n")
    sys.exit(1)
' "$expr" "$label" || exit 1
}

# --- per-type composition matches the retired packages.machine_types ----------
assert_json '{"machine_type":"ci"}' \
  'f["groups"]==["core"] and f["run_install_scripts"] is True and f["apply_macos_defaults"] is True and f["secrets_enabled"] is False and f["private_overlay"] is False and f["elevation"]=="none" and f["machine_type"]=="ci"' \
  "ci composition"

assert_json '{"machine_type":"personal"}' \
  'f["groups"]==["core","mac-desktop","developer-tools","apple-development","personal-apps"] and f["run_install_scripts"] is True and f["apply_macos_defaults"] is True and f["secrets_enabled"] is False and f["elevation"]=="none" and f["private_overlay"] is False' \
  "personal composition"

assert_json '{"machine_type":"homelab"}' \
  'f["groups"]==["core","developer-tools","apple-development","homelab-admin"]' \
  "homelab composition"

assert_json '{"machine_type":"work"}' \
  'f["groups"]==["core","mac-desktop","developer-tools","work-apps"] and f["private_overlay"] is True and f["elevation"]=="jamf-self-service"' \
  "work composition"

# --- machine_type default: absent resolves to personal ------------------------
assert_json '{}' 'f["machine_type"]=="personal"' "absent machine_type -> personal"

# --- machines_local is the highest layer (overrides type + defaults) ----------
assert_json '{"machine_type":"personal","machines_local":{"secrets_enabled":true}}' \
  'f["secrets_enabled"] is True' "machines_local enables secrets"
assert_json '{"machine_type":"work","machines_local":{"elevation":"none"}}' \
  'f["elevation"]=="none"' "machines_local overrides work elevation"

# --- a list is replaced wholesale by the highest layer that sets it -----------
assert_json '{"machine_type":"work","machines_local":{"groups":["core"]}}' \
  'f["groups"]==["core"]' "machines_local replaces groups (no concat)"

# --- os layer composes for a matching .chezmoi.os (darwin on this host) -------
assert_json '{"machine_type":"personal","machines":{"os":{"darwin":{"apply_macos_defaults":false}}}}' \
  'f["apply_macos_defaults"] is False and f["run_install_scripts"] is True' \
  "os.darwin layer composes above defaults, below machines_local"

# --- unknown machine_type fails loud (the typo guard) -------------------------
set +e
bogus="$(resolve '{"machine_type":"nope"}' 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || die "unknown machine type should fail the resolver"
[[ $bogus == *"unknown machine type"* ]] || die "expected 'unknown machine type' error, got: $bogus"

print -- "OK machines-features"
