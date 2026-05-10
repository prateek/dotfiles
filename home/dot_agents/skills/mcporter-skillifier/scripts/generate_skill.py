#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any


def _normalize_skill_name(name: str) -> str:
    normalized = name.strip().lower()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
    normalized = normalized.strip("-")
    normalized = re.sub(r"-{2,}", "-", normalized)
    if not normalized or not re.fullmatch(r"[a-z0-9-]{1,64}", normalized):
        raise ValueError(f"Invalid skill name after normalization: {normalized!r}")
    return normalized


def _title_case(name: str) -> str:
    return " ".join(part.capitalize() for part in name.split("-") if part)


def _parse_kv_pairs(pairs: list[str]) -> dict[str, str]:
    env: dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            raise ValueError(f"Expected KEY=VALUE, got: {pair!r}")
        key, value = pair.split("=", 1)
        key = key.strip()
        if not key:
            raise ValueError(f"Empty key in: {pair!r}")
        env[key] = value
    return env


def _write_text(path: Path, content: str, *, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    if executable:
        mode = path.stat().st_mode
        path.chmod(mode | 0o111)


def _fixture_server_py() -> str:
    return """#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import uuid
from typing import Any


PROXY_NAME = "mcporter-skill-fixture"
PROXY_VERSION = "0.1"


_memory: dict[str, str] = {}


def _result(request_id: Any, result: Any) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def _error(request_id: Any, code: int, message: str) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def _tool_output_json(*, content: str, continuation_id: str) -> str:
    payload = {
        "status": "continuation_available",
        "content": content,
        "content_type": "text",
        "metadata": {"tool_name": "chat", "fixture": True},
        "continuation_offer": {
            "continuation_id": continuation_id,
            "note": "Fixture continuation offer",
            "remaining_turns": 999,
        },
    }
    return json.dumps(payload, indent=2, sort_keys=True)


def _tools() -> list[dict[str, Any]]:
    return [
        {
            "name": "chat",
            "description": "Fixture chat tool that persists the first prompt per continuation_id and replays it on follow-ups.",
            "inputSchema": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "prompt": {"type": "string"},
                    "continuation_id": {"type": "string"},
                },
                "required": ["prompt"],
            },
        }
    ]


def handle(msg: dict[str, Any]) -> dict[str, Any] | None:
    method = msg.get("method")
    if not isinstance(method, str):
        return _error(msg.get("id"), -32600, "Invalid Request")
    if method.startswith("notifications/"):
        return None

    if method == "initialize":
        params = msg.get("params") if isinstance(msg.get("params"), dict) else {}
        protocol_version = params.get("protocolVersion") or "2025-11-25"
        return _result(
            msg.get("id"),
            {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": PROXY_NAME, "version": PROXY_VERSION},
            },
        )

    if method == "ping":
        return _result(msg.get("id"), {})

    if method == "tools/list":
        return _result(msg.get("id"), {"tools": _tools(), "nextCursor": None})

    if method == "tools/call":
        params = msg.get("params") if isinstance(msg.get("params"), dict) else {}
        name = params.get("name")
        arguments = params.get("arguments") if isinstance(params.get("arguments"), dict) else {}
        if name != "chat":
            return _result(
                msg.get("id"),
                {"content": [{"type": "text", "text": f"unknown tool: {name}"}], "isError": True},
            )

        prompt = arguments.get("prompt")
        continuation_id = arguments.get("continuation_id")
        if not isinstance(prompt, str) or not prompt:
            return _result(
                msg.get("id"),
                {"content": [{"type": "text", "text": "missing prompt"}], "isError": True},
            )

        if isinstance(continuation_id, str) and continuation_id in _memory:
            content = _memory[continuation_id]
            payload = _tool_output_json(content=content, continuation_id=continuation_id)
            return _result(msg.get("id"), {"content": [{"type": "text", "text": payload}], "isError": False})

        new_id = str(uuid.uuid4())
        _memory[new_id] = prompt
        payload = _tool_output_json(content=prompt, continuation_id=new_id)
        return _result(msg.get("id"), {"content": [{"type": "text", "text": payload}], "isError": False})

    return _error(msg.get("id"), -32601, f"Method not found: {method}")


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            sys.stdout.write(json.dumps(_error(None, -32700, "Parse error")) + "\\n")
            sys.stdout.flush()
            continue

        if not isinstance(msg, dict):
            sys.stdout.write(json.dumps(_error(None, -32600, "Invalid Request")) + "\\n")
            sys.stdout.flush()
            continue

        resp = handle(msg)
        if resp is None:
            continue
        sys.stdout.write(json.dumps(resp, separators=(",", ":")) + "\\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
"""


def _wrapper_script_sh(server_name: str) -> str:
    return f"""#!/usr/bin/env bash
set -euo pipefail

MCPORTER_VERSION="${{MCPORTER_VERSION:-0.7.3}}"

_SCRIPT_DIR="$(cd -- "$(dirname -- "${{BASH_SOURCE[0]}}")" && pwd -P)"
_SKILL_DIR="$(cd -- "${{_SCRIPT_DIR}}/.." && pwd -P)"

CONFIG_PATH="${{MCP_SKILL_CONFIG:-${{_SKILL_DIR}}/mcporter.json}}"

MCPORTER_BIN="${{MCPORTER_BIN:-}}"
if [ -n "${{MCPORTER_BIN}}" ]; then
  if ! command -v "${{MCPORTER_BIN}}" >/dev/null 2>&1; then
    echo "mcp wrapper: MCPORTER_BIN=${{MCPORTER_BIN}} not found in PATH" >&2
    exit 2
  fi
  MC=("${{MCPORTER_BIN}}" --config "${{CONFIG_PATH}}")
else
  if ! command -v npx >/dev/null 2>&1; then
    echo "mcp wrapper: npx not found in PATH (set MCPORTER_BIN=mcporter to use a local mcporter binary)" >&2
    exit 2
  fi
  export npm_config_update_notifier="${{npm_config_update_notifier:-false}}"
  MC=(npx -y "mcporter@${{MCPORTER_VERSION}}" --config "${{CONFIG_PATH}}")
fi

subcmd="${{1:-}}"
if [ -z "${{subcmd}}" ] || [ "${{subcmd}}" = "-h" ] || [ "${{subcmd}}" = "--help" ] || [ "${{subcmd}}" = "help" ]; then
  cat <<'EOF'
Usage:
  mcp list [args...]
  mcp call <tool|server.tool|url> [args...]

Notes:
  - Defaults to MCPorter via npx (pinned by MCPORTER_VERSION).
  - Set MCPORTER_BIN=mcporter to use a local mcporter binary from PATH instead.
  - Uses a skill-local config by default: mcporter.json (override with MCP_SKILL_CONFIG).
EOF
  exit 0
fi

case "${{subcmd}}" in
  list)
    shift
    "${{MC[@]}}" list "{server_name}" "$@"
    ;;
  call)
    shift
    selector="${{1:-}}"
    if [ -z "${{selector}}" ]; then
      echo "mcp wrapper: missing tool selector" >&2
      exit 2
    fi
    shift
    if [[ "${{selector}}" == *.* || "${{selector}}" == http*://* ]]; then
      target="${{selector}}"
    else
      target="{server_name}.${{selector}}"
    fi
    "${{MC[@]}}" call "${{target}}" "$@"
    ;;
  *)
    shift
    "${{MC[@]}}" "${{subcmd}}" "$@"
    ;;
esac
"""

def _selftest_script_sh(*, server_name: str, include_fixture: bool) -> str:
    fixture_note = "yes" if include_fixture else "no"
    fixture_call = (
        r"""
echo "selftest: fixture keep-alive (multi-turn) ..."
SENTINEL="fixture-selftest-$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)"

first_args="$(python3 - <<PY
import json
print(json.dumps({"prompt": "${SENTINEL}"}))
PY
)"
first="$(bash "${_SKILL_DIR}/scripts/mcp" call fixture.chat --output json --args "${first_args}")"

cid="$(python3 - "${first}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
offer = data.get("continuation_offer") or {}
cid = offer.get("continuation_id")
if not isinstance(cid, str) or not cid:
    raise SystemExit(f"missing continuation_id: {data!r}")
print(cid)
PY
)"

second_args="$(python3 - <<PY
import json
print(json.dumps({"prompt": "follow-up-without-sentinel", "continuation_id": "${cid}"}))
PY
)"
second="$(bash "${_SKILL_DIR}/scripts/mcp" call fixture.chat --output json --args "${second_args}")"

python3 - "${SENTINEL}" "${first}" "${second}" <<'PY'
import json
import sys

sentinel = sys.argv[1]
first = json.loads(sys.argv[2])
second = json.loads(sys.argv[3])
assert sentinel in (first.get("content") or ""), first
assert sentinel in (second.get("content") or ""), second
PY
"""
        if include_fixture
        else ""
    )

    return f"""#!/usr/bin/env bash
set -euo pipefail

MCPORTER_VERSION="${{MCPORTER_VERSION:-0.7.3}}"

_SCRIPT_DIR="$(cd -- "$(dirname -- "${{BASH_SOURCE[0]}}")" && pwd -P)"
_SKILL_DIR="$(cd -- "${{_SCRIPT_DIR}}/.." && pwd -P)"

CONFIG_PATH="${{MCP_SKILL_CONFIG:-${{_SKILL_DIR}}/mcporter.json}}"

echo "selftest: skill_dir=${{_SKILL_DIR}}"
echo "selftest: config=${{CONFIG_PATH}}"
echo "selftest: mcporter_version=${{MCPORTER_VERSION}}"
echo "selftest: fixture_tests={fixture_note}"

MCPORTER_BIN="${{MCPORTER_BIN:-}}"
if [ -n "${{MCPORTER_BIN}}" ]; then
  if ! command -v "${{MCPORTER_BIN}}" >/dev/null 2>&1; then
    echo "selftest: MCPORTER_BIN=${{MCPORTER_BIN}} not found in PATH" >&2
    exit 2
  fi
else
  if ! command -v npx >/dev/null 2>&1; then
    echo "selftest: npx not found in PATH (set MCPORTER_BIN=mcporter to use a local mcporter binary)" >&2
    exit 2
  fi
fi

if [ -f "${{_SKILL_DIR}}/tests/test_offline.py" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "selftest: python3 not found in PATH (required for offline tests)" >&2
    exit 2
  fi
  echo "selftest: offline tests ..."
  python3 "${{_SKILL_DIR}}/tests/test_offline.py" >/dev/null 2>&1
fi

echo "selftest: list tools (server={server_name}) ..."
bash "${{_SKILL_DIR}}/scripts/mcp" list --json >/dev/null

{fixture_call}

echo "ok"
"""


def _agents_openai_yaml(skill_name: str, server_name: str) -> str:
    return f"""interface:
  display_name: "{_title_case(skill_name)}"
  short_description: "Use MCP server '{server_name}' via MCPorter"
"""


def _generated_skill_md(skill_name: str, server_name: str) -> str:
    return f"""---
name: {skill_name}
description: Use the `{server_name}` MCP server via MCPorter (with optional keep-alive daemon for multi-turn tools).
---

# {_title_case(skill_name)}

This skill wraps an MCP server via MCPorter (shell calls), with an optional keep-alive daemon so stdio servers can support multi-turn `continuation_id` flows.

## Quick start

List tools:

```bash
bash "scripts/mcp" list
```

Call a tool (recommended: JSON args):

```bash
bash "scripts/mcp" call <tool> --output json --args '{{"key":"value"}}'
```

## Multi-turn note

If the server uses `continuation_id` backed by in-memory state (like PAL), you must keep the underlying server process alive between calls. This skill does that by configuring MCPorter `lifecycle=keep-alive` (daemon-managed). MCPorter will auto-start (and reuse) the daemon as needed; you can just keep calling tools.

## Assumptions / requirements

- Default: `npx` is available (Node installed) so the wrapper can run `mcporter@${MCPORTER_VERSION}`.
- Optional: set `MCPORTER_BIN=mcporter` to use a local `mcporter` binary on `PATH` instead of `npx`.
- The MCP server transport is reachable:
  - For stdio servers: the configured command exists and can start.
  - For HTTP servers: the URL is reachable and any required auth is configured.
- For multi-turn `continuation_id` flows: `lifecycle=keep-alive` is required (daemon-managed).

## Selftest

```bash
bash "scripts/selftest"
```
"""


def _mcporter_config(
    *,
    server_name: str,
    description: str,
    http_url: str | None,
    stdio_tokens: list[str] | None,
    env: dict[str, str] | None,
    keep_alive: bool,
    idle_timeout_ms: int | None,
    include_fixture: bool,
) -> dict[str, Any]:
    if (http_url is None) == (stdio_tokens is None):
        raise ValueError("Exactly one of http_url or stdio_tokens must be provided")

    entry: dict[str, Any] = {"description": description}
    if http_url is not None:
        entry["baseUrl"] = http_url
    else:
        entry["command"] = stdio_tokens

    if env:
        entry["env"] = env

    if keep_alive:
        lifecycle: dict[str, Any] = {"mode": "keep-alive"}
        if idle_timeout_ms and idle_timeout_ms > 0:
            lifecycle["idleTimeoutMs"] = idle_timeout_ms
        entry["lifecycle"] = lifecycle

    servers: dict[str, Any] = {server_name: entry}

    if include_fixture:
        servers["fixture"] = {
            "description": "Fixture stdio MCP server used for deterministic tests.",
            "command": ["python3", "tests/fixtures/memory_mcp_server.py"],
            "lifecycle": {"mode": "keep-alive", "idleTimeoutMs": 300000},
        }

    return {"mcpServers": servers, "imports": []}


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a Codex skill that wraps an MCP server via MCPorter.")
    parser.add_argument("--skill-name", required=True, help="Generated skill folder name (hyphen-case).")
    parser.add_argument(
        "--out-dir",
        default=None,
        help="Directory to write the generated skill into (default: sibling of this skill).",
    )
    parser.add_argument("--server-name", default=None, help="Server name to use inside mcporter.json.")
    parser.add_argument("--server-description", default=None, help="Description to store in mcporter.json.")

    conn = parser.add_mutually_exclusive_group(required=True)
    conn.add_argument("--http-url", help="HTTP MCP server URL.")
    conn.add_argument("--stdio", help='STDIO command, e.g. \'uvx --from ... pal-mcp-server\' (will be shlex-split).')
    parser.add_argument("--env", action="append", default=[], help="Env var override for server: KEY=VALUE (repeatable).")
    parser.add_argument(
        "--keep-alive",
        action="store_true",
        help="Enable MCPorter keep-alive daemon (required for in-memory continuation_id flows).",
    )
    parser.add_argument("--idle-timeout-ms", type=int, default=None, help="Keep-alive idle timeout in ms.")
    parser.add_argument(
        "--with-fixture-tests",
        action="store_true",
        help="Include a fixture MCP server + tests folder for deterministic multi-turn testing.",
    )
    parser.add_argument("--force", action="store_true", help="Overwrite existing output directory if present.")
    verify = parser.add_mutually_exclusive_group()
    verify.add_argument(
        "--verify",
        dest="verify",
        action="store_true",
        help="After generation, run the generated skill's selftest (requires npx; may require auth/network).",
    )
    verify.add_argument(
        "--no-verify",
        dest="verify",
        action="store_false",
        help="Do not run the generated skill's selftest (default).",
    )
    parser.set_defaults(verify=False)

    args = parser.parse_args()

    skill_name = _normalize_skill_name(args.skill_name)
    server_name = _normalize_skill_name(args.server_name or skill_name)
    server_description = (args.server_description or f"{server_name} MCP server").strip()

    if args.out_dir:
        out_dir = Path(args.out_dir).expanduser().resolve()
    else:
        out_dir = Path(__file__).resolve().parents[2]

    skill_dir = out_dir / skill_name
    if skill_dir.exists():
        if not args.force:
            raise SystemExit(f"Refusing to overwrite existing directory: {skill_dir} (pass --force)")
        if skill_dir.is_symlink():
            raise SystemExit(f"Refusing to overwrite symlinked directory: {skill_dir}")
        try:
            skill_dir.resolve().relative_to(out_dir.resolve())
        except ValueError as exc:
            raise SystemExit(f"Refusing to delete outside out_dir: {skill_dir} (out_dir={out_dir})") from exc
        shutil.rmtree(skill_dir)

    (skill_dir / "scripts").mkdir(parents=True, exist_ok=True)
    if args.with_fixture_tests:
        (skill_dir / "tests" / "fixtures").mkdir(parents=True, exist_ok=True)

    stdio_tokens: list[str] | None = None
    if args.stdio:
        stdio_tokens = shlex.split(args.stdio)
        if not stdio_tokens:
            raise SystemExit("--stdio produced no tokens")

    http_url = args.http_url
    env = _parse_kv_pairs(args.env) if args.env else None

    config = _mcporter_config(
        server_name=server_name,
        description=server_description,
        http_url=http_url,
        stdio_tokens=stdio_tokens,
        env=env,
        keep_alive=bool(args.keep_alive),
        idle_timeout_ms=args.idle_timeout_ms,
        include_fixture=bool(args.with_fixture_tests),
    )

    _write_text(skill_dir / "SKILL.md", _generated_skill_md(skill_name, server_name))
    _write_text(skill_dir / "mcporter.json", json.dumps(config, indent=2, sort_keys=True) + "\n")
    _write_text(skill_dir / "scripts" / "mcp", _wrapper_script_sh(server_name), executable=True)
    _write_text(
        skill_dir / "scripts" / "selftest",
        _selftest_script_sh(server_name=server_name, include_fixture=bool(args.with_fixture_tests)),
        executable=True,
    )
    _write_text(skill_dir / "agents" / "openai.yaml", _agents_openai_yaml(skill_name, server_name))

    if args.with_fixture_tests:
        _write_text(
            skill_dir / "tests" / "fixtures" / "memory_mcp_server.py",
            _fixture_server_py(),
            executable=True,
        )
        _write_text(
            skill_dir / "tests" / "test_offline.py",
            """#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class OfflineTests(unittest.TestCase):
    def test_skill_files_exist(self) -> None:
        self.assertTrue((ROOT / "SKILL.md").exists())
        self.assertTrue((ROOT / "mcporter.json").exists())
        self.assertTrue((ROOT / "scripts" / "mcp").exists())

    def test_mcporter_config_parses(self) -> None:
        data = json.loads((ROOT / "mcporter.json").read_text(encoding="utf-8"))
        self.assertIn("mcpServers", data)
        self.assertIn("imports", data)


if __name__ == "__main__":
    unittest.main()
""",
            executable=True,
        )

    if args.verify:
        try:
            subprocess.run(
                ["bash", str(skill_dir / "scripts" / "selftest")],
                check=True,
                cwd=str(skill_dir),
            )
        except subprocess.CalledProcessError as exc:
            raise SystemExit(f"Selftest failed for generated skill at {skill_dir} (exit {exc.returncode})") from exc

    print(f"Wrote skill: {skill_dir}")


if __name__ == "__main__":
    main()
