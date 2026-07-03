#!/usr/bin/env bash
# Copy an eval fixture into a fresh per-run working dir.
# Usage: setup_fixture.sh <fixture_name> <dest_dir>
# Available fixtures: see evals/files/ (one directory per eval).
#
# DEST must be absolute and must NOT exist; the script never deletes
# anything. We create the leaf with `mkdir` (no -p), so any race that
# beats us to the path fails the create instead of clobbering it.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <fixture_name> <dest_dir>" >&2
  exit 2
fi

FIXTURE="$1"
DEST="$2"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"

# FIXTURE must be a single directory name under evals/files/ — reject
# path separators and parent refs so `setup_fixture.sh ..` can't copy
# the entire evals/ tree.
if [[ "$FIXTURE" == */* || "$FIXTURE" == "." || "$FIXTURE" == ".." || -z "$FIXTURE" ]]; then
  echo "Fixture name must be a single directory under evals/files/; got: $FIXTURE" >&2
  exit 1
fi

SRC="$SKILL_DIR/evals/files/$FIXTURE"

if [[ ! -d "$SRC" ]]; then
  echo "Fixture not found: $SRC" >&2
  exit 1
fi

if [[ "$DEST" != /* ]]; then
  echo "DEST must be an absolute path; got: $DEST" >&2
  exit 1
fi

if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "Refusing: DEST ($DEST) already exists. Pick a fresh path or remove it first." >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$DEST")"
if ! mkdir -m 0700 -- "$DEST" 2>/dev/null; then
  echo "Refusing: failed to create DEST ($DEST). Path may have appeared after the existence check." >&2
  exit 1
fi
if [[ -L "$DEST" ]]; then
  echo "Refusing: DEST ($DEST) is a symlink after mkdir; aborting before copy." >&2
  exit 1
fi

cp -R "$SRC"/. "$DEST"/

echo "Fixture ready at $DEST"
