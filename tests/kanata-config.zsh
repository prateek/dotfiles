#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "kanata-config: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
config="$DOTFILES_ROOT/home/dot_config/kanata/kanata.kbd"

[[ -f "$config" ]] || die "missing config: $config"
command -v kanata >/dev/null 2>&1 || die "missing kanata; run: brew install kanata"

kanata --check --cfg "$config" >/dev/null

print -- "OK kanata-config"
