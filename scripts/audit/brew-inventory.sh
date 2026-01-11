#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BREWFILE="${BREWFILE:-$REPO_ROOT/Brewfile}"

if [ ! -f "$BREWFILE" ]; then
  echo "Brewfile not found: $BREWFILE" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not found. Install Homebrew first." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

brewfile_taps="$tmp_dir/brewfile_taps.txt"
installed_taps="$tmp_dir/installed_taps.txt"

brewfile_formulae="$tmp_dir/brewfile_formulae.txt"
installed_formulae_all="$tmp_dir/installed_formulae_all.txt"
installed_formulae_requested="$tmp_dir/installed_formulae_requested.txt"

sed -n 's/^tap "\([^"]*\)".*/\1/p' "$BREWFILE" | LC_ALL=C sort -u >"$brewfile_taps"
brew tap 2>/dev/null | LC_ALL=C sort -u >"$installed_taps" || true

sed -n 's/^brew "\([^"]*\)".*/\1/p' "$BREWFILE" | LC_ALL=C sort -u >"$brewfile_formulae"
brew list --formula --full-name 2>/dev/null | LC_ALL=C sort -u >"$installed_formulae_all" || true
brew list --formula --installed-on-request --full-name 2>/dev/null | LC_ALL=C sort -u >"$installed_formulae_requested" || true

echo "# Brew inventory"
echo "# Brewfile: $BREWFILE"
echo

echo "## Taps: in Brewfile but not tapped"
# Note: Homebrew doesn't always list its built-in taps here.
comm -23 "$brewfile_taps" "$installed_taps" | grep -vE '^homebrew/(bundle|cask|cask-fonts)$' | sed 's/^/- /' || true
echo

echo "## Taps: tapped but not in Brewfile"
comm -13 "$brewfile_taps" "$installed_taps" | sed 's/^/- /' || true
echo

echo "## Formulae: in Brewfile but not installed"
comm -23 "$brewfile_formulae" "$installed_formulae_all" | sed 's/^/- /' || true
echo

echo "## Formulae: installed (on-request) but not in Brewfile"
comm -13 "$brewfile_formulae" "$installed_formulae_requested" | sed 's/^/- /' || true
echo

echo "## Formulae: installed (any) but not in Brewfile (includes dependencies)"
comm -13 "$brewfile_formulae" "$installed_formulae_all" | sed 's/^/- /' || true
echo

echo "# Notes"
echo "# - 'installed (on-request)' are formulae you explicitly installed (not just deps)."
echo "# - Confirm before removing anything from Brewfile."
