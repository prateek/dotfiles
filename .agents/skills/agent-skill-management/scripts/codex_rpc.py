"""Bounded requests to Codex's native configuration and plugin APIs."""
from __future__ import annotations

import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time


def requests(messages: list[tuple[str, dict]], *, cli: str = "codex", env=None, cwd: Path | None = None) -> list[dict]:
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen([cli, "app-server", "--listen", "stdio://"],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors,
                                   bufsize=0, env=env, cwd=cwd or Path.home())
        pending = b""
        results = []
        initialize = ("initialize", {"clientInfo": {"name": "dotfiles-plugins", "version": "1"},
                                     "capabilities": {"experimentalApi": True}})
        try:
            for identity, (method, params) in enumerate([initialize, *messages]):
                process.stdin.write((json.dumps({"id": identity, "method": method, "params": params}) + "\n").encode())
                deadline = time.monotonic() + 30
                while True:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise RuntimeError(f"Codex timed out responding to {method}")
                    if b"\n" not in pending:
                        ready, _, _ = select.select([process.stdout], [], [], remaining)
                        if not ready:
                            raise RuntimeError(f"Codex timed out responding to {method}")
                        chunk = os.read(process.stdout.fileno(), 65536)
                        if not chunk:
                            errors.seek(0)
                            raise RuntimeError(f"Codex exited during {method}: {errors.read().decode(errors='replace')}")
                        pending += chunk
                        if b"\n" not in pending:
                            continue
                    line, pending = pending.split(b"\n", 1)
                    message = json.loads(line)
                    if message.get("id") != identity:
                        continue
                    if "error" in message:
                        raise RuntimeError(f"Codex {method}: {message['error']}")
                    if identity:
                        results.append(message["result"])
                    break
            return results
        finally:
            process.stdin.close()
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
            process.stdout.close()


def enabled_edit(plugin: str, enabled: bool) -> tuple[str, dict]:
    return "config/value/write", {"keyPath": f"plugins.{json.dumps(plugin)}.enabled", "value": enabled,
                                  "mergeStrategy": "replace"}
