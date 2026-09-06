load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset MISE_RUBY_GITHUB_ATTESTATIONS
  cat > "$FIXTURE/bin/mise" <<'STUB'
#!/bin/sh
set -eu
if [ "${MISE_RUBY_GITHUB_ATTESTATIONS:-}" != false ]; then
  echo 'Ruby attestation checks must default to false during bootstrap' >&2
  exit 1
fi
printf '%s\n' "$*" >> "$FIXTURE/mise.calls"
STUB
  chmod +x "$FIXTURE/bin/mise"
}

@test "Mise bootstrap trusts config and installs Node and Go before dependent tools without unauthenticated attestations" {
  run -0 "$TEST_PYTHON" - "$DOTFILES_ROOT/home/dot_config/mise/conf.d/runtimes.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as stream:
    assert tomllib.load(stream)['settings']['ruby']['github_attestations'] is False
PY
  assert_success
  render_template home/.chezmoiscripts/run_onchange_after_20-mise-install.sh.tmpl personal \
    '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  printf '%s\n' "trust $HOME/.config/mise/config.toml" 'install -y node' 'install -y go' \
    'exec node -- mise install -y' > "$FIXTURE/expected.calls"
  run -0 cmp "$FIXTURE/expected.calls" "$FIXTURE/mise.calls"
  assert_success
}
