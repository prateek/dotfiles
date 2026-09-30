# shellcheck source=../../scripts/packages/lib.sh
source "$DOTFILES_ROOT/scripts/packages/lib.sh"

# Renders as the OS the machine type declares (features.tmpl refuses any other),
# or as the host OS for a type machines.toml does not define.
render_template() {
  local relative="$1" machine="$2" data="${3:-}" override
  [[ -n "$data" ]] || data='{}'
  override="$("$TEST_PYTHON" -c '
import json, sys
data = json.loads(sys.argv[3])
chezmoi = {"hostname": "dotfiles-test-host"} | ({"os": sys.argv[2]} if sys.argv[2] else {})
chezmoi |= data.pop("chezmoi", {})
print(json.dumps({"machine_type": sys.argv[1], "chezmoi": chezmoi} | data))
' "$machine" "$(machine_type_os "$machine")" "$data")"
  : > "$FIXTURE/chezmoi.toml"
  chezmoi --source "$DOTFILES_ROOT" --config "$FIXTURE/chezmoi.toml" \
    --destination "$HOME" --cache "$XDG_CACHE_HOME" \
    --persistent-state "$FIXTURE/chezmoi-state.boltdb" --no-tty \
    --override-data "$override" execute-template --file "$DOTFILES_ROOT/$relative"
}
