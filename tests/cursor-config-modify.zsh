#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# An empty .toml config isolates from this host's chezmoi config; machine_type
# is pinned per render via --override-data (ADR 0012 features.tmpl convention).
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

render() {  # render <machine_type> <home-relative tmpl path>
  chezmoi --source "$REPO_ROOT/home" --config "$empty_config" \
    --override-data "{\"machine_type\":\"$1\"}" \
    execute-template --file "$REPO_ROOT/home/$2"
}

modify="$tmp_root/modify_cursor.py"
render work dot_cursor/modify_private_cli-config.json.tmpl >"$modify"
chmod +x "$modify"

# Cursor keeps auth, model, approval, and team state in this same file. A full
# rewrite would log the CLI out, so every unrelated key has to survive.
current="$tmp_root/current.json"
cat >"$current" <<'JSON'
{
  "authInfo": {"token": "secret-abc"},
  "model": {"modelId": "gpt-5.6-sol"},
  "permissions": {"allow": ["Read"]},
  "marketplaces": {"other": {"source": "github", "path": "x"}}
}
JSON
merged="$tmp_root/merged.json"
"$modify" <"$current" >"$merged"
python3 - "$merged" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["authInfo"]["token"] == "secret-abc", d
assert d["model"]["modelId"] == "gpt-5.6-sol", d
assert d["permissions"]["allow"] == ["Read"], d
assert d["marketplaces"]["other"]["source"] == "github", d
local = d["marketplaces"]["prateek-local"]
assert local["source"] == "directory", d
assert local["path"].endswith("/.agents/plugins"), d
PY

again="$tmp_root/again.json"
"$modify" <"$merged" >"$again"
cmp -s "$merged" "$again" || { echo "FAIL: modify is not idempotent" >&2; exit 1; }

# A file Cursor wrote that already carries the marketplace is echoed unchanged,
# so apply never churns Cursor's own formatting.
cursor_style="$tmp_root/cursor-style.json"
render work .chezmoitemplates/cursor-cli-config-managed.json.tmpl \
  | python3 -c 'import json,sys; sys.stdout.write(json.dumps(json.load(sys.stdin)))' \
  >"$cursor_style"
cursor_out="$tmp_root/cursor-style-out.json"
"$modify" <"$cursor_style" >"$cursor_out"
cmp -s "$cursor_style" "$cursor_out" || { echo "FAIL: correct file not preserved byte-for-byte" >&2; exit 1; }

# A deleted config is rebuilt rather than left empty; that is the recovery path.
empty_in="$tmp_root/empty-in"
: >"$empty_in"
"$modify" <"$empty_in" | python3 -c '
import sys, json
d = json.load(sys.stdin)
assert set(d) == {"marketplaces"}, d
assert d["marketplaces"]["prateek-local"]["source"] == "directory", d
'

# Machines without cursor-agent must not have the file conjured for them.
if ! render personal .chezmoiignore | grep -qx '.cursor/cli-config.json'; then
  echo "FAIL: .cursor/cli-config.json not ignored without cursor-agent" >&2
  exit 1
fi
if render work .chezmoiignore | grep -qx '.cursor/cli-config.json'; then
  echo "FAIL: .cursor/cli-config.json ignored on a cursor-agent machine" >&2
  exit 1
fi

# The work machine type lists cursor-agent, but the headless Linux profile runs
# Claude only, so agent_clis alone would hand the DevPod a config it never uses.
headless="$(chezmoi --source "$REPO_ROOT/home" --config "$empty_config" \
  --override-data '{"machine_type":"work","chezmoi":{"os":"linux"}}' \
  execute-template --file "$REPO_ROOT/home/.chezmoiignore")"
if ! print -r -- "$headless" | grep -qx '.cursor/cli-config.json'; then
  echo "FAIL: .cursor/cli-config.json not ignored on the headless Linux profile" >&2
  exit 1
fi

echo "ok: cursor cli-config modify (marketplace merged, auth/model/permissions preserved, idempotent, no-churn, rebuilt from empty, gated by agent_clis)"
