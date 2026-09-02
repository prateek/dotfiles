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
mkdir -p "$tmp_home" "${tmp_config:h}" "$tmp_cache" "${tmp_state:h}"

run_chezmoi() {
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
    chezmoi --no-pager --no-tty \
      --override-data '{"chezmoi":{"os":"linux"}}' \
      --config "$tmp_config" \
      --cache "$tmp_cache" \
      --persistent-state "$tmp_state" \
      "$@"
}

if [[ "$(uname -s)" == "Linux" ]]; then
  run_chezmoi init --source "$DOTFILES_ROOT" --promptChoice 'machine_type=work'
else
  # Config-template rendering happens before --override-data is available to
  # `init`, so a non-Linux host would take the Darwin-only Jamf prompt. Build
  # the equivalent noninteractive config locally; the Ubuntu CI lane exercises
  # the real init path.
  cat >"$tmp_config" <<EOF
sourceDir = "$DOTFILES_ROOT"
pager = ""

[warnings]
configFileTemplateHasChanged = false

[data]
dotfiles_dir = "$DOTFILES_ROOT"
xdg_config_dir = "$tmp_home/.config"
xdg_cache_dir = "$tmp_home/.cache"
xdg_state_dir = "$tmp_home/.local/state"
machine_type = "work"
jamf_policy_id = ""
EOF
fi

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

excludes_prefix '\.gitconfig' || die ".gitconfig must remain image-owned"
excludes_prefix '\.inputrc' || die ".inputrc must remain image-owned"
excludes_prefix '\.vimrc' || die ".vimrc must remain Spacejunk-owned"
excludes_prefix '\.zshrc' || die "root .zshrc must remain image/user-owned"
excludes_prefix '\.config/git' || die "Git config must remain image-owned"
excludes_prefix '\.config/mise' || die "mise manifests must remain image-owned"
excludes_prefix '\.config/tmux' || die "tmux config must remain Spacejunk-owned"
for subtree in agents commands rules skills; do
  excludes_prefix "\\.claude/$subtree" ||
    die ".claude/$subtree must remain Spacejunk-owned"
done
excludes_prefix 'Library' || die "Library targets must not render on Linux"
excludes_prefix '\.chezmoiscripts' || die "Chezmoi scripts must not run on Linux"

run_chezmoi apply --dry-run --exclude=externals >/dev/null

zprofile="$tmp_root/zprofile"
run_chezmoi cat "$tmp_home/.config/zsh/.zprofile" >"$zprofile"
mkdir -p "$tmp_home/agentd"
cat >"$tmp_home/agentd/workstation.env" <<'EOF'
DEVBOX_PROFILE_BASE=workstation
DEVBOX_PROFILE_ORDER=workstation
EOF
cat >"$tmp_home/.cursor.env" <<'EOF'
DEVBOX_PROFILE_ORDER=cursor
EOF
profile_env="$(
  HOME="$tmp_home" PATH="/usr/bin:/bin" \
    zsh -dfc 'source "$1"; /usr/bin/env' _ "$zprofile"
)"
grep -Fxq "DEVBOX_PROFILE_BASE=workstation" <<<"$profile_env" ||
  die "zprofile did not export workstation.env"
grep -Fxq "DEVBOX_PROFILE_ORDER=cursor" <<<"$profile_env" ||
  die "zprofile did not load .cursor.env last"

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
