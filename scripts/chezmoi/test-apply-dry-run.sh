#!/usr/bin/env bash

# Shared helper for validating chezmoi apply --dry-run in a clean temp environment.
# Used by Makefile targets, CI, and test scripts.

set -euo pipefail

machine_type="${1:-ci}"
case "$machine_type" in
  ci|personal|homelab|work) ;;
  *) echo "Invalid machine type: $machine_type (must be ci, personal, homelab, or work)" >&2; exit 1 ;;
esac

dotfiles_root="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

mkdir -p "$tmp_home/.config/chezmoi" "$tmp_home/.cache/chezmoi" "$tmp_home/.local/state/chezmoi"

run_chezmoi() {
  DOTFILES_ROOT="$dotfiles_root" \
  DOTFILES_MACHINE_TYPE="$machine_type" \
  DOTFILES_RUN_INSTALL_SCRIPTS=false \
  DOTFILES_APPLY_MACOS_DEFAULTS=false \
  DOTFILES_SECRETS_ENABLED=false \
  HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
    chezmoi --no-tty \
      --config "$tmp_home/.config/chezmoi/chezmoi.toml" \
      --cache "$tmp_home/.cache/chezmoi" \
      --persistent-state "$tmp_home/.local/state/chezmoi/state.boltdb" \
      "$@"
}

run_chezmoi init --promptDefaults --source "$dotfiles_root" >/dev/null
run_chezmoi apply --dry-run --refresh-externals=never --source "$dotfiles_root/home" --destination "$tmp_home" >/dev/null
