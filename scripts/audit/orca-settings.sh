#!/usr/bin/env bash
# Detect when the tracked Orca settings drift from Orca's current built-in
# defaults (something chezmoi can't see). Refreshes the committed defaults
# snapshot, whose git diff shows what an Orca upgrade moved.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="/Applications/Orca.app"
ASAR="$APP/Contents/Resources/app.asar"
EXTRACTOR="$REPO_ROOT/scripts/audit/orca-extract-defaults.mjs"
SNAPSHOT="$REPO_ROOT/scripts/audit/orca-defaults.snapshot.json"
STUB="$REPO_ROOT/home/Library/Application Support/orca/modify_orca-data.json.tmpl"
LIVE="$HOME/Library/Application Support/orca/orca-data.json"

if [[ ! -f "$ASAR" ]]; then
  echo "orca-settings audit: Orca not installed ($ASAR missing); skipping." >&2
  exit 0
fi
for bin in node npx chezmoi python3 uv; do
  command -v "$bin" >/dev/null || { echo "orca-settings audit: '$bin' not found on PATH." >&2; exit 2; }
done

version="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

( cd "$tmp" && npx --yes @electron/asar extract-file "$ASAR" out/main/index.js ) >/dev/null
[[ -f "$tmp/index.js" ]] || { echo "orca-settings audit: failed to extract out/main/index.js from $ASAR" >&2; exit 1; }
node "$EXTRACTOR" "$tmp/index.js" "$HOME" >"$tmp/defaults.json"

python3 - "$tmp/defaults.json" "$version" "$SNAPSHOT" <<'PY'
import json, sys
defaults = json.load(open(sys.argv[1]))
snapshot = {"orcaVersion": sys.argv[2], "platform": "darwin", "settings": defaults}
with open(sys.argv[3], "w") as f:
    json.dump(snapshot, f, indent=2, sort_keys=True)
    f.write("\n")
PY

# Desired = base + this machine's overlay, produced by running the stub on `{}`.
render="$tmp/modify.py"
chezmoi --source "$REPO_ROOT/home" execute-template --file "$STUB" >"$render"
chmod +x "$render"
printf '{}' | "$render" >"$tmp/desired.json"

python3 - "$tmp/defaults.json" "$tmp/desired.json" "$LIVE" <<'PY'
import json, sys

defaults = json.load(open(sys.argv[1]))
desired = json.load(open(sys.argv[2])).get("settings", {})
try:
    live = json.load(open(sys.argv[3])).get("settings", {})
except FileNotFoundError:
    live = None

# Keys we intentionally don't track (markers, stale defaults, app state); the
# audit must not flag them as untracked divergence.
DENYLIST = {
    "agentDefaultArgs", "sourceControlAi", "localBaseRefSuggestionDismissed",
    "openLinksInAppPreferencePrompted", "terminalMacOptionAsAltMigrated",
    "voice", "visibleTaskProviders",
}

fragment = set(desired)
untracked, redundant, stale, live_drift = {}, {}, [], {}
app_added = 0

for k in sorted(desired):
    if k not in defaults:
        stale.append(k)
    elif desired[k] == defaults[k]:
        redundant[k] = desired[k]

if live is not None:
    for k in sorted(live):
        if k in defaults and live[k] != defaults[k] and k not in fragment and k not in DENYLIST:
            untracked[k] = live[k]
        if k not in defaults and k not in fragment:
            app_added += 1
    for k in sorted(fragment):
        cur = live.get(k, defaults.get(k))  # absent from live == Orca's default
        if cur != desired[k]:
            live_drift[k] = {"live": cur, "fragment": desired[k]}

def section(title, body):
    print(f"\n=== {title} ===")
    print(body if body else "  (none)")

print(f"Orca settings audit — {len(fragment)} tracked, {len(defaults)} defaults"
      + ("" if live is not None else "  [live orca-data.json not found]"))

section("Untracked divergence (live differs from default, not tracked) — ADD to an overlay/base",
        "\n".join(f"  {json.dumps({k: v})}" for k, v in untracked.items()))
section("Redundant tracked (fragment value equals current default) — DROP",
        "\n".join(f"  {k} = {json.dumps(v)}" for k, v in redundant.items()))
section("Stale tracked (key no longer in Orca's schema) — DROP",
        "\n".join(f"  {k}" for k in stale))
if live is not None:
    section("Live differs from tracked — `chezmoi apply` (Orca quit) to push, or reconcile",
            "\n".join(f"  {k}: live={json.dumps(v['live'])} fragment={json.dumps(v['fragment'])}" for k, v in live_drift.items()))
    print(f"\n(app-added keys outside Orca's defaults schema, ignored: {app_added})")

actionable = len(untracked) + len(redundant) + len(stale) + len(live_drift)
print(f"\nActionable drift: {actionable}")
sys.exit(1 if actionable else 0)
PY
