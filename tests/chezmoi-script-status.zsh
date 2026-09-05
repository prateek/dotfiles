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
mise_config_dir="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

tmp_config="$tmp_home/.config/chezmoi/chezmoi.toml"
tmp_cache="$tmp_home/.cache/chezmoi"
tmp_state="$tmp_home/.local/state/chezmoi/state.boltdb"
tmp_github_root="$tmp_home/code/github.com"
stub_bin="$tmp_home/test-bin"
mkdir -p "$tmp_home/.config/chezmoi" "$tmp_cache" "${tmp_state:h}" "$tmp_github_root" "$stub_bin"

# A temporary HOME still shares the caller's launchd domain and Orca runtime.
cat >"$stub_bin/launchctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$CHEZMOI_TEST_CALLS/launchctl"
if [[ $# -eq 2 && "$1" == bootout && "$2" == gui/*/com.prateek.wiki-sessions-sync ]]; then
  exit 0
fi
printf 'launchctl %s\n' "$*" >>"$CHEZMOI_TEST_CALLS/unexpected"
exit 64
EOF
cat >"$stub_bin/orca" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$CHEZMOI_TEST_CALLS/orca"
if [[ "$*" == 'automations list --json' ]]; then
  printf '{"ok":true,"result":{"automations":[]}}\n'
  exit 0
fi
printf 'orca %s\n' "$*" >>"$CHEZMOI_TEST_CALLS/unexpected"
exit 64
EOF
chmod +x "$stub_bin/launchctl" "$stub_bin/orca"
mkdir -p "$tmp_home/test-calls"

run_chezmoi() {
  DOTFILES_ROOT="$DOTFILES_ROOT" \
  DOTFILES_INSTALL_XCODE=false \
  DOTFILES_SKIP_PLIST_HOOKS=1 \
  DOTFILES_SKIP_LAUNCHCTL_SYNC=1 \
  CHEZMOI_TEST_CALLS="$tmp_home/test-calls" \
  MISE_TRUSTED_CONFIG_PATHS="$mise_config_dir" \
  PATH="$stub_bin:$PATH" \
  GHPATH="$tmp_github_root" \
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
[[ ! -s "$tmp_home/test-calls/unexpected" ]] || die "unexpected service call: $(<"$tmp_home/test-calls/unexpected")"
[[ -s "$tmp_home/test-calls/launchctl" ]] || die "disabled wiki feature did not exercise the launchd stub"
[[ -s "$tmp_home/test-calls/orca" ]] || die "disabled wiki feature did not exercise the Orca stub"

print -- "OK chezmoi-script-status"
