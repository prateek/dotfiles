#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BREWFILE="${BREWFILE:-$REPO_ROOT/Brewfile}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/audit/app-inventory.sh: macOS only; skipping."
  exit 0
fi

if [ ! -f "$BREWFILE" ]; then
  echo "Brewfile not found: $BREWFILE" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not found. Install Homebrew first." >&2
  exit 1
fi

extract_casks() {
  sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE" | LC_ALL=C sort -u
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

brewfile_casks="$tmp_dir/brewfile_casks.txt"
installed_casks="$tmp_dir/installed_casks.txt"

extract_casks >"$brewfile_casks"
brew list --cask 2>/dev/null | LC_ALL=C sort -u >"$installed_casks" || true

echo "# App inventory"
echo "# Brewfile: $BREWFILE"
echo

echo "## Brew casks: in Brewfile but not installed"
comm -23 "$brewfile_casks" "$installed_casks" | sed 's/^/- /' || true
echo

echo "## Brew casks: installed but not in Brewfile"
comm -13 "$brewfile_casks" "$installed_casks" | sed 's/^/- /' || true
echo

brewfile_mas_ids="$tmp_dir/brewfile_mas_ids.txt"
installed_mas_ids="$tmp_dir/installed_mas_ids.txt"
sed -n 's/^mas ".*", id: \([0-9][0-9]*\).*/\1/p' "$BREWFILE" | LC_ALL=C sort -u >"$brewfile_mas_ids" || true

if command -v mas >/dev/null 2>&1; then
  mas list 2>/dev/null | awk '{print $1}' | LC_ALL=C sort -u >"$installed_mas_ids" || true

  echo "## Mac App Store apps: in Brewfile but not installed"
  comm -23 "$brewfile_mas_ids" "$installed_mas_ids" | sed 's/^/- /' || true
  echo

  echo "## Mac App Store apps: installed but not in Brewfile"
  comm -13 "$brewfile_mas_ids" "$installed_mas_ids" | sed 's/^/- /' || true
  echo
else
  echo "## Mac App Store apps"
  echo "- 'mas' not installed; skipping MAS inventory."
  echo
fi

echo "## /Applications inventory (third-party apps)"
printf "app\tbundle_id\tapp_store_receipt\tflag\tpath\n"

print_app_row() {
  local app_path="$1"
  local app_name bundle_id receipt flag

  app_name="$(basename "$app_path")"
  bundle_id="$(mdls -raw -name kMDItemCFBundleIdentifier "$app_path" 2>/dev/null || true)"
  receipt="$(mdls -raw -name kMDItemAppStoreHasReceipt "$app_path" 2>/dev/null || true)"

  flag=""
  if [[ "$bundle_id" == com.apple.* ]]; then
    flag="apple"
  elif [ "$receipt" = "1" ]; then
    flag="mas"
  else
    flag="manual_or_brew"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$app_name" "$bundle_id" "$receipt" "$flag" "$app_path"
}

tmp_apps="$tmp_dir/apps.tsv"

for dir in "/Applications" "$HOME/Applications"; do
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' app; do
    print_app_row "$app" >>"$tmp_apps"
  done < <(find "$dir" -maxdepth 1 -name "*.app" -print0 2>/dev/null)
done

# Filter out Apple apps; sort for readability.
awk -F'\t' 'NR==1 || $5!="apple"' "$tmp_apps" | LC_ALL=C sort -t $'\t' -k5,5 -k1,1

echo
echo "# Notes"
echo "# - 'manual_or_brew' means the app is not an App Store app and isn't an Apple system app."
echo "# - To determine whether it's already managed by a cask, compare against your Brewfile/installed casks."
