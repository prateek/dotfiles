#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/macos/apply.sh: macOS only; skipping."
  exit 0
fi

# macOS defaults are applied via chezmoi apply
# (home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl).
# Run `chezmoi apply` for those.

if [ "${DOTFILES_APPLY_PRIVILEGED_APP_ASSETS:-0}" = "1" ]; then
  chrome_policy="$(mktemp "${TMPDIR:-/tmp}/dotfiles-chrome-policy.XXXXXX.plist")"
  trap 'rm -f "$chrome_policy"' EXIT
  if "$REPO_ROOT/scripts/macos/render-chrome-policy.py" --output "$chrome_policy"; then
    sudo mkdir -p "/Library/Managed Preferences"
    sudo install -m 0644 "$chrome_policy" "/Library/Managed Preferences/com.google.Chrome.plist"
    killall "Google Chrome" >/dev/null 2>&1 || true
  fi
fi

if [ -x "$REPO_ROOT/scripts/macos/set-cmux-icon.sh" ] && [ -d "/Applications/cmux.app" ]; then
  "$REPO_ROOT/scripts/macos/set-cmux-icon.sh" "/Applications/cmux.app"
fi

echo "Done."
