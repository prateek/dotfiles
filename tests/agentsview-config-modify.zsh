#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

script="$tmp_root/modify_agentsview_config.py"
current="$tmp_root/current.toml"
merged="$tmp_root/merged.toml"
semantic_merged="$tmp_root/semantic-merged.toml"

chezmoi \
  --source "$REPO_ROOT/home" \
  execute-template \
  --file "$REPO_ROOT/home/private_dot_agentsview/modify_private_config.toml.tmpl" \
  >"$script"
chmod +x "$script"

# Point the runtime glob at a fixture clone so the machine's real archive
# never leaks into assertions.
fixture_clone="$tmp_root/clone"
mkdir -p "$fixture_clone/sessions/alpha/claude/projects" \
         "$fixture_clone/sessions/alpha/cursor/projects" \
         "$fixture_clone/sessions/beta/claude/projects" \
         "$fixture_clone/sessions/beta/codex/sessions" \
         "$fixture_clone/sessions/selfhost/claude/projects"
export WIKI_SESSIONS_CLONE="$fixture_clone"
export WIKI_SESSIONS_HOST="selfhost"

cat >"$current" <<TOML
auth_token = "secret-token"
cursor_secret = "secret-cursor"
custom_key = "keep-me"

# hand-written entry: buildbox copilot
[[session_sources]]
agent = "copilot"
dir = "/srv/handwritten/copilot"
machine = "buildbox"
TOML

"$script" <"$current" >"$merged"

python3 - "$merged" "$fixture_clone" <<'PY'
import sys
import tomllib
import os

path, clone = sys.argv[1], sys.argv[2]
data = tomllib.loads(open(path, "rb").read().decode())

assert data["auth_token"] == "secret-token", data
assert data["cursor_secret"] == "secret-cursor", data
assert data["custom_key"] == "keep-me", data

home = os.path.expanduser("~")
assert data["codex_sessions_dirs"] == [
    home + "/.codex/sessions",
    home + "/.codex/archived_sessions",
    home + "/Library/Application Support/orca/codex-runtime-home/home/sessions",
    home + "/Library/Application Support/orca-dev/codex-runtime-home/home/sessions",
], data["codex_sessions_dirs"]

sources = data["session_sources"]
# Hand-written entry survives, first.
assert sources[0] == {"agent": "copilot", "dir": "/srv/handwritten/copilot", "machine": "buildbox"}, sources[0]
# Generated entries: sorted hosts, correct agents/machines, self host excluded.
generated = sources[1:]
assert generated == [
    {"agent": "claude", "dir": f"{clone}/sessions/alpha/claude/projects", "machine": "alpha"},
    {"agent": "cursor", "dir": f"{clone}/sessions/alpha/cursor/projects", "machine": "alpha"},
    {"agent": "claude", "dir": f"{clone}/sessions/beta/claude/projects", "machine": "beta"},
    {"agent": "codex", "dir": f"{clone}/sessions/beta/codex/sessions", "machine": "beta"},
], generated
assert not any(e["machine"] == "selfhost" for e in generated), generated
PY

# Hand-written entries survive verbatim, comments included.
grep -q '# hand-written entry: buildbox copilot' "$merged"

# Idempotent: re-running against already-merged output must not change a byte.
"$script" <"$merged" >"$semantic_merged"
cmp -s "$merged" "$semantic_merged"

# A host removed from the clone drops out; stale repo entries are reconciled away.
rm -rf "$fixture_clone/sessions/beta"
pruned="$tmp_root/pruned.toml"
"$script" <"$merged" >"$pruned"
python3 - "$pruned" "$fixture_clone" <<'PY'
import sys
import tomllib

path, clone = sys.argv[1], sys.argv[2]
data = tomllib.loads(open(path, "rb").read().decode())
machines = [e["machine"] for e in data["session_sources"]]
assert machines == ["buildbox", "alpha", "alpha"], machines
PY

# From-scratch: config.toml does not exist yet (agentsview never launched) and
# no clone is present — only the codex key is written.
export WIKI_SESSIONS_CLONE="$tmp_root/no-clone"
empty_current="$tmp_root/empty-current.toml"
empty_merged="$tmp_root/empty-merged.toml"
: >"$empty_current"
"$script" <"$empty_current" >"$empty_merged"
python3 - "$empty_merged" <<'PY'
import sys
import tomllib

data = tomllib.loads(open(sys.argv[1], "rb").read().decode())
assert list(data.keys()) == ["codex_sessions_dirs"], data
PY

# Parity: the wiki repo's sync-sessions must generate identical entries from
# the same fixture, compared through each script's --print-session-sources
# seam. Skipped when the clone (with the script) isn't present.
wiki_script="$HOME/code/github.com/prateek/wiki-agent-sessions/.agents/skills/session-sync/scripts/sync-sessions"
if [[ -x "$wiki_script" ]] && command -v uv >/dev/null 2>&1; then
  mkdir -p "$fixture_clone/sessions/beta/claude/projects" "$fixture_clone/sessions/beta/codex/sessions"
  a="$("$script" --print-session-sources "$fixture_clone" selfhost </dev/null)"
  b="$("$wiki_script" --print-session-sources "$fixture_clone" selfhost)"
  [[ "$a" == "$b" ]] || { print -u2 "generator drift:\nmodify: $a\nwiki:   $b"; exit 1; }
else
  echo "agentsview-config: parity check skipped (wiki clone not present)"
fi

echo "agentsview-config-modify: OK"
