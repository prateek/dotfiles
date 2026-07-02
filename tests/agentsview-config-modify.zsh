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
  --file "$REPO_ROOT/home/dot_agentsview/modify_private_config.toml.tmpl" \
  >"$script"
chmod +x "$script"

cat >"$current" <<'TOML'
auth_token = "secret-token"
cursor_secret = "secret-cursor"
custom_key = "keep-me"
TOML

"$script" <"$current" >"$merged"

python3 - "$merged" <<PY
import sys
import tomllib
import os

path = sys.argv[1]
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
PY

# Idempotent: re-running against already-merged output must not change a byte.
"$script" <"$merged" >"$semantic_merged"
cmp -s "$merged" "$semantic_merged"

# From-scratch: config.toml does not exist yet (agentsview never launched).
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
