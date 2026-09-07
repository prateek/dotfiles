#!/usr/bin/env zsh
set -euo pipefail

# --- config ---
src="${1:-$HOME/notes}"
dest="${2:-$HOME/backups/notes}"

mkdir -p "$dest"

# rsync -a preserves permissions; --delete keeps the mirror exact.
rsync -a --delete "$src/" "$dest/"

print "backed up $src -> $dest"
