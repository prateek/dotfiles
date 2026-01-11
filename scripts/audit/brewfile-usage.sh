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

DAYS_UNUSED="${DAYS_UNUSED:-90}"
if [ -n "${HISTORY_FILE:-}" ]; then
  : # user provided
elif [ -f "$HOME/.zhistory" ]; then
  HISTORY_FILE="$HOME/.zhistory"
else
  HISTORY_FILE="$HOME/.zsh_history"
fi

extract_casks() {
  sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE"
}

extract_formulae() {
  sed -n 's/^brew "\([^"]*\)".*/\1/p' "$BREWFILE"
}

if [ "$(uname -s)" = "Darwin" ]; then
  has_mdls=1
else
  has_mdls=0
fi

# Build a frequency + last-used map of commands from zsh history (best-effort).
# Supports extended history lines like: ": 1700000000:0;git status"
declare -A HIST_FREQ=()
declare -A HIST_LAST_EPOCH=()
if [ -f "$HISTORY_FILE" ]; then
  while IFS=$'\t' read -r cmd count last_epoch; do
    [ -n "$cmd" ] || continue
    HIST_FREQ["$cmd"]="$count"
    if [ -n "${last_epoch:-}" ] && [ "$last_epoch" -gt 0 ] 2>/dev/null; then
      HIST_LAST_EPOCH["$cmd"]="$last_epoch"
    fi
  done < <(
    awk -F';' '
      function basecmd(s) { sub(/ .*/, "", s); return s }
      {
        cmd=basecmd($2)
        if (cmd == "") next
        freq[cmd]++

        # Parse epoch from extended history prefix if present
        meta=$1
        if (meta ~ /^: [0-9]+:/) {
          sub(/^: /, "", meta)
          split(meta, parts, ":")
          epoch=parts[1] + 0
          if (epoch > last[cmd]) last[cmd]=epoch
        }
      }
      END {
        for (c in freq) {
          printf "%s\t%d\t%d\n", c, freq[c], (c in last ? last[c] : 0)
        }
      }' "$HISTORY_FILE"
  )
fi

# Installed sets (avoid calling `brew list` in a tight loop).
declare -A INSTALLED_CASKS=()
while IFS= read -r c; do
  [ -n "$c" ] || continue
  INSTALLED_CASKS["$c"]=1
done < <(brew list --cask 2>/dev/null || true)

declare -A INSTALLED_FORMULAE=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  INSTALLED_FORMULAE["$f"]=1
done < <(brew list --formula 2>/dev/null || true)

# Install reasons / dependency graph hints
declare -A ON_REQUEST=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  ON_REQUEST["$f"]=1
done < <(brew list --formula --installed-on-request 2>/dev/null || true)

declare -A LEAVES=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  LEAVES["$f"]=1
done < <(brew leaves 2>/dev/null || true)

HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"

guess_primary_cmd() {
  local formula="$1"

  local raw="${formula##*/}"
  local base="${raw%@*}"

  case "$raw" in
    python@*) echo "python3"; return 0 ;;
    openjdk@*) echo "java"; return 0 ;;
  esac

  case "$base" in
    ripgrep) echo "rg" ;;
    neovim) echo "nvim" ;;
    the_silver_searcher) echo "ag" ;;
    python) echo "python3" ;;
    openjdk) echo "java" ;;
    coreutils) echo "gls" ;;
    gnu-sed) echo "gsed" ;;
    findutils) echo "gfind" ;;
    *) echo "$base" ;;
  esac
}

best_cmd_guess() {
  # Prefer an actually-used binary name from this formula's opt/{bin,sbin}.
  # Falls back to a heuristic mapping for speed/portability.
  local formula="$1"
  local raw="${formula##*/}"

  if [ -n "$HOMEBREW_PREFIX" ] && [ -d "$HOMEBREW_PREFIX/opt/$raw" ]; then
    local opt="$HOMEBREW_PREFIX/opt/$raw"
    local best_cmd=""
    local best_count=0
    local best_epoch=0
    local f cmd count epoch

    shopt -s nullglob
    for f in "$opt"/bin/* "$opt"/sbin/*; do
      [ -f "$f" ] || continue
      [ -x "$f" ] || continue
      cmd="$(basename "$f")"
      count="${HIST_FREQ[$cmd]:-0}"
      epoch="${HIST_LAST_EPOCH[$cmd]:-0}"
      if [ "$count" -gt "$best_count" ] || { [ "$count" -eq "$best_count" ] && [ "$epoch" -gt "$best_epoch" ]; }; then
        best_cmd="$cmd"
        best_count="$count"
        best_epoch="$epoch"
      fi
    done
    shopt -u nullglob

    if [ -n "$best_cmd" ]; then
      echo "$best_cmd"
      return 0
    fi
  fi

  guess_primary_cmd "$formula"
}

epoch_from_mdls_datetime() {
  # Input format: "YYYY-MM-DD HH:MM:SS +0000"
  local dt="$1"
  date -j -f "%Y-%m-%d %H:%M:%S %z" "$dt" "+%s" 2>/dev/null || true
}

days_since_epoch() {
  local epoch="$1"
  local now
  now="$(date +%s)"
  echo $(( (now - epoch) / 86400 ))
}

echo "# Brewfile usage report"
echo "# Brewfile: $BREWFILE"
echo "# DAYS_UNUSED: $DAYS_UNUSED"
echo

echo "## Casks (GUI apps)"
printf "cask\tinstalled\tapp_path\tlast_used\tuse_count\tdays_since_last_use\tflag\n"

tmp_casks="$(mktemp)"
trap 'rm -f "$tmp_casks"' EXIT

while IFS= read -r cask; do
  [ -n "$cask" ] || continue

  installed="no"
  app_path=""
  last_used=""
  use_count=""
  days_since=""
  flag=""

  if [ -n "${INSTALLED_CASKS[$cask]+x}" ]; then
    installed="yes"

    # Try to locate the app bundle name from the cask install contents.
    app_from_cask="$(brew list --cask "$cask" 2>/dev/null | grep -m 1 -E '\.app$' || true)"
    if [ -n "$app_from_cask" ]; then
      app_name="$(basename "$app_from_cask")"
      if [ -d "/Applications/$app_name" ]; then
        app_path="/Applications/$app_name"
      else
        app_path="$app_from_cask"
      fi
    fi

    if [ "$has_mdls" = "1" ] && [ -n "$app_path" ]; then
      last_used="$(mdls -raw -name kMDItemLastUsedDate "$app_path" 2>/dev/null || true)"
      use_count="$(mdls -raw -name kMDItemUseCount "$app_path" 2>/dev/null || true)"
      [ "$last_used" = "(null)" ] && last_used=""
      [ "$use_count" = "(null)" ] && use_count=""

	      if [ -n "$last_used" ]; then
	        last_epoch="$(epoch_from_mdls_datetime "$last_used")"
	        if [ -n "$last_epoch" ]; then
	          days_since="$(days_since_epoch "$last_epoch")"
	          if [ "$days_since" -ge "$DAYS_UNUSED" ]; then
	            flag="review_unused"
	          fi
	        fi
	      elif [ -z "$flag" ]; then
	        flag="review_unknown_usage"
	      fi
	    fi
	  else
	    flag="review_not_installed"
	  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$cask" "$installed" "$app_path" "$last_used" "$use_count" "$days_since" "$flag" >>"$tmp_casks"
done < <(extract_casks)

cat "$tmp_casks" | LC_ALL=C sort -t $'\t' -k6,6nr -k1,1

echo
echo "## Formulae (CLI tools, heuristic)"
printf "formula\tinstalled\tinstall_reason\tleaf\tneeded_by_used\tcmd_guess\thistory_count\tlast_used_epoch\tdays_since_last_use\tflag\n"

tmp_formulae="$(mktemp)"
trap 'rm -f "$tmp_casks" "$tmp_formulae"' EXIT

tmp_used_formulae="$(mktemp)"
trap 'rm -f "$tmp_casks" "$tmp_formulae" "$tmp_used_formulae"' EXIT

while IFS= read -r formula; do
  [ -n "$formula" ] || continue

  formula_base="${formula##*/}"
  installed="no"
  cmd_guess="$(best_cmd_guess "$formula")"
  hist_count="${HIST_FREQ[$cmd_guess]:-0}"
  last_epoch="${HIST_LAST_EPOCH[$cmd_guess]:-0}"
  days_since_last_use="-"
  flag="-"
  install_reason="-"
  leaf="-"

  if [ -n "${INSTALLED_FORMULAE[$formula_base]+x}" ]; then
    installed="yes"
    if [ -n "${ON_REQUEST[$formula_base]+x}" ]; then
      install_reason="on_request"
    else
      install_reason="dependency"
    fi

    if [ -n "${LEAVES[$formula_base]+x}" ]; then
      leaf="yes"
    else
      leaf="no"
    fi

    if [ "$last_epoch" -gt 0 ]; then
      days_since_last_use="$(days_since_epoch "$last_epoch")"
      if [ "$days_since_last_use" -ge "$DAYS_UNUSED" ]; then
        flag="review_unused"
      else
        flag="-"
      fi
    elif [ "${HIST_FREQ[$cmd_guess]:-0}" -eq 0 ]; then
      flag="review_zero_history"
    else
      flag="review_unknown_last_use"
    fi

    if [ "$hist_count" -gt 0 ] || [ "$last_epoch" -gt 0 ]; then
      printf "%s\n" "$formula" >>"$tmp_used_formulae"
    fi
  else
    flag="review_not_installed"
  fi

  # Note: we do NOT include needed_by_used here (it's computed after we build the used set).
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$formula" "$installed" "$install_reason" "$leaf" "$cmd_guess" "$hist_count" "$last_epoch" "$days_since_last_use" "$flag" >>"$tmp_formulae"
done < <(extract_formulae)

declare -A NEEDED_BY_USED=()
if [ -s "$tmp_used_formulae" ]; then
  deps_tmp="$(mktemp)"
  trap 'rm -f "$tmp_casks" "$tmp_formulae" "$tmp_used_formulae" "$deps_tmp"' EXIT

  # Take the union of dependencies for used formulae (batch to avoid long argv).
  cat "$tmp_used_formulae" | xargs -n 20 brew deps --installed --full-name --union 2>/dev/null | LC_ALL=C sort -u >"$deps_tmp" || true
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    NEEDED_BY_USED["$dep"]=1
    NEEDED_BY_USED["${dep##*/}"]=1
  done <"$deps_tmp"
fi

tmp_formulae_aug="$(mktemp)"
trap 'rm -f "$tmp_casks" "$tmp_formulae" "$tmp_used_formulae" "$tmp_formulae_aug"' EXIT

while IFS=$'\t' read -r formula installed install_reason leaf cmd_guess hist_count last_epoch days_since_last_use flag; do
  formula_base="${formula##*/}"
  needed_by_used="no"
  if [ "$installed" = "yes" ]; then
    if [ "$hist_count" -gt 0 ] || [ "${last_epoch:-0}" -gt 0 ] 2>/dev/null; then
      needed_by_used="yes"
    elif [ -n "${NEEDED_BY_USED[$formula]+x}" ] || [ -n "${NEEDED_BY_USED[$formula_base]+x}" ]; then
      needed_by_used="yes"
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$formula" "$installed" "$install_reason" "$leaf" "$needed_by_used" "$cmd_guess" "$hist_count" "$last_epoch" "$days_since_last_use" "$flag" >>"$tmp_formulae_aug"
done <"$tmp_formulae"

cat "$tmp_formulae_aug" | LC_ALL=C sort -t $'\t' -k9,9nr -k7,7nr -k1,1

echo
echo "# Notes"
echo "# - Cask usage uses Spotlight metadata (mdls). Some apps may not update usage reliably."
echo "# - Formula usage is a heuristic based on a guessed primary command and ~/.zsh_history."
echo "# - If your ~/.zsh_history doesn't include timestamps, formula last-used may be blank."
echo "# - Review flags are suggestions only; confirm before removing anything from Brewfile."
