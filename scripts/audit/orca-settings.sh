#!/usr/bin/env bash
# Compare the tracked Orca settings with the `settings` row Orca actually reads
# (its profile-state SQLite store; ADR 0042), or push them with Orca closed.
#
#   scripts/audit/orca-settings.sh [check|apply]
#
# `check` is read-only and exits 1 on drift. `apply` refuses while Orca holds
# the store. Both render the desired settings from this checkout, so an unlanded
# change to the template or to agent_clis is what gets compared.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:-check}"
case "$mode" in
  check|apply) ;;
  *) echo "usage: $0 [check|apply]" >&2; exit 3 ;;
esac

template="$REPO_ROOT/home/.chezmoitemplates/orca-settings.desired.json.tmpl"
desired="$(chezmoi --source "$REPO_ROOT" execute-template --file "$template" | base64)"
exec "$REPO_ROOT/scripts/orca/settings-reconcile" "$mode" --desired-b64 "$desired"
