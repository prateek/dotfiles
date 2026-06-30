#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

work_script="$tmp_root/modify_work.py"
homelab_script="$tmp_root/modify_homelab.py"
ci_script="$tmp_root/modify_ci.py"
current="$tmp_root/current.json"
merged="$tmp_root/merged.json"
idempotent="$tmp_root/idempotent.json"
empty_in="$tmp_root/empty.json"
empty_out="$tmp_root/empty-out.json"
homelab_out="$tmp_root/homelab-out.json"
ci_out="$tmp_root/ci-out.json"

# machine_type is pinned per render via --override-data; an empty --config
# isolates from this host's chezmoi config (ADR 0012 features.tmpl convention).
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

render() {
  chezmoi \
    --source "$REPO_ROOT/home" \
    --config "$empty_config" \
    --override-data "{\"machine_type\":\"$1\"}" \
    execute-template \
    --file "$REPO_ROOT/home/Library/Application Support/orca/modify_orca-data.json.tmpl" \
    >"$2"
  chmod +x "$2"
}

render work "$work_script"
render homelab "$homelab_script"
render ci "$ci_script"

# A managed setting at a non-target value, an unmanaged setting, and the churny
# state Orca rewrites: the merge must enforce managed keys and leave the rest.
cat >"$current" <<'JSON'
{
  "schemaVersion": 1,
  "repos": [
    { "id": "abc", "path": "/Users/prungta/code/repo", "displayName": "repo" }
  ],
  "worktreeMeta": { "abc::/tmp/wt": { "comment": "keep me" } },
  "settings": {
    "theme": "system",
    "terminalFontFamily": "SF Mono",
    "disabledTuiAgents": [],
    "terminalShortcutPolicy": "orca-first",
    "userOnlyPreference": "untouched"
  },
  "workspaceSession": { "activeRepoId": "abc" }
}
JSON

"$work_script" <"$current" >"$merged"

python3 - "$merged" <<'PY'
import json, os, sys

data = json.load(open(sys.argv[1]))
s = data["settings"]

assert s["theme"] == "dark", s["theme"]
assert s["terminalFontFamily"] == "JetBrains Mono", s["terminalFontFamily"]
assert s["terminalShortcutPolicy"] == "terminal-first", s["terminalShortcutPolicy"]
assert s["setupScriptLaunchMode"] == "split-horizontal", s["setupScriptLaunchMode"]
assert s["terminalScrollbackBytes"] == 25000000, s["terminalScrollbackBytes"]
assert s["defaultTuiAgent"] == "claude", s["defaultTuiAgent"]
assert s["workspaceDir"].endswith("/code/worktrees"), s["workspaceDir"]
assert os.path.isabs(s["workspaceDir"]), s["workspaceDir"]

assert {a["command"] for a in s["openInApplications"]} == {"cursor", "code"}
assert [q["label"] for q in s["terminalQuickCommands"]] == ["Open in Finder", "Open in Cursor", "Open in VS Code"]
assert s["disabledTuiAgents"] == ["codex"], s["disabledTuiAgents"]

assert s["userOnlyPreference"] == "untouched", s
assert data["schemaVersion"] == 1
assert data["repos"][0]["id"] == "abc"
assert data["worktreeMeta"]["abc::/tmp/wt"]["comment"] == "keep me"
assert data["workspaceSession"]["activeRepoId"] == "abc"
PY

"$work_script" <"$merged" >"$idempotent"
cmp -s "$merged" "$idempotent" || { echo "FAIL: merge is not idempotent" >&2; exit 1; }

cat >"$empty_in" <<'JSON'
{ "schemaVersion": 1, "repos": [] }
JSON
"$work_script" <"$empty_in" >"$empty_out"
python3 - "$empty_out" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["settings"]["theme"] == "dark"
assert data["settings"]["disabledTuiAgents"] == ["codex"]
assert data["repos"] == []
PY

"$homelab_script" <"$current" >"$homelab_out"
python3 - "$homelab_out" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["settings"]
assert s["disabledTuiAgents"] == ["claude-agent-teams"], s["disabledTuiAgents"]
assert s["defaultTuiAgent"] == "codex", s["defaultTuiAgent"]
assert s["theme"] == "dark"
assert s["terminalShortcutPolicy"] == "terminal-first"
PY

# A machine_type with no overlay (ci) renders base only — no hard fail, no
# host-specific key.
"$ci_script" <"$empty_in" >"$ci_out"
python3 - "$ci_out" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["settings"]
assert "disabledTuiAgents" not in s, s.get("disabledTuiAgents")
assert s["defaultTuiAgent"] == "codex", s["defaultTuiAgent"]
assert s["theme"] == "dark"
PY

echo "ok: orca settings modify (base+overlay merge, passthrough, idempotence, machine_type, no-overlay)"
