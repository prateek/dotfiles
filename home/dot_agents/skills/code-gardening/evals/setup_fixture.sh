#!/usr/bin/env bash
# Copy an eval fixture into a per-run working dir.
# Usage: setup_fixture.sh <fixture_name> <dest_dir>
#   eval1_nongit_docs       — non-git workspace
#   eval2_git_cli           — initializes git and commits
#   eval3_agents_redundant  — non-git workspace

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
cp -R "$SRC"/. "$DEST"/

if [[ "$FIXTURE" == "eval2_git_cli" ]]; then
  cd "$DEST"
  git init -q
  git add -A
  git -c user.email=evals@local -c user.name=evals commit -q -m "initial fixture"
fi

echo "Fixture ready at $DEST"
