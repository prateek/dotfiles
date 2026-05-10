#!/usr/bin/env bash
#
# chezmoi hooks.apply.post: read the pending bundle-id list written by the
# pre-hook. If non-empty, kill cfprefsd once so the next read by any app
# picks up the new files. Optionally relaunch the apps the user quit, gated
# by DOTFILES_RELAUNCH_AFTER_APPLY=1 (off by default).
#
set -euo pipefail

# Skip the cfprefsd kill (and the optional relaunch) when chezmoi was
# invoked with --dry-run. The pre-hook also exits early in that case so
# the state file should not exist; defensive double-check below. Handle
# bare `--dry-run`, `--dry-run=true`, and short-flag bundles like `-n`,
# `-nv`, `-vn`.
for arg in ${CHEZMOI_ARGS:-}; do
  case "$arg" in
    --dry-run|--dry-run=true) exit 0 ;;
    --*) ;;
    -*n*) exit 0 ;;
  esac
done

# Explicit opt-out — same var the pre-hook reads.
if [ "${DOTFILES_SKIP_PLIST_HOOKS:-0}" = "1" ]; then
  exit 0
fi

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/plist-pending.txt"

# No pre-hook output (or empty file) means no managed plists changed; nothing to do.
if [[ ! -s $state_file ]]; then
  rm -f "$state_file"
  exit 0
fi

/usr/bin/killall -u "$USER" cfprefsd 2>/dev/null || true

if [[ "${DOTFILES_RELAUNCH_AFTER_APPLY:-0}" == "1" ]]; then
  while IFS= read -r id; do
    [[ -z $id ]] && continue
    /usr/bin/open -b "$id" 2>/dev/null || true
  done < "$state_file"
fi

rm -f "$state_file"
