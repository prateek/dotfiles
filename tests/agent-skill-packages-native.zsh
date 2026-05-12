#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

cd "$REPO_ROOT"

plugins_root="$tmp_root/.agents/plugins"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$plugins_root" \
  --skip-config-templates

if command -v claude >/dev/null 2>&1; then
  claude plugin validate "$plugins_root"
else
  print -u2 "skip: claude CLI is not available"
fi

if command -v codex >/dev/null 2>&1; then
  python3 - "$plugins_root/marketplace.json" <<'PY'
import json
import select
import subprocess
import sys
import time

marketplace_path = sys.argv[1]
with open(marketplace_path) as handle:
    marketplace = json.load(handle)

plugin_name = marketplace["plugins"][0]["name"]
proc = subprocess.Popen(
    ["codex", "app-server", "--listen", "stdio://"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
)
next_id = 0


def request(method, params, timeout=10):
    global next_id
    next_id += 1
    proc.stdin.write(json.dumps({"id": next_id, "method": method, "params": params}) + "\n")
    proc.stdin.flush()
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], 0.2)
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            break
        message = json.loads(line)
        if message.get("id") == next_id:
            return message
    raise AssertionError(f"timed out waiting for response {next_id}")

try:
    request(
        "initialize",
        {
            "clientInfo": {
                "name": "agent-skill-packages-native",
                "title": None,
                "version": "0",
            },
            "capabilities": {"experimentalApi": True},
        },
    )
    response = request(
        "plugin/read",
        {
            "marketplacePath": marketplace_path,
            "remoteMarketplaceName": None,
            "pluginName": plugin_name,
        },
    )
    if "error" in response:
        raise AssertionError(response["error"])
    assert response["result"]["plugin"]["skills"], response
finally:
    try:
        proc.stdin.close()
    except Exception:
        pass
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
PY
else
  print -u2 "skip: codex CLI is not available"
fi
