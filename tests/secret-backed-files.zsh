#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "secret-backed-files: $*"
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

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export OP_CALLS="$tmp_root/op-calls.log"

cat >"$stub_bin/op" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$OP_CALLS"

if [ "$1" = "signin" ] && [ "${2:-}" = "--raw" ]; then
  printf 'test-session'
  exit 0
fi

if [ "$1" = "--session" ] && [ "${3:-}" = "read" ]; then
  printf 'stub-license-value'
  exit 0
fi

printf 'unexpected op invocation: %s\n' "$*" >&2
exit 2
EOF
chmod +x "$stub_bin/op"

override='{
  "manage_zinit_external": false,
  "secrets": {
    "refs": {
      "example_license": "op://vault-id/item-id/field-id"
    }
  },
  "licenses": {
    "paths": [
      "Library/Application Support/Example App/license.key"
    ]
  }
}'

chezmoi_isolated() {
  PATH="$stub_bin:$PATH" \
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    "$@"
}

disabled_ignore_template="$(
  chezmoi_isolated \
    --override-data "$override" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiignore"
)"
assert_contains "$disabled_ignore_template" "Library/Application Support/Example App/license.key"

disabled_render="$(
  chezmoi_isolated \
    --override-data "$override" \
    execute-template \
    --file "$DOTFILES_ROOT/tests/fixtures/secret-backed-license.tmpl"
)"
[[ -z "$disabled_render" ]] || die "expected disabled secret template to render empty output"
[[ ! -e "$OP_CALLS" ]] || die "expected disabled secret template not to call op"

enabled_override='{
  "manage_zinit_external": false,
  "secrets_enabled": true,
  "secrets": {
    "refs": {
      "example_license": "op://vault-id/item-id/field-id"
    }
  },
  "licenses": {
    "paths": [
      "Library/Application Support/Example App/license.key"
    ]
  }
}'

enabled_ignore_template="$(
  chezmoi_isolated \
    --override-data "$enabled_override" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiignore"
)"
assert_not_contains "$enabled_ignore_template" "Library/Application Support/Example App/license.key"

enabled_render="$(
  chezmoi_isolated \
    --override-data "$enabled_override" \
    execute-template \
    --file "$DOTFILES_ROOT/tests/fixtures/secret-backed-license.tmpl"
)"
[[ "$enabled_render" = "stub-license-value" ]] || die "unexpected enabled render output"

op_calls="$(<"$OP_CALLS")"
assert_contains "$op_calls" "signin --raw"
assert_contains "$op_calls" "--session test-session read --no-newline op://vault-id/item-id/field-id"

>"$OP_CALLS"
local_config="$tmp_root/chezmoi.toml"
cat >"$local_config" <<EOF
sourceDir = "$DOTFILES_ROOT"

[data]
secrets_enabled = true
manage_zinit_external = false

[data.secrets.refs]
example_license = "op://vault-id/item-id/field-id"
EOF

config_render="$(
  PATH="$stub_bin:$PATH" \
  chezmoi \
    --config "$local_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/config-state.boltdb" \
    execute-template \
    --file "$DOTFILES_ROOT/tests/fixtures/secret-backed-license.tmpl"
)"
[[ "$config_render" = "stub-license-value" ]] || die "local config [data.secrets.refs] did not render"

config_op_calls="$(<"$OP_CALLS")"
assert_contains "$config_op_calls" "--session test-session read --no-newline op://vault-id/item-id/field-id"

print -- "OK secret-backed-files"
