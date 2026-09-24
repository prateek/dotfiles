#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf '%s\n' "$*" >&2; exit 1; }
dotfiles_sudo_start() { printf 'authenticate\n' >>"$FIXTURE/sudo.log"; }

source "$DOTFILES_ROOT/home/.chezmoitemplates/pin_hostname.sh"
pin_hostname_reconcile "$1"
