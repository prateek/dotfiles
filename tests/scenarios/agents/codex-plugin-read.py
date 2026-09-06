import json
import os
import select
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def main():
    cli, marketplace_path = sys.argv[1:]
    marketplace = json.loads(Path(marketplace_path).read_text())
    plugin_name = marketplace["plugins"][0]["name"]
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            [cli, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors, bufsize=0,
        )
        pending = b""

        def request(identity, method, params):
            nonlocal pending
            process.stdin.write((json.dumps({"id": identity, "method": method, "params": params}) + "\n").encode())
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if b"\n" not in pending:
                    ready, _, _ = select.select([process.stdout], [], [], max(0, deadline - time.monotonic()))
                    if not ready:
                        break
                    chunk = os.read(process.stdout.fileno(), 65536)
                    if not chunk:
                        break
                    pending += chunk
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    message = json.loads(line)
                    if message.get("id") == identity:
                        assert "error" not in message, message
                        return message["result"]
            errors.seek(0)
            raise AssertionError(f"no response to {method}: {errors.read().decode(errors='replace')}")

        try:
            request(1, "initialize", {
                "clientInfo": {"name": "agent-skill-packages-native", "title": None, "version": "0"},
                "capabilities": {"experimentalApi": True},
            })
            result = request(2, "plugin/read", {
                "marketplacePath": marketplace_path, "remoteMarketplaceName": None, "pluginName": plugin_name,
            })
            assert result["plugin"]["skills"], result
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


if __name__ == "__main__":
    main()
