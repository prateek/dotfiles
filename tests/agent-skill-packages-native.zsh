#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"

if ! command -v claude >/dev/null 2>&1; then
  print -u2 "skip: claude CLI is not available"
  exit 0
fi

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

cd "$REPO_ROOT"

plugins_root="$tmp_root/.agents/plugins"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$plugins_root" \
  --skip-config-templates
claude plugin validate "$plugins_root"
