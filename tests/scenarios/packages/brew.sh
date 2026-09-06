#!/bin/sh
set -eu
printf '%s%s\n' "${HOMEBREW_CASK_OPTS:+CASK_OPTS=$HOMEBREW_CASK_OPTS }" "$*" >> "$FIXTURE/brew.calls"
case "$*" in
  '--repository') printf '%s\n' "$FIXTURE/brew-repo" ;;
  tap) cat "$FIXTURE/brew.taps" ;;
  'list --formula') cat "$FIXTURE/brew.formulas" ;;
  'list --cask') cat "$FIXTURE/brew.casks" ;;
  'outdated --formula --verbose'|'outdated --cask --verbose') cat "$FIXTURE/brew.outdated" ;;
  tap\ *|install\ *|uninstall\ *) ;;
  *) printf 'unexpected brew command: %s\n' "$*" >&2; exit 99 ;;
esac
