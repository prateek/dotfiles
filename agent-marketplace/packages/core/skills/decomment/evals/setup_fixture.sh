#!/usr/bin/env bash
# Usage: setup_fixture.sh <fixture_name> <dest_dir>

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
DEST="$(cd "$DEST" && pwd)"  # eval2 changes directory before copying the overlay

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
