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
chezmoi --source "$REPO_ROOT/home" --config "$empty_config" \
  execute-template --file "$REPO_ROOT/home/modify_private_dot_crit.config.json.tmpl" >"$modify"
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
assert d["agent_cmd"] == "crit-agent {prompt}", d
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
printf '{"auth_token":"x","agent_cmd":"crit-agent {prompt}"}' >"$crit_style"
crit_out="$tmp_root/crit-style-out.json"
"$modify" <"$crit_style" >"$crit_out"
cmp -s "$crit_style" "$crit_out" || { echo "FAIL: correct-agent_cmd file not preserved byte-for-byte" >&2; exit 1; }

# From-scratch: config does not exist yet (crit never launched).
empty_in="$tmp_root/empty.json"; : >"$empty_in"
scratch="$tmp_root/scratch.json"
"$modify" <"$empty_in" >"$scratch"
python3 - "$scratch" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert list(d.keys()) == ["agent_cmd"], d
assert d["agent_cmd"] == "crit-agent {prompt}", d
PY

# --- 2. acpx config.json.tmpl: shortcuts gated by machine agent_clis ---
# work (cursor-agent + claude): all seven shortcuts; agpt rides cursor-agent.
render work dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agpt-extra","aopus","aopus-max","agemini","afable","afable-max"}, sorted(d)
assert d["agpt"]["command"] == "cursor-agent", d["agpt"]
'
# personal (claude + codex): GPT tiers ride the Codex adapter; afable* via claude.
render personal dot_acpx/config.json.tmpl | python3 -c '
import sys, json
d = json.load(sys.stdin)["agents"]
assert set(d) == {"agpt","agpt-extra","afable","afable-max"}, sorted(d)
assert d["agpt"]["command"] == "codex-acp", d["agpt"]
'
# ci (no agent_clis): empty agents map.
render ci dot_acpx/config.json.tmpl | python3 -c '
import sys, json
assert json.load(sys.stdin)["agents"] == {}, "ci should emit no shortcuts"
'

# --- 3. crit-agent wrapper (templated per machine): resolution + reply-only flags ---
# Stub acpx echoes its argv so we can read the chosen model and the flags.
stub_dir="$tmp_root/bin"; mkdir -p "$stub_dir"
cat >"$stub_dir/acpx" <<'SH'
#!/usr/bin/env bash
echo "$*"
SH
chmod +x "$stub_dir/acpx"

render_wrapper() {  # render_wrapper <machine_type> -> path to rendered script
  local out="$tmp_root/crit-agent-$1"
  render "$1" dot_local/bin/executable_crit-agent.tmpl >"$out"
  chmod +x "$out"
  print -r -- "$out"
}
pick() { env -i PATH="$stub_dir:/usr/bin:/bin" HOME="$tmp_root" ${(z)2} bash "$1" "a prompt" 2>&1; }
model_of() { local out; out="$(pick "$1" "$2")"; print -r -- "${${out%% exec*}##* }"; }

# work bridges via cursor-agent: GPT contrast = agpt, Claude = aopus.
work_w="$(render_wrapper work)"
[[ "$(model_of "$work_w" 'CRIT_AGENT_MODEL=agemini CLAUDECODE=1')" == "agemini" ]] || { echo "FAIL: work CRIT_AGENT_MODEL override" >&2; exit 1; }
[[ "$(model_of "$work_w" 'CLAUDECODE=1')"           == "agpt"  ]] || { echo "FAIL: work CLAUDECODE -> agpt" >&2; exit 1; }
[[ "$(model_of "$work_w" 'AI_AGENT=codex_9')"       == "aopus" ]] || { echo "FAIL: work codex launcher -> aopus" >&2; exit 1; }
[[ "$(model_of "$work_w" 'AI_AGENT=claude-code_2')" == "agpt"  ]] || { echo "FAIL: work claude launcher -> agpt" >&2; exit 1; }

# personal has no cursor-agent: GPT rides the Codex adapter under the agpt name,
# Claude = afable. The GPT target is agpt on every machine.
personal_w="$(render_wrapper personal)"
[[ "$(model_of "$personal_w" 'CLAUDECODE=1')"           == "agpt"   ]] || { echo "FAIL: personal CLAUDECODE -> agpt" >&2; exit 1; }
[[ "$(model_of "$personal_w" 'AI_AGENT=codex_9')"       == "afable" ]] || { echo "FAIL: personal codex launcher -> afable" >&2; exit 1; }
[[ "$(model_of "$personal_w" 'AI_AGENT=claude-code_2')" == "agpt"   ]] || { echo "FAIL: personal claude launcher -> agpt" >&2; exit 1; }
# CODEX_HOME is ambient; no signal falls to the machine default (agpt on personal).
[[ "$(model_of "$personal_w" 'CODEX_HOME=/x')"          == "agpt"   ]] || { echo "FAIL: personal no-signal -> agpt default" >&2; exit 1; }

# Reply-only: the flags that deny writes without hanging are always present.
flags="$(pick "$work_w" 'CLAUDECODE=1')"
[[ "$flags" == *"--no-terminal"* ]] || { echo "FAIL: --no-terminal missing" >&2; exit 1; }
[[ "$flags" == *"--non-interactive-permissions deny"* ]] || { echo "FAIL: --non-interactive-permissions deny missing" >&2; exit 1; }
[[ "$flags" == *"--format quiet"* ]] || { echo "FAIL: --format quiet missing" >&2; exit 1; }

# Fail closed: a machine with no agent CLIs (ci) can't dispatch and says so.
ci_w="$(render_wrapper ci)"
if out="$(pick "$ci_w" '')"; then echo "FAIL: ci wrapper should exit non-zero" >&2; exit 1; fi
[[ "$out" == *"no acpx agent"* ]] || { echo "FAIL: ci wrapper missing fail-closed message" >&2; exit 1; }

echo "ok: crit config modify (agent_cmd, secrets preserved, idempotent, no-churn); acpx gating by agent_clis (work/personal/ci); templated wrapper resolution per machine + reply-only flags + fail-closed"
