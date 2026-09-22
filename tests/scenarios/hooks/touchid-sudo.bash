#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }
dotfiles_sudo_start() {
  printf 'authenticate\n' >>"$FIXTURE/sudo.log"
  if [ -f "$FIXTURE/during-auth" ]; then bash "$FIXTURE/during-auth"; fi
}

source "$DOTFILES_ROOT/home/.chezmoitemplates/touchid_sudo.sh"
touchid_sudo_reconcile "$FIXTURE/pam.d" "$1" "${2:-$(id -un)}" "$(id -gn)" "$FIXTURE/pam_tid.so.2"
