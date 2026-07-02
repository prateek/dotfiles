#!/usr/bin/env bash
# Copy an eval fixture into a per-run working dir.
# Usage: setup_fixture.sh <fixture_name> <dest_dir>
#   eval1_failure_modes  — plain workspace
#   eval2_git_scope      — commits base/ as a human baseline, overlays
#                          uncommitted working-tree changes from overlay/
#   eval3_zsh_generate   — plain workspace
#   eval4_borderline     — plain workspace
#   eval5_python_report  — plain workspace
#   eval6_zsh_envfile    — plain workspace

set -euo pipefail

FIXTURE="$1"
DEST="$2"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$SKILL_DIR/evals/files/$FIXTURE"

if [[ ! -d "$SRC" ]]; then
  echo "Fixture not found: $SRC" >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"  # absolutize: the eval2 branch cd's into it before copying the overlay

if [[ "$FIXTURE" == "eval2_git_scope" ]]; then
  cp -R "$SRC/base"/. "$DEST"/
  cd "$DEST"
  git init -q
  git add -A
  git -c user.email=evals@local -c user.name=evals commit -q -m "human baseline"
  cp -R "$SRC/overlay"/. "$DEST"/
else
  cp -R "$SRC"/. "$DEST"/
fi

echo "Fixture ready at $DEST"
