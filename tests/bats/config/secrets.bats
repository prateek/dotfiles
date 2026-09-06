load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  data='{"secrets":{"refs":{"example_license":"op://vault-id/item-id/field-id"}},"licenses":{"paths":["Library/Application Support/Example App/license.key"]}}'
  cat > "$FIXTURE/bin/op" <<'STUB'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FIXTURE/op.calls"
case "$*" in
  'signin --raw') printf test-session ;;
  '--session test-session read --no-newline op://vault-id/item-id/field-id') printf stub-license-value ;;
  *) printf 'unexpected op invocation: %s\n' "$*" >&2; exit 2 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/op"
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

@test "Enabled secret-backed files leave the ignore list and read the declared field using a session" {
  data="$("$TEST_PYTHON" -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1]) | {"machines_local":{"secrets_enabled":True}}))' "$data")"
  run -0 --separate-stderr render_template home/.chezmoiignore personal "$data"
  assert_success
  [ -z "$stderr" ]
  refute_output --partial 'Library/Application Support/Example App/license.key'
  run -0 --separate-stderr render_template tests/fixtures/secret-backed-license.tmpl personal "$data"
  assert_success
  assert_output stub-license-value
  [ -z "$stderr" ]
  [ "$(cat "$FIXTURE/op.calls")" = $'signin --raw\n--session test-session read --no-newline op://vault-id/item-id/field-id' ]
}

@test "Secret-backed files honor locally configured secret references and opt-in" {
  cat > "$FIXTURE/local.toml" <<'CONFIG'
[data.machines_local]
secrets_enabled = true
[data.secrets.refs]
example_license = "op://vault-id/item-id/field-id"
CONFIG
  run_without_reporting_fds 0 chezmoi --source "$DOTFILES_ROOT" --config "$FIXTURE/local.toml" \
    --destination "$HOME" --cache "$XDG_CACHE_HOME" --persistent-state "$FIXTURE/local-state.boltdb" \
    execute-template --file "$DOTFILES_ROOT/tests/fixtures/secret-backed-license.tmpl"
  assert_success
  assert_output stub-license-value
  [ -z "$stderr" ]
  [[ "$(cat "$FIXTURE/op.calls")" == *'--session test-session read --no-newline op://vault-id/item-id/field-id'* ]]
}
