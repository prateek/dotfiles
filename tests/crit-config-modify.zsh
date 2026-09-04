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
assert d["open_cmd"].endswith("/.local/bin/crit-open"), d
assert d["notify_on_round_ready"] is True, d
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
printf '{"auth_token":"x"}' | "$modify" >"$crit_style"
crit_out="$tmp_root/crit-style-out.json"
"$modify" <"$crit_style" >"$crit_out"
cmp -s "$crit_style" "$crit_out" || { echo "FAIL: already-correct file not preserved byte-for-byte" >&2; exit 1; }

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
assert sorted(d) == ["agent_cmd", "notify_on_round_ready", "open_cmd"], d
assert d["agent_cmd"] == "claude --dangerously-skip-permissions -p", d
PY

# ci (no claude in agent_clis): a stale agent_cmd is removed, other keys
# survive, and a machine with no config never materializes one.
modify_ci="$tmp_root/modify_crit_ci.py"
render ci modify_private_dot_crit.config.json.tmpl >"$modify_ci"
chmod +x "$modify_ci"
printf '{"auth_token":"x","agent_cmd":"crit-agent {prompt}","open_cmd":"/stale","notify_on_round_ready":true}' | "$modify_ci" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "agent_cmd" not in d, d
assert "open_cmd" not in d, d
assert "notify_on_round_ready" not in d, d
assert d["auth_token"] == "x", d
'
[[ -z "$("$modify_ci" <"$empty_in")" ]] || { echo "FAIL: ci modify materialized a stub config" >&2; exit 1; }

# --- 2. acpx config.json.tmpl: shortcuts gated by machine agent_clis ---
# work (cursor-agent + claude): all eight shortcuts; agpt rides cursor-agent.
render work dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agptw","agptx","aopus","aopusx","agemini","afable","afablex"}, sorted(d)
assert d["agpt"]["command"] == "cursor-agent", d["agpt"]
# cursor-agent takes global flags before the acp subcommand, so argv order is
# load-bearing, and a shortcut that loses --model silently falls back to
# Cursor default.
for name in ("agpt", "agptx", "agptw", "aopus", "aopusx", "agemini"):
    args = d[name]["args"]
    assert args[0] == "--model" and args[1], (name, args)
    assert args[args.index("--add-dir") + 1].endswith("/.agents/plugins"), (name, args)
    assert args[-1] == "acp", (name, args)
'

# The Claude marketplaces root is stat-probed against the apply-time
# filesystem, so drive both branches from a synthetic home. Against this host's
# home only one branch would ever render.
probe_home="$tmp_root/probe-home"
mkdir -p "$probe_home"
render_probe() {  # render_probe -> dot_acpx/config.json.tmpl under $probe_home
  chezmoi --source "$REPO_ROOT/home" --config "$empty_config" \
    --override-data "{\"machine_type\":\"work\",\"chezmoi\":{\"homeDir\":\"$probe_home\"}}" \
    execute-template --file "$REPO_ROOT/home/dot_acpx/config.json.tmpl"
}
render_probe | python3 -c '
import sys, json
args = json.load(sys.stdin)["agents"]["agptw"]["args"]
assert args.count("--add-dir") == 1, args
'
mkdir -p "$probe_home/.claude/plugins/marketplaces"
render_probe | python3 -c '
import sys, json
args = json.load(sys.stdin)["agents"]["agptw"]["args"]
assert args.count("--add-dir") == 2, args
second = args.index("--add-dir", args.index("--add-dir") + 1)
assert args[second + 1].endswith("/.claude/plugins/marketplaces"), args
assert args[-1] == "acp", args
'
# personal (claude + codex): the two Sol tiers ride the Codex adapter; afable*
# via claude. agptw is absent — Codex pins one model, so it has no cheap lane.
render personal dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agptx","afable","afablex"}, sorted(d)
assert d["agpt"]["command"] == "codex-acp", d["agpt"]
'
# homelab (claude + codex, no cursor-agent): same shape as personal — the
# codex package group must ship codex-acp there to back these shortcuts.
render homelab dot_acpx/config.json.tmpl | python3 -c '
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

echo "ok: crit config modify (agent_cmd/open_cmd/notify_on_round_ready set on Orca+claude machines, removed on ci, secrets preserved, idempotent, no-churn); acpx gating by agent_clis (work/personal/homelab/ci)"
