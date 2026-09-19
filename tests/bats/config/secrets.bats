load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  data='{"secrets":{"refs":{"example_license":"op://vault-id/item-id/field-id"}},"licenses":{"paths":{"example_license":"Library/Application Support/Example App/license.key"}}}'
  cat > "$FIXTURE/bin/op" <<'STUB'
#!/bin/sh
set -eu
printf '%s token=%s\n' "$*" "${OP_SERVICE_ACCOUNT_TOKEN:-}" >> "$FIXTURE/op.calls"
case "$*" in
  'read --no-newline op://vault-id/item-id/field-id') printf stub-license-value ;;
  *) printf 'unexpected op invocation: %s\n' "$*" >&2; exit 2 ;;
esac
STUB
  cat > "$FIXTURE/bin/security" <<'STUB'
#!/bin/sh
case "$*" in
  'find-generic-password -s op-devland-sa -w')
    if [ -e "$FIXTURE/keychain-token" ]; then
      cat "$FIXTURE/keychain-token"
      exit 0
    fi ;;
esac
echo 'security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.' >&2
exit 44
STUB
  chmod +x "$FIXTURE/bin/op" "$FIXTURE/bin/security"
}

# Render the config a machine gets from `chezmoi init`, add the local opt-in and
# ref, then render a secret-backed template against it.
render_license_on_opted_in_machine() {
  printf '[data]\nmachine_type = "personal"\n' > "$FIXTURE/chezmoi.toml"
  local chezmoi=(chezmoi --source "$DOTFILES_ROOT" --config "$FIXTURE/chezmoi.toml"
    --destination "$HOME" --cache "$XDG_CACHE_HOME" --persistent-state "$FIXTURE/state.boltdb" --no-tty)
  run_without_reporting_fds 0 "${chezmoi[@]}" init --promptDefaults
  cat >> "$FIXTURE/chezmoi.toml" <<'CONFIG'
[data.machines_local]
secrets_enabled = true
[data.secrets.refs]
example_license = "op://vault-id/item-id/field-id"
CONFIG
  run_without_reporting_fds "$1" "${chezmoi[@]}" \
    execute-template --file "$DOTFILES_ROOT/tests/fixtures/secret-backed-license.tmpl"
}

@test "Disabled secret-backed files remain ignored and render empty without contacting 1Password" {
  run -0 --separate-stderr render_template home/.chezmoiignore personal "$data"
  assert_success
  [ -z "$stderr" ]
  assert_output --partial 'Library/Application Support/Example App/license.key'
  run -0 --separate-stderr render_template tests/fixtures/secret-backed-license.tmpl personal "$data"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -e "$FIXTURE/op.calls" ]
}

@test "Enabled secret-backed files leave the ignore list" {
  data="$("$TEST_PYTHON" -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1]) | {"machines_local":{"secrets_enabled":True}}))' "$data")"
  run -0 --separate-stderr render_template home/.chezmoiignore personal "$data"
  assert_success
  [ -z "$stderr" ]
  refute_output --partial 'Library/Application Support/Example App/license.key'
}

@test "Enabled secrets keep a license without a reference ignored so apply cannot delete a hand-installed file" {
  data="$("$TEST_PYTHON" -c 'import json,sys; d=json.loads(sys.argv[1]); d["secrets"]["refs"]["example_license"]=""; print(json.dumps(d | {"machines_local":{"secrets_enabled":True}}))' "$data")"
  run -0 --separate-stderr render_template home/.chezmoiignore personal "$data"
  assert_success
  [ -z "$stderr" ]
  assert_output --partial 'Library/Application Support/Example App/license.key'
  run -0 --separate-stderr render_template tests/fixtures/secret-backed-license.tmpl personal "$data"
  assert_success
  assert_output ''
  [ ! -e "$FIXTURE/op.calls" ]
}

@test "Enabled secret-backed files read as the keychain's 1Password service account without signing in" {
  printf 'ops_test-token\n' > "$FIXTURE/keychain-token"
  render_license_on_opted_in_machine 0
  assert_output stub-license-value
  [ -z "$stderr" ]
  [ "$(cat "$FIXTURE/op.calls")" = 'read --no-newline op://vault-id/item-id/field-id token=ops_test-token' ]
}

@test "Enabled secret-backed files fail with the keychain command when the service account token is missing" {
  render_license_on_opted_in_machine 1
  assert_equal "$output" ''
  [[ "$stderr" == *'security add-generic-password -U -s op-devland-sa -a "$USER" -w'* ]]
  [ ! -e "$FIXTURE/op.calls" ]
}
