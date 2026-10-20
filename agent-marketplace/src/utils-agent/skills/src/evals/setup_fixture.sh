#!/usr/bin/env bash
# Materialize the src trigger-eval fixture in a fresh absolute destination.
# Usage: setup_fixture.sh <dest_dir>
#
# A small npm project that pins zod in its lockfile, so "the version this
# project has installed" resolves, plus the local files the negative cases
# name, so the model has nothing to hunt for before it decides.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <dest_dir>" >&2
  exit 2
fi

DEST="$1"
if [[ "$DEST" != /* ]]; then
  echo "destination must be absolute: $DEST" >&2
  exit 1
fi
if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "refusing to overwrite fixture path: $DEST" >&2
  exit 1
fi

mkdir -p -- "$DEST"/{src/lib,docs}
cd -- "$DEST"

cat > package.json <<'JSON'
{
  "name": "ledgerline",
  "version": "0.4.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "zod": "^3.23.0"
  }
}
JSON

cat > package-lock.json <<'JSON'
{
  "name": "ledgerline",
  "version": "0.4.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "ledgerline",
      "version": "0.4.0",
      "dependencies": {
        "zod": "^3.23.0"
      }
    },
    "node_modules/zod": {
      "version": "3.23.8",
      "resolved": "https://registry.npmjs.org/zod/-/zod-3.23.8.tgz",
      "license": "MIT"
    }
  }
}
JSON

cat > src/lib/parse.ts <<'TS'
import { z } from "zod";

const LINE = /^(\d{4}-\d{2}-\d{2})\s+(-?\d+(?:\.\d{2})?)\s+(.+?)\s*$/;

export const Entry = z.object({
  date: z.string(),
  amount: z.number(),
  memo: z.string().min(1),
});

export function parseLine(line: string) {
  const match = LINE.exec(line);
  if (!match) return null;
  return Entry.parse({ date: match[1], amount: Number(match[2]), memo: match[3] });
}
TS

cat > docs/migration-plan.md <<'MD'
# Ledger import migration

1. Accept both the old CSV and the new line format for one release.
2. Convert stored CSV imports in a background job.
3. Remove the CSV path.
MD

printf '# Ledgerline\n\nParses plain-text ledger lines into typed entries.\n' > README.md

git init -q .
git -c user.name="src eval" -c user.email="src-eval@example.com" add -A
git -c user.name="src eval" -c user.email="src-eval@example.com" commit -qm "fixture"

printf 'fixture=%s\n' "$DEST"
