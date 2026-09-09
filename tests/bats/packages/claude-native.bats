load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  unset MISE_DATA_DIR
  template=home/.chezmoiscripts/run_after_06-claude-native.sh.tmpl
  render_template "$template" work '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"

  cat > "$FIXTURE/fake-install.sh" <<'STUB'
#!/bin/sh
{
  printf 'PATH=%s\n' "$PATH"
  printf 'ARGS=%s\n' "$*"
} > "$FIXTURE/installer.env"
[ "${TEST_INSTALLER_STATUS:-0}" = 0 ] || exit "${TEST_INSTALLER_STATUS}"
versions="$HOME/.local/share/claude/versions"
mkdir -p "$versions" "$HOME/.local/bin"
printf '#!/bin/sh\nprintf "1.2.3 (Claude Code)\\n"\n' > "$versions/1.2.3"
chmod +x "$versions/1.2.3"
ln -sfn "$versions/1.2.3" "$HOME/.local/bin/claude"
STUB

  cat > "$FIXTURE/bin/curl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/curl.calls"
[ "${TEST_CURL_STATUS:-0}" = 0 ] || exit "${TEST_CURL_STATUS}"
output=""
while [ "$#" -gt 0 ]; do
  [ "$1" = -o ] && output="$2"
  shift
done
cp "$FIXTURE/fake-install.sh" "$output"
STUB

  # Matches the hook's own pattern against a process table the case writes, so a
  # pattern that cannot match a real command line fails here instead of passing
  # on the stub's say-so.
  cat > "$FIXTURE/bin/pgrep" <<'STUB'
#!/bin/sh
printf '%s\n' "$2" >> "$FIXTURE/pgrep.calls"
[ -s "$FIXTURE/procs" ] || exit 1
grep -Eq "$2" "$FIXTURE/procs"
STUB

  cat > "$FIXTURE/bin/mise" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/mise.calls"
exit "${TEST_MISE_STATUS:-0}"
STUB

  chmod +x "$FIXTURE/bin/curl" "$FIXTURE/bin/pgrep" "$FIXTURE/bin/mise"
  : > "$FIXTURE/curl.calls"
  : > "$FIXTURE/mise.calls"
  : > "$FIXTURE/procs"

  # The hook decides between warning and failing on whether any claude is left
  # on PATH, so the fixture must not inherit the developer's own install.
  render_path="$PATH"
  export PATH="$FIXTURE/bin:/usr/bin:/bin"
}

seed_npm_installs() {
  node_dir="$HOME/.local/share/mise/installs/node/24.12.0"
  mise_copy="$HOME/.local/share/mise/installs/npm-anthropic-ai-claude-code"
  mkdir -p "$node_dir/lib/node_modules/@anthropic-ai/claude-code" \
    "$node_dir/bin" "$mise_copy/2.1.263/bin"
  # mise keeps version aliases beside the real install in both trees.
  ln -s ./24.12.0 "$HOME/.local/share/mise/installs/node/24.12"
  ln -s ./24.12.0 "$HOME/.local/share/mise/installs/node/latest"
  ln -s ./2.1.263 "$mise_copy/latest"
  : > "$mise_copy/2.1.263/bin/claude"
  cat > "$node_dir/bin/npm" <<'STUB'
#!/bin/sh
{
  printf 'ARGS=%s\n' "$*"
  printf 'PREFIX=%s\n' "${npm_config_prefix:-}"
  printf 'PATH=%s\n' "$PATH"
} > "$FIXTURE/npm.env"
rm -rf "$(dirname "$0")/../lib/node_modules/@anthropic-ai"
STUB
  chmod +x "$node_dir/bin/npm"
}

@test "Claude Code installs from Anthropic's installer without touching managed shell startup files" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [ -x "$HOME/.local/bin/claude" ]
  [ ! -e "$HOME/.zprofile" ]
  local recorded
  recorded="$(cat "$FIXTURE/installer.env")"
  # Must match the autoUpdatesChannel in claude-settings-managed.json.tmpl.
  [[ "$recorded" == *'ARGS=latest'* ]]
  # The installer edits a shell profile when its install directory is off PATH.
  [[ "$recorded" == *"PATH=$HOME/.local/bin:"* ]]
  [[ "$recorded" != *homebrew* ]]
  [[ "$recorded" != *"$FIXTURE/bin"* ]]
}

@test "the channel handed to the installer matches the managed autoUpdatesChannel" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  local managed
  managed="$(PATH="$render_path" render_template \
    home/.chezmoitemplates/claude-settings-managed.json.tmpl work \
    '{"machines_local":{"run_install_scripts":true}}' |
    "$TEST_PYTHON" -c 'import json, sys; print(json.load(sys.stdin)["autoUpdatesChannel"])')"
  # The installer writes its target into the settings file chezmoi manages.
  [[ "$(cat "$FIXTURE/installer.env")" == *"ARGS=$managed"* ]]
}

@test "Claude Code installation is skipped once the native launcher is present" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  : > "$FIXTURE/curl.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial 'ok: Claude Code native install is present.'
  [ ! -s "$FIXTURE/curl.calls" ]
}

@test "Both npm copies retire once the native install answers for claude" {
  seed_npm_installs
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ ! -d "$node_dir/lib/node_modules/@anthropic-ai/claude-code" ]
  local recorded
  recorded="$(cat "$FIXTURE/npm.env")"
  [[ "$recorded" == *'ARGS=uninstall -g @anthropic-ai/claude-code'* ]]
  [[ "$recorded" == *"PREFIX=$node_dir"* ]]
  [[ "$recorded" == *"PATH=$node_dir/bin:"* ]]
  [[ "$(cat "$FIXTURE/mise.calls")" == *'uninstall --all npm:@anthropic-ai/claude-code'* ]]
  # mise's uninstall leaves the alias symlinks and its backend marker behind.
  [ ! -e "$HOME/.local/share/mise/installs/npm-anthropic-ai-claude-code" ]
}

@test "the leftovers of an already-retired mise copy are cleared without another uninstall" {
  seed_npm_installs
  rm -rf "$mise_copy/2.1.263"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [ ! -e "$HOME/.local/share/mise/installs/npm-anthropic-ai-claude-code" ]
  [ ! -s "$FIXTURE/mise.calls" ]
}

@test "npm copies survive an apply while a session is still executing them" {
  seed_npm_installs
  # A mise shim execs the version it selects; a live session never shows a shim.
  printf '%s\n' "$node_dir/bin/claude --resume" \
    "$mise_copy/2.1.263/bin/claude" > "$FIXTURE/procs"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"still running from $node_dir/bin/claude"* ]]
  [[ "$stderr" == *'still running from the mise npm-backend copy'* ]]
  [ -d "$node_dir/lib/node_modules/@anthropic-ai/claude-code" ]
  [ -d "$mise_copy/2.1.263" ]
  [ ! -e "$FIXTURE/npm.env" ]
  [ ! -s "$FIXTURE/mise.calls" ]
}

@test "a busy npm copy does not hold up retiring the idle one" {
  seed_npm_installs
  # The state this machine landed in.
  printf '%s\n' "$node_dir/bin/claude --resume" > "$FIXTURE/procs"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"still running from $node_dir/bin/claude"* ]]
  [[ "$stderr" != *'mise npm-backend copy'* ]]
  [ -d "$node_dir/lib/node_modules/@anthropic-ai/claude-code" ]
  [ ! -e "$FIXTURE/npm.env" ]
  [[ "$(cat "$FIXTURE/mise.calls")" == *'uninstall --all npm:@anthropic-ai/claude-code'* ]]
}

@test "a version alias does not slip past the live-session guard" {
  seed_npm_installs
  # The busy copy is also reachable as the 24.12 and latest aliases beside it.
  printf '%s\n' "$node_dir/bin/claude --resume" > "$FIXTURE/procs"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -d "$node_dir/lib/node_modules/@anthropic-ai/claude-code" ]
  [ ! -e "$FIXTURE/npm.env" ]
  [[ "$(cat "$FIXTURE/pgrep.calls")" != *"/node/24.12/"* ]]
}

@test "Failed Claude Code installation keeps the npm install it would have retired" {
  seed_npm_installs
  printf '#!/bin/sh\nprintf "2.1.266 (Claude Code)\\n"\n' > "$FIXTURE/bin/claude"
  chmod +x "$FIXTURE/bin/claude"
  export TEST_INSTALLER_STATUS=1
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'the next chezmoi apply retries'* ]]
  [ -d "$node_dir/lib/node_modules/@anthropic-ai/claude-code" ]
  [ ! -e "$FIXTURE/npm.env" ]
}

@test "Failed Claude Code installation fails the apply when no claude is left on PATH" {
  export TEST_CURL_STATUS=1
  run_bash 1 "$FIXTURE/install.sh"
  assert_failure
  [[ "$stderr" == *'Could not download https://claude.ai/install.sh.'* ]]
  [[ "$stderr" == *'no claude is on PATH'* ]]
  [ ! -e "$HOME/.local/bin/claude" ]
}

@test "Claude Code installation is limited to machines that list claude in agent_clis" {
  PATH="$render_path" render_template "$template" ci \
    '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/excluded.sh"
  run_bash 0 "$FIXTURE/excluded.sh"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -e "$HOME/.local/bin/claude" ]
  [ ! -s "$FIXTURE/curl.calls" ]
}
