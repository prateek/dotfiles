#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BREWFILE="${BREWFILE:-}"
BREWFILE_PROFILE="${BREWFILE_PROFILE:-full}"

if [ -n "$BREWFILE" ] && [ ! -f "$BREWFILE" ]; then
  echo "Package manifest not found: $BREWFILE" >&2
  exit 1
fi

render_brewfile() {
  if [ -n "$BREWFILE" ]; then
    cat "$BREWFILE"
  else
    "$REPO_ROOT/bin/dotfiles" render brewfile --profile "$BREWFILE_PROFILE"
  fi
}

brewfile_label() {
  if [ -n "$BREWFILE" ]; then
    echo "$BREWFILE"
  else
    echo "packages.toml profile '$BREWFILE_PROFILE'"
  fi
}

extract_casks() {
  render_brewfile | sed -n 's/^cask "\([^"]*\)".*/\1/p'
}

coverage_for() {
  uv run --quiet --python '>=3.11' python - "$REPO_ROOT" "$1" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
cask = sys.argv[2]

def chezmoi_source_for_target(target):
    if target.startswith("/"):
        return None
    encoded_parts = [
        f"dot_{part.removeprefix('.')}" if part.startswith(".") else part
        for part in target.split("/")
    ]
    return root / "home" / pathlib.Path(*encoded_parts)

def source_path(item):
    source = item.get("source")
    if source:
        return root / source
    src = chezmoi_source_for_target(item.get("path", ""))
    if src and not src.exists():
        tmpl = pathlib.Path(str(src) + ".tmpl")
        if tmpl.exists():
            return tmpl
    return src

apps_root = root / "home/.chezmoidata/apps"
app_paths = {}
for candidate in sorted(apps_root.glob("*.toml")):
    data = tomllib.loads(candidate.read_text())
    for candidate_id, app in data.get("apps", {}).items():
        if app.get("cask"):
            app_paths[app["cask"]] = (candidate_id, candidate, app)

if cask not in app_paths:
    print("no\tno\t-")
    raise SystemExit

app_id, path, app = app_paths[cask]
where = [str(path.relative_to(root))]
repo_artifact = False

for item in app.get("files", []):
    where.append(f"file:{item.get('path', '-')}")
    src = source_path(item)
    if src and src.exists():
        repo_artifact = True

defaults = app.get("defaults", {})
if isinstance(defaults, list):
    for item in defaults:
        where.append(f"defaults:{item.get('domain', '-')}:{item.get('key', '-')}")
else:
    for domain, values in defaults.items():
        for key in values:
            where.append(f"defaults:{domain}:{key}")

for item in app.get("policies", {}).values():
    if item:
        where.append("policy:data")

print(f"yes\t{'yes' if repo_artifact else 'no'}\t{' | '.join(where)}")
PY
}

echo "# App config coverage (tracked in this repo)"
echo "# Source: $(brewfile_label)"
echo

targets=()
if [ "$#" -gt 0 ]; then
  targets=("$@")
else
  mapfile -t targets < <(extract_casks)
fi

printf "cask\tconfigured\trepo_artifact\twhere\n"
for cask in "${targets[@]}"; do
  coverage="$(coverage_for "$cask")"
  printf "%s\t%s\n" "$cask" "$coverage"
done | LC_ALL=C sort -t $'\t' -k2,2r -k1,1

echo
echo "# Notes"
echo "# - configured=yes means this repo has app config for an installed cask."
echo "# - repo_artifact=yes means a configured file or directory exists under home/."
