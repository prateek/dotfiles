render_template() {
  local relative="$1" machine="$2" data="${3:-}" override
  [[ -n "$data" ]] || data='{}'
  override="$("$TEST_PYTHON" -c '
import json, sys
print(json.dumps({"machine_type": sys.argv[1], "chezmoi": {"hostname": "dotfiles-test-host"}} | json.loads(sys.argv[2])))
' "$machine" "$data")"
  : > "$FIXTURE/chezmoi.toml"
  chezmoi --source "$DOTFILES_ROOT" --config "$FIXTURE/chezmoi.toml" \
    --destination "$HOME" --cache "$XDG_CACHE_HOME" \
    --persistent-state "$FIXTURE/chezmoi-state.boltdb" --no-tty \
    --override-data "$override" execute-template --file "$DOTFILES_ROOT/$relative"
}
