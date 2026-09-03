#!/usr/bin/env zsh

set -euo pipefail

die() {
  print -u2 -- "linux-work-profile: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

tmp_home="$tmp_root/home"
tmp_config="$tmp_root/config/chezmoi.toml"
tmp_cache="$tmp_root/cache"
tmp_state="$tmp_root/state/chezmoi.boltdb"
python_bin_dir="$(python3 -c 'import os,sys; print(os.path.dirname(sys.executable))')"
mkdir -p "$tmp_home" "${tmp_config:h}" "$tmp_cache" "${tmp_state:h}"

run_chezmoi() {
  local platform="${CHEZMOI_TEST_OS:-linux}"

  DOTFILES_ROOT="$DOTFILES_ROOT" \
  HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
  PATH="$python_bin_dir:$PATH" \
    chezmoi --no-pager --no-tty \
      --override-data "{\"chezmoi\":{\"os\":\"$platform\"}}" \
      --config "$tmp_config" \
      --cache "$tmp_cache" \
      --persistent-state "$tmp_state" \
      "$@"
}

if [[ "$(uname -s)" == "Linux" ]]; then
  run_chezmoi init --source "$DOTFILES_ROOT" --promptChoice 'machine_type=work'
else
  # `init` uses the host OS before --override-data applies. Render the same
  # config template explicitly so local macOS runs still exercise Linux config.
  run_chezmoi execute-template --init \
    --promptChoice 'machine_type=work' \
    --file "$DOTFILES_ROOT/home/.chezmoi.toml.tmpl" \
    >"$tmp_config"
  cat >>"$tmp_config" <<'EOF'
[warnings]
configFileTemplateHasChanged = false
EOF
fi

config_text="$(<"$tmp_config")"
[[ "$config_text" == *'[scriptEnv]'* ]] ||
  die "Linux config does not prepend the user-local tool directory"
[[ "$config_text" == *"$tmp_home/.local/bin:"* ]] ||
  die "Linux config does not put the uv install directory on PATH"
[[ "$config_text" == *"$DOTFILES_ROOT/scripts/chezmoi-hooks/headless-uv.sh"* ]] ||
  die "Linux config does not install uv before reading source state"

features="$(run_chezmoi execute-template --file "$DOTFILES_ROOT/home/.chezmoitemplates/features.tmpl")"
FEATURES_JSON="$features" python3 - <<'PY' || die "Linux feature composition is wrong"
import json
import os

features = json.loads(os.environ["FEATURES_JSON"])
expected = {
    "groups": ["core"],
    "run_install_scripts": False,
    "apply_macos_defaults": False,
    "private_overlay": False,
    "elevation": "none",
    "agent_session_wiki": False,
    "orca_mode": "headless",
}
for key, value in expected.items():
    assert features.get(key) == value, (key, features.get(key), value)
PY

managed="$(run_chezmoi managed)"
contains() {
  grep -Fxq -- "$1" <<<"$managed"
}
excludes_prefix() {
  ! grep -Eq -- "^${1}(/|$)" <<<"$managed"
}

contains ".config/zsh/.zprofile" || die "portable zprofile is not managed"
contains ".local/bin/orca-cli" || die "orca-cli wrapper is not managed"
contains ".local/bin/orca-devpod-reconcile" || die "Orca reconciler is not managed"
contains ".orca/keybindings.json" || die "Orca keybindings are not managed"
contains ".claude/settings.json" || die "Claude plugin settings are not managed"

excludes_prefix '\.gitconfig' || die ".gitconfig must remain image-owned"
excludes_prefix '\.inputrc' || die ".inputrc must remain image-owned"
excludes_prefix '\.vimrc' || die ".vimrc must remain image-owned"
excludes_prefix '\.zshrc' || die "root .zshrc must remain image/user-owned"
excludes_prefix '\.config/git' || die "Git config must remain image-owned"
excludes_prefix '\.config/mise' || die "mise manifests must remain image-owned"
excludes_prefix '\.config/tmux' || die "tmux config must remain image-owned"
excludes_prefix '\.pi/agent/settings\.json' || die "pi settings must not require uv"
excludes_prefix '\.crit\.config\.json' || die "crit settings must not require uv"
for subtree in agents commands rules skills; do
  excludes_prefix "\\.claude/$subtree" ||
    die ".claude/$subtree must remain image-owned"
done
excludes_prefix 'Library' || die "Library targets must not render on Linux"
managed_scripts="$(grep -E '^\.chezmoiscripts/' <<<"$managed" || true)"
[[ "$managed_scripts" == ".chezmoiscripts/36-agent-plugins.sh" ]] ||
  die "only the agent plugin projection script may run during apply"

claude_modifier="$tmp_root/claude-settings-modifier"
run_chezmoi execute-template \
  --file "$DOTFILES_ROOT/home/dot_claude/modify_private_settings.json.tmpl" \
  >"$claude_modifier"
[[ "$(<"$claude_modifier")" == '#!/usr/bin/env -S uv run --quiet --script'* ]] ||
  die "headless Claude settings must use uv"

mkdir -p "$tmp_home/.claude"
cat >"$tmp_home/.claude/settings.json" <<'EOF'
{"imageOwnedSetting":"preserved"}
EOF
run_chezmoi apply --exclude=externals >/dev/null

[[ -f "$tmp_home/.agents/plugins/.claude-plugin/marketplace.json" ]] ||
  die "Claude plugin marketplace was not projected"
[[ -f "$tmp_home/.agents/plugins/plugins/core/.claude-plugin/plugin.json" ]] ||
  die "core plugin was not projected"
python3 - "$tmp_home/.claude/settings.json" "$tmp_home/.agents/plugins" <<'PY' || die "Claude plugin settings were not merged"
import json
import pathlib
import sys

settings = json.loads(pathlib.Path(sys.argv[1]).read_text())
marketplace = settings["extraKnownMarketplaces"]["prateek-local"]["source"]
assert marketplace == {"source": "directory", "path": sys.argv[2]}, marketplace
assert settings["enabledPlugins"]["core@prateek-local"] is True
assert settings["imageOwnedSetting"] == "preserved"
assert "statusLine" not in settings
assert "skillListingBudgetFraction" not in settings
assert "hooks" not in settings
PY

darwin_ignore="$(
  CHEZMOI_TEST_OS=darwin \
    run_chezmoi execute-template --file "$DOTFILES_ROOT/home/.chezmoiignore"
)"
grep -Fxq ".local/bin/orca-devpod-reconcile" <<<"$darwin_ignore" ||
  die "Linux-only reconciler must be ignored on Darwin"

wrapper="$tmp_root/orca-cli"
run_chezmoi cat "$tmp_home/.local/bin/orca-cli" >"$wrapper"
chmod +x "$wrapper"

fake_bin="$tmp_root/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/orca" <<EOF
#!/bin/sh
touch "$tmp_root/bare-orca-selected"
EOF
chmod +x "$fake_bin/orca"
cat >"$fake_bin/orca-ide" <<'EOF'
#!/bin/sh
exit 42
EOF
chmod +x "$fake_bin/orca-ide"

# Mask the real package path so this checks the explicit orca-ide fallback even
# on a pilot host where Orca is already installed.
python3 - "$wrapper" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace("/usr/bin/orca-ide", "/missing/orca-ide"))
PY

set +e
PATH="$fake_bin:/usr/bin:/bin" "$wrapper" status >/dev/null 2>&1
wrapper_rc=$?
set -e
[[ $wrapper_rc -eq 42 ]] || die "wrapper did not select explicit orca-ide fallback"
[[ ! -e "$tmp_root/bare-orca-selected" ]] || die "wrapper selected bare orca"

explicit="$tmp_root/explicit-orca"
cat >"$explicit" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF
chmod +x "$explicit"
selected="$(ORCA_CLI_COMMAND="$explicit" "$wrapper" repo list --json)"
[[ "$selected" == "repo list --json" ]] || die "explicit ORCA_CLI_COMMAND was not selected"

print -- "OK linux-work-profile"
