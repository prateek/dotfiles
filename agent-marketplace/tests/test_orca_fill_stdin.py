"""CLI secret-handling checks against a substitute Orca runtime socket."""

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import unittest


HELPER = (
    Path(__file__).resolve().parents[1]
    / "packages/utils-agent/skills/browser/scripts/orca-fill-stdin"
)


class OrcaFillStdinTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="orca-fill-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.calls = []
        self.prepare = True
        self.verify = True
        self.fill_error = False
        self.secret = 'dummy-"quote"-é-\\literal\n'
        self.server = socket.socket(socket.AF_UNIX)
        endpoint = str(self.root / "runtime.sock")
        self.server.bind(endpoint)
        self.server.listen()
        self.server.settimeout(0.1)
        self.stopped = threading.Event()
        (self.root / "orca-runtime.json").write_text(
            json.dumps(
                {
                    "authToken": "fixture-auth-token",
                    "transports": [{"kind": "unix", "endpoint": endpoint}],
                }
            )
        )
        binary = self.root / "orca"
        binary.write_text(
            '#!/bin/sh\nprintf "%s\\n" "${FIXTURE_ORCA_VERSION:-1.4.212}"\n'
        )
        binary.chmod(0o755)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("ORCA_")}
        self.env.update(
            ORCA_USER_DATA_PATH=str(self.root),
            PATH=str(self.root) + os.pathsep + os.environ["PATH"],
        )
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self):
        self.stopped.set()
        self.thread.join(timeout=2)
        self.server.close()

    def serve(self):
        evals = 0
        while not self.stopped.is_set():
            try:
                conn, _ = self.server.accept()
            except socket.timeout:
                continue
            with conn, conn.makefile("rb") as stream:
                request = json.loads(stream.readline())
                self.calls.append(request)
                method = request["method"]
                if method == "browser.fill":
                    result = {"filled": request["params"]["element"]}
                else:
                    evals += 1
                    result = {
                        "result": json.dumps(
                            self.prepare if evals == 1 else self.verify
                        )
                    }
                failed = method == "browser.fill" and self.fill_error
                frames = [
                    {"_keepalive": True},
                    {
                        "id": request["id"],
                        "ok": not failed,
                        "result": result,
                        "error": {"message": self.secret + " fixture-auth-token"},
                    },
                ]
                conn.sendall("".join(json.dumps(f) + "\n" for f in frames).encode())

    def run_helper(self, value=None):
        result = subprocess.run(
            [
                sys.executable,
                str(HELPER),
                "--page",
                "owned-page",
                "--selector",
                "#password",
                "--origin",
                "https://example.test",
            ],
            input=self.secret if value is None else value,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertNotIn(self.secret, result.stdout + result.stderr)
        self.assertNotIn("fixture-auth-token", result.stdout + result.stderr)
        return result

    def test_stdin_bytes_reach_only_the_owned_page_and_receipt_contains_no_value(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {"filled": True, "verified": True, "submitted": False},
        )
        fills = [c for c in self.calls if c["method"] == "browser.fill"]
        self.assertEqual(len(fills), 1)
        self.assertEqual(fills[0]["params"]["value"], self.secret)
        self.assertTrue(all(c["params"]["page"] == "owned-page" for c in self.calls))
        self.assertEqual(
            {c["method"] for c in self.calls}, {"browser.eval", "browser.fill"}
        )

    def test_rejected_origin_or_field_never_receives_the_password(self):
        self.prepare = False
        result = self.run_helper()
        self.assertEqual(result.returncode, 1)
        self.assertIn("origin or unique editable password field", result.stderr)
        self.assertFalse(any(c["method"] == "browser.fill" for c in self.calls))
        self.assertNotIn(self.secret, json.dumps(self.calls, ensure_ascii=False))

    def test_runtime_error_cannot_echo_secret_or_trigger_a_retry(self):
        self.fill_error = True
        result = self.run_helper()
        self.assertEqual(result.returncode, 1)
        self.assertIn("response withheld", result.stderr)
        self.assertEqual(
            len([c for c in self.calls if c["method"] == "browser.fill"]), 1
        )

    def test_successful_fill_receipt_is_not_enough(self):
        self.verify = False
        result = self.run_helper()
        self.assertEqual(result.returncode, 1)
        self.assertIn("did not retain the exact input", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_unknown_version_stops_before_runtime_access(self):
        self.env["FIXTURE_ORCA_VERSION"] = "1.4.213"
        result = self.run_helper()
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsupported Orca version", result.stderr)
        self.assertEqual(self.calls, [])

    def test_empty_and_oversized_stdin_never_reach_runtime(self):
        for value in ("", "x" * 4097):
            with self.subTest(size=len(value)):
                result = self.run_helper(value)
                self.assertEqual(result.returncode, 1)
                self.assertIn("1 to 4096", result.stderr)
                self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
