load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_after_34-agent-data-store.sh.tmpl
  stores="$FIXTURE/ssd"
  mkdir -p "$stores"
  cat > "$FIXTURE/bin/uv" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/uv-calls"
script="$4"
grep -q 'Manage the dotfiles-owned keys in ~/.agentsview/config.toml' "$script" || exit 97
exec "$TEST_PYTHON" -c '
import sys
text = sys.stdin.read()
sys.stdout.write(text if "managed = true" in text else text + "managed = true\n")
'
STUB
  chmod +x "$FIXTURE/bin/uv"
}

render_store_script() {
  render_template "$template" homelab "$("$TEST_PYTHON" -c '
import json, sys
print(json.dumps({"machines_local": {"agentsview_data_dir": sys.argv[1] + "/agentsview",
                                      "qmd_cache_dir": sys.argv[1] + "/qmd"}}))
' "$stores")" > "$FIXTURE/store.sh"
}

@test "agent data stores are linked and agentsview config reconciles through the link" {
  render_store_script
  mkdir -p "$stores/agentsview"
  printf 'auth_token = "keep"\n' > "$stores/agentsview/config.toml"

  run_bash 0 "$FIXTURE/store.sh"
  assert_success
  [ "$(readlink "$HOME/.agentsview")" = "$stores/agentsview" ]
  [ "$(readlink "$XDG_CACHE_HOME/qmd")" = "$stores/qmd" ]
  [ "$(cat "$stores/agentsview/config.toml")" = $'auth_token = "keep"\nmanaged = true' ]
  [ "$("$TEST_PYTHON" -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$stores/agentsview/config.toml")" = 0o600 ]
  assert_output --partial "Reconciled $HOME/.agentsview/config.toml."

  run_bash 0 "$FIXTURE/store.sh"
  assert_success
  assert_output --partial 'ok: agentsview config already reconciled.'
  [ "$(wc -l < "$FIXTURE/uv-calls")" -eq 2 ]
  [ -z "$(find "$stores/agentsview" -name 'config.toml.*')" ]
}

@test "an existing data directory is left in place with a migration warning" {
  render_store_script
  mkdir -p "$HOME/.agentsview"
  printf 'db' > "$HOME/.agentsview/sessions.db"

  run_bash 0 "$FIXTURE/store.sh"
  assert_success
  [[ "$stderr" == *"$HOME/.agentsview is not a link to $stores/agentsview; move its data there first"* ]]
  [ ! -L "$HOME/.agentsview" ]
  [ "$(cat "$HOME/.agentsview/sessions.db")" = db ]
  [ ! -e "$FIXTURE/uv-calls" ]
  [ -L "$XDG_CACHE_HOME/qmd" ]
}

@test "an unavailable store volume creates no links" {
  render_store_script
  chmod 555 "$stores"

  run_bash 0 "$FIXTURE/store.sh"
  chmod 755 "$stores"
  assert_success
  [[ "$stderr" == *"$stores/agentsview is unavailable; is its volume mounted?"* ]]
  [[ "$stderr" == *"$stores/qmd is unavailable; is its volume mounted?"* ]]
  [ ! -e "$HOME/.agentsview" ] && [ ! -L "$HOME/.agentsview" ]
  [ ! -L "$XDG_CACHE_HOME/qmd" ]
}

@test "hosts without agent data stores render no script" {
  run -0 render_template "$template" homelab
  [ -z "${output//[[:space:]]/}" ]
}
