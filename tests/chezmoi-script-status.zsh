#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "chezmoi-script-status: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

tmp_config="$tmp_home/.config/chezmoi/chezmoi.toml"
tmp_cache="$tmp_home/.cache/chezmoi"
tmp_state="$tmp_home/.local/state/chezmoi/state.boltdb"
tmp_github_root="$tmp_home/code/github.com"
tmp_grmrepo_config="$tmp_home/.local/state/grmrepo/config.toml"
mkdir -p "$tmp_home/.config/chezmoi" "$tmp_cache" "${tmp_state:h}" "$tmp_github_root" "${tmp_grmrepo_config:h}"

run_chezmoi() {
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  DOTFILES_INSTALL_XCODE=false \
  DOTFILES_SKIP_PLIST_HOOKS=1 \
  GHPATH="$tmp_github_root" \
  GRMREPO_CONFIG="$tmp_grmrepo_config" \
  HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
  ZDOTDIR="$tmp_home/.config/zsh" \
    chezmoi --no-pager --no-tty \
      --config "$tmp_config" \
      --cache "$tmp_cache" \
      --persistent-state "$tmp_state" \
      --override-data '{"machines_local":{"run_install_scripts":false}}' \
      "$@"
}

run_chezmoi init --promptDefaults --promptChoice 'machine_type=ci' --source "$DOTFILES_ROOT"
run_chezmoi apply --exclude=externals >/dev/null

status_output="$(run_chezmoi status --exclude=externals)"
[[ -z "$status_output" ]] || die "expected clean chezmoi status after apply, got: $status_output"

print -- "OK chezmoi-script-status"
