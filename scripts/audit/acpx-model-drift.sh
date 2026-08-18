#!/usr/bin/env bash
# Check the cursor-agent model ids pinned in the acpx config template against
# the live `cursor-agent --list-models` catalog. cursor-agent has no
# latest-tracking aliases, so pins go stale; this flags pins the catalog no
# longer offers and newer generations in the same model family.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ACPX_TEMPLATE="${ACPX_TEMPLATE:-$REPO_ROOT/home/dot_acpx/config.json.tmpl}"

if [ ! -f "$ACPX_TEMPLATE" ]; then
  echo "acpx config template not found: $ACPX_TEMPLATE" >&2
  exit 1
fi

pins="$(sed -nE 's/.*"--model" "([^"]+)".*/\1/p' "$ACPX_TEMPLATE")"
if [ -z "$pins" ]; then
  echo "No pinned --model ids found in $ACPX_TEMPLATE" >&2
  exit 1
fi

# Exposes the pin extraction so the regression test can exercise this
# script's own parsing instead of a copy of the sed above.
if [ "${1:-}" = "--print-pins" ]; then
  printf '%s\n' "$pins"
  exit 0
fi

if ! command -v cursor-agent >/dev/null 2>&1; then
  echo "cursor-agent not found. Install it first (its own installer, not mise)." >&2
  exit 1
fi

# Catalog lines look like `gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast`;
# keep the id, drop the header and trailing tip lines.
catalog="$(cursor-agent --list-models | sed -nE 's/^([a-z0-9][a-z0-9.-]*) - .*/\1/p')"
if [ -z "$catalog" ]; then
  echo "Could not parse any model ids from cursor-agent --list-models" >&2
  exit 1
fi

# Splits an id into family-version-tier, e.g.
#   claude-opus-5-thinking-xhigh-fast -> claude-opus / 5 / thinking-xhigh-fast
#   gpt-5.6-sol-high-fast             -> gpt / 5.6 / sol-high-fast
id_re='([a-z][a-z-]*)-([0-9][0-9.-]*)-(.+)'

# One pass over the catalog into `id|family|version|tier` lines. Ids without
# a version+tier (e.g. `auto`, `gpt-5.2`) drop out here but stay in $catalog
# for the existence check.
catalog_parsed="$(sed -nE "s/^(${id_re})\$/\\1|\\2|\\3|\\4/p" <<<"$catalog")"

status=0

for pin in $pins; do
  if ! grep -qxF "$pin" <<<"$catalog"; then
    echo "STALE: $pin is pinned but no longer in the cursor-agent catalog"
    status=1
    continue
  fi

  parsed="$(sed -nE "s/^${id_re}\$/\\1|\\2|\\3/p" <<<"$pin")"
  [ -n "$parsed" ] || continue
  IFS='|' read -r pin_family pin_version pin_tier <<<"$parsed"
  pin_tail="${pin_tier##*-}"
  pv="${pin_version//-/.}"

  # Warn when the catalog has a strictly newer version in the same family.
  # Tier matching is deliberately loose — only the last token (fast/pro/...)
  # must agree. Tier names drift across generations (gpt-5.5's "extra-high"
  # became 5.6's "xhigh"), so exact-tier matching would go silent right when
  # the catalog moves; the cost is cross-tier hints (a newer xhigh-fast id
  # flags a high-fast pin), acceptable for a warning. The last token still
  # keeps e.g. gemini-*-flash ids from matching a gemini-*-pro pin.
  newer=""
  while IFS='|' read -r cid cfamily cversion ctier; do
    [ -n "$cid" ] && [ "$cid" != "$pin" ] || continue
    [ "$cfamily" = "$pin_family" ] || continue
    [ "${ctier##*-}" = "$pin_tail" ] || continue
    cv="${cversion//-/.}"
    [ "$cv" = "$pv" ] && continue
    if [ "$(printf '%s\n%s\n' "$pv" "$cv" | sort -V | tail -1)" = "$cv" ]; then
      newer="$newer $cid"
    fi
  done <<<"$catalog_parsed"

  if [ -n "$newer" ]; then
    echo "NEWER: $pin has newer $pin_family options:$newer"
    status=1
  else
    echo "ok: $pin"
  fi
done

exit "$status"
