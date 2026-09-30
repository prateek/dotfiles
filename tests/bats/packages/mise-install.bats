load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset MISE_RUBY_GITHUB_ATTESTATIONS TEST_MISE_LS
  mkdir -p "$FIXTURE/installs/tool/1.0"
  cat > "$FIXTURE/bin/mise" <<'STUB'
#!/bin/sh
set -eu
if [ "${MISE_RUBY_GITHUB_ATTESTATIONS:-}" != false ]; then
  echo 'Ruby attestation checks must default to false during bootstrap' >&2
  exit 1
fi
printf '%s\n' "$*" >> "$FIXTURE/mise.calls"
case "$1" in
  ls) printf '%s\n' "${TEST_MISE_LS:-[]}" ;;
  where) printf '%s\n' "$FIXTURE/installs/tool/1.0" ;;
esac
STUB
  chmod +x "$FIXTURE/bin/mise"
}

render_hook() {
  render_template home/.chezmoiscripts/run_onchange_after_20-mise-install.sh.tmpl "$1" \
    '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
}

@test "Mise bootstrap trusts config and installs Node and Go before dependent tools without unauthenticated attestations" {
  run -0 "$TEST_PYTHON" - "$DOTFILES_ROOT/home/dot_config/mise/conf.d/runtimes.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as stream:
    assert tomllib.load(stream)['settings']['ruby']['github_attestations'] is False
PY
  assert_success
  render_hook personal
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  printf '%s\n' "trust $HOME/.config/mise/config.toml" 'install -y node' 'install -y go' \
    'exec node -- mise install -y' > "$FIXTURE/expected.calls"
  run -0 cmp "$FIXTURE/expected.calls" "$FIXTURE/mise.calls"
  assert_success
}

@test "Mise bootstrap uninstalls catalogue agents the machine no longer selects and clears their install roots" {
  render_hook work
  export TEST_MISE_LS='[{"version":"1.0","installed":true}]'
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  printf '%s\n' "trust $HOME/.config/mise/config.toml" 'install -y node' 'install -y go' \
    'exec node -- mise install -y' \
    'ls --json npm:@google/gemini-cli' 'where npm:@google/gemini-cli' 'uninstall --all npm:@google/gemini-cli' \
    'ls --json github:can1357/oh-my-pi' 'where github:can1357/oh-my-pi' 'uninstall --all github:can1357/oh-my-pi' \
    > "$FIXTURE/expected.calls"
  run -0 cmp "$FIXTURE/expected.calls" "$FIXTURE/mise.calls"
  assert_success
  [ ! -e "$FIXTURE/installs/tool" ]
}

@test "Mise bootstrap leaves a delisted agent alone when mise reports it absent" {
  render_hook work
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  run -0 grep -c '^ls --json' "$FIXTURE/mise.calls"
  assert_output '2'
  run -1 grep -q '^uninstall' "$FIXTURE/mise.calls"
  [ -d "$FIXTURE/installs/tool/1.0" ]
}
