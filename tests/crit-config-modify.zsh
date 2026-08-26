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

# --- 1. modify_private_dot_crit.config.json: set agent_cmd, preserve crit's keys ---
modify="$tmp_root/modify_crit.py"
render personal modify_private_dot_crit.config.json.tmpl >"$modify"
chmod +x "$modify"

# crit writes auth_token/share_consented/auth_user_* to this file; a non-ASCII
# author name and an unmanaged key must survive the merge untouched.
current="$tmp_root/current.json"
cat >"$current" <<'JSON'
{
  "auth_token": "secret-abc",
  "share_consented": true,
  "auth_user_name": "Prätéek",
  "port": 3456,
  "custom_key": "keep-me"
}
JSON
merged="$tmp_root/merged.json"
"$modify" <"$current" >"$merged"
python3 - "$merged" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["agent_cmd"] == "claude --dangerously-skip-permissions -p", d
assert d["auth_token"] == "secret-abc", d
assert d["share_consented"] is True, d
assert d["auth_user_name"] == "Prätéek", d
assert d["port"] == 3456 and d["custom_key"] == "keep-me", d
PY
grep -qF 'Prätéek' "$merged" || { echo "FAIL: non-ASCII author not preserved (ensure_ascii)" >&2; exit 1; }

# Idempotent, and a file crit wrote (compact, correct agent_cmd) is preserved
# byte-for-byte so chezmoi apply never churns crit's own writes.
again="$tmp_root/again.json"
"$modify" <"$merged" >"$again"
cmp -s "$merged" "$again" || { echo "FAIL: modify is not idempotent" >&2; exit 1; }
crit_style="$tmp_root/crit-style.json"
printf '{"auth_token":"x","agent_cmd":"claude --dangerously-skip-permissions -p"}' >"$crit_style"
crit_out="$tmp_root/crit-style-out.json"
"$modify" <"$crit_style" >"$crit_out"
cmp -s "$crit_style" "$crit_out" || { echo "FAIL: correct-agent_cmd file not preserved byte-for-byte" >&2; exit 1; }

# A stale agent_cmd (e.g. the retired crit-agent bridge) is rewritten in place.
printf '{"auth_token":"x","agent_cmd":"crit-agent {prompt}"}' | "$modify" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["agent_cmd"] == "claude --dangerously-skip-permissions -p", d
assert d["auth_token"] == "x", d
'

# From-scratch: config does not exist yet (crit never launched).
empty_in="$tmp_root/empty.json"; : >"$empty_in"
scratch="$tmp_root/scratch.json"
"$modify" <"$empty_in" >"$scratch"
python3 - "$scratch" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert list(d.keys()) == ["agent_cmd"], d
assert d["agent_cmd"] == "claude --dangerously-skip-permissions -p", d
PY

# ci (no claude in agent_clis): a stale agent_cmd is removed, other keys
# survive, and a machine with no config never materializes one.
modify_ci="$tmp_root/modify_crit_ci.py"
render ci modify_private_dot_crit.config.json.tmpl >"$modify_ci"
chmod +x "$modify_ci"
printf '{"auth_token":"x","agent_cmd":"crit-agent {prompt}"}' | "$modify_ci" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "agent_cmd" not in d, d
assert d["auth_token"] == "x", d
'
[[ -z "$("$modify_ci" <"$empty_in")" ]] || { echo "FAIL: ci modify materialized a stub config" >&2; exit 1; }

# --- 2. acpx config.json.tmpl: shortcuts gated by machine agent_clis ---
# work (cursor-agent + claude): all seven shortcuts; agpt rides cursor-agent.
render work dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agptx","aopus","aopusx","agemini","afable","afablex"}, sorted(d)
assert d["agpt"]["command"] == "cursor-agent", d["agpt"]
'
# personal (claude + codex): GPT tiers ride the Codex adapter; afable* via claude.
render personal dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agptx","afable","afablex"}, sorted(d)
assert d["agpt"]["command"] == "codex-acp", d["agpt"]
'
# ci (no agent_clis): empty agents map.
render ci dot_acpx/config.json.tmpl | python3 -c '
import sys, json
assert json.load(sys.stdin)["agents"] == {}, "ci should emit no shortcuts"
'

echo "ok: crit config modify (agent_cmd set on claude machines, removed on ci, secrets preserved, idempotent, no-churn); acpx gating by agent_clis (work/personal/ci)"
