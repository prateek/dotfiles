load '../../support/common'

setup() {
  setup_fixture
  local name
  for name in ${!DOTFILES_BANNER_@}; do unset "$name"; done
  export NO_COLOR=1 XDG_CONFIG_HOME="$HOME/.config"
  export BANNER_ROOT="$HOME/.config/dotfiles/shell-banner"
  export BANNER_CONFIG="$HOME/.config/fastfetch/config.jsonc"
  export BANNER_PROBES="$FIXTURE/probes"
  : > "$FIXTURE/chezmoi.toml"
  run_without_reporting_fds 0 chezmoi --no-tty --source "$DOTFILES_ROOT" \
    --config "$FIXTURE/chezmoi.toml" --destination "$HOME" \
    --cache "$XDG_CACHE_HOME/chezmoi" --persistent-state "$FIXTURE/chezmoi.db" \
    --override-data '{"machine_type":"ci","chezmoi":{"hostname":"dotfiles-test-host"}}' \
    apply --force --exclude=scripts --parent-dirs "$BANNER_ROOT" "$BANNER_CONFIG" "$HOME/.local/bin/dotpkgs" "$HOME/.local/lib/dotpkgs"
  assert_success
  cat > "$FIXTURE/bin/dotpkgs" <<EOF
#!/bin/sh
exec "$TEST_PYTHON" "$HOME/.local/bin/dotpkgs" "\$@"
EOF
  chmod +x "$FIXTURE/bin/dotpkgs"
  export DOTFILES_BANNER_DOTPKGS_BIN="$FIXTURE/bin/dotpkgs"
  cat > "$FIXTURE/bin/chezmoi-probe" <<'FAKE'
#!/bin/sh
for arg do
  case "$arg" in
    status) echo status >> "$BANNER_PROBES"; echo ' M .zshrc'; exit 0 ;;
    managed) printf '.zshrc\n.config\n'; exit 0 ;;
  esac
done
exit 2
FAKE
  chmod +x "$FIXTURE/bin/chezmoi-probe"
  printf 'DOTFILES_BANNER_SOURCES=chezmoi\nDOTFILES_BANNER_CHEZMOI_BIN=%s\n' \
    "$FIXTURE/bin/chezmoi-probe" > "$BANNER_ROOT/local.env"
}

render_configured_chezmoi() {
  run_without_reporting_fds 0 "$TEST_PYTHON" - "${1:-$BANNER_CONFIG}" <<'PY'
import json, pathlib, subprocess, sys
text = pathlib.Path(sys.argv[1]).read_text()
config = json.loads('\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//')))
module = next(m for m in config['modules'] if isinstance(m, dict) and m.get('text', '').endswith(' chezmoi'))
subprocess.run([module['shell'], '-c', module['text']], check=True)
PY
  assert_success
  assert_output --partial '1 / 2 drifted'
  [ -z "$stderr" ]
}

@test "disabling every source makes refresh a successful no-op" {
  echo DOTFILES_BANNER_CHEZMOI_ENABLED=0 >> "$BANNER_ROOT/local.env"
  run_zsh 0 "$BANNER_ROOT/bin/refresh"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -e "$BANNER_PROBES" ]
}

@test "a disabled or deselected source stops replaying cached counts" {
  run_zsh 0 "$BANNER_ROOT/bin/refresh"
  assert_success
  for override in DOTFILES_BANNER_CHEZMOI_ENABLED=0 DOTFILES_BANNER_SOURCES=brew; do
    cp "$BANNER_ROOT/local.env" "$FIXTURE/original.env"
    echo "$override" >> "$BANNER_ROOT/local.env"
    run_zsh 0 "$BANNER_ROOT/bin/module" chezmoi
    assert_success
    assert_output 'disabled'
    mv "$FIXTURE/original.env" "$BANNER_ROOT/local.env"
  done
}

@test "renderer reads the state directory configured only in local.env" {
  printf 'DOTFILES_BANNER_STATE_DIR=%s\n' "$FIXTURE/custom state" >> "$BANNER_ROOT/local.env"
  run_zsh 0 "$BANNER_ROOT/bin/refresh"
  assert_success
  render_configured_chezmoi
}

@test "configured command rows honor an XDG config path containing spaces" {
  export XDG_CONFIG_HOME="$FIXTURE/custom config"
  mkdir -p "$XDG_CONFIG_HOME"
  mv "$HOME/.config/dotfiles" "$XDG_CONFIG_HOME/"
  mv "$HOME/.config/fastfetch" "$XDG_CONFIG_HOME/"
  local moved_root="$XDG_CONFIG_HOME/dotfiles/shell-banner"
  run_zsh 0 "$moved_root/bin/refresh"
  assert_success
  render_configured_chezmoi "$XDG_CONFIG_HOME/fastfetch/config.jsonc"
}

@test "mise refresh uses the home configuration across project directories" {
  cat > "$FIXTURE/bin/mise-probe" <<'FAKE'
#!/bin/sh
printf '%s|%s\n' "$PWD" "$*" >> "$BANNER_PROBES"
case "$1" in
  outdated) if [ "$PWD" = "$HOME" ]; then echo '{}'; else echo '{"global-tool":{"latest":"2"}}'; fi ;;
  ls) echo '{"global-tool":[{"version":"1","installed":true,"requested_version":"latest"}]}' ;;
  *) exit 2 ;;
esac
exit 0
FAKE
  chmod +x "$FIXTURE/bin/mise-probe"
  printf 'DOTFILES_BANNER_SOURCES=mise\nDOTFILES_BANNER_MISE_BIN=%s\n' \
    "$FIXTURE/bin/mise-probe" > "$BANNER_ROOT/local.env"
  mkdir -p "$FIXTURE/project-a" "$FIXTURE/project-b"
  cd "$FIXTURE/project-a"
  run_zsh 0 "$BANNER_ROOT/bin/refresh"
  assert_success
  run_zsh 0 "$BANNER_ROOT/bin/module" mise
  assert_success
  assert_output --partial '0 / 1 outdated'
  printf '%s|ls --global --json\n%s|outdated --json\n%s|outdated --bump --json\n' "$HOME" "$HOME" "$HOME" > "$FIXTURE/expected-probes"
  cmp "$FIXTURE/expected-probes" "$BANNER_PROBES"
  cd "$FIXTURE/project-b"
  run_zsh 0 "$BANNER_ROOT/bin/refresh" --if-stale
  assert_success
  cmp "$FIXTURE/expected-probes" "$BANNER_PROBES"
}
