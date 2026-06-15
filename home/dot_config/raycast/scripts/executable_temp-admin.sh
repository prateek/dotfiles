#!/bin/bash
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Temp Admin
# @raycast.mode compact
# @raycast.packageName Admin
#
# Optional parameters:
# @raycast.icon 🔑
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Trigger Jamf Self Service temporary-admin elevation and wait until this account joins the admin group. Reads the configured policy from ~/.config/dotfiles/elevation.sh.
# @raycast.author Prateek Rungta
#
# Mirrors the apply-time hook _dotfiles_elevate_jamf_self_service in
# home/.chezmoitemplates/script_lib.sh. The policy ID is not committed; it is
# discovered at runtime from the rendered elevation.sh. See
# docs/references/jamf-self-service-elevation.md.

set -euo pipefail

is_admin() {
  id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin
}

if is_admin; then
  echo "✅ Already an administrator."
  exit 0
fi

config="${HOME}/.config/dotfiles/elevation.sh"
if [ ! -r "$config" ]; then
  echo "⚠️  No elevation config at $config; nothing to do."
  exit 1
fi
# shellcheck disable=SC1090
. "$config"

method="${DOTFILES_ELEVATION_METHOD:-none}"
if [ "$method" != "jamf-self-service" ]; then
  echo "⚠️  Elevation method is '$method'; no Self Service trigger available."
  exit 1
fi

policy_id="${DOTFILES_JAMF_POLICY_ID:-}"
if [ -z "$policy_id" ]; then
  echo "⚠️  DOTFILES_JAMF_POLICY_ID is empty; set it via chezmoi (see docs/references/jamf-self-service-elevation.md)."
  exit 1
fi

echo "🔑 Requesting temporary admin via Jamf Self Service (policy ${policy_id})…"
if ! open "jamfselfservice://content?entity=policy&action=execute&id=${policy_id}" >/dev/null 2>&1; then
  echo "❌ Failed to open Self Service URL for policy ${policy_id}."
  exit 1
fi

for _ in $(seq 1 30); do
  sleep 1
  if is_admin; then
    echo "✅ You are now an administrator (~1h)."
    exit 0
  fi
done

echo "❌ Timed out after 30s waiting for admin. Check Self Service / Jamf logs."
exit 1
