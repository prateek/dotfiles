import json
import stat
from collections import Counter

from tests.support.python import ROOT, RepoTestCase


XTRACE = """ordinary stderr survives outside the trace parser
+DFX|v=1|ts=1.000000|pid=42|sub=0|src=/tmp/install.sh|line=10|name=/tmp/install.sh|stack=|ctx=toplevel| install_main
+DFX|v=1|ts=1.010000|pid=42|sub=0|src=/tmp/install.sh|line=20|name=install_brewfile|stack=install_brewfile,install_main|ctx=toplevel,shfunc| API_TOKEN=supersecret brew bundle install --token abc123
+DFX|v=1|ts=1.050000|pid=42|sub=0|src=/tmp/install.sh|line=21|name=install_brewfile|stack=install_brewfile,install_main|ctx=toplevel,shfunc| echo done
+DFX|v=1|ts=not-a-time|pid=42|sub=0|src=/tmp/install.sh|line=22|name=bad|stack=|ctx=toplevel| ignored
"""


class PerfettoTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.tools = ROOT / "scripts/trace"
        self.fixture = self.work / "xtrace.log"
        self.fixture.write_text(XTRACE)
        self.converted = self.work / "fixture.perfetto.json"
        self.summary = self.work / "summary.json"
        self.command([
            str(self.tools / "xtrace-to-perfetto"), "--output", str(self.converted),
            "--summary-output", str(self.summary), "--process-name", "fixture",
            "--pid-offset", "100", str(self.fixture),
        ])

    def assert_private(self, path):
        self.assertEqual(stat.S_IMODE(path.stat().st_mode) & 0o077, 0, str(path))

    def test_conversion_redacts_secrets_and_maps_commands_to_distinct_named_tracks(self):
        raw = self.converted.read_text()
        self.assertNotIn("supersecret", raw)
        self.assertNotIn("abc123", raw)
        json.loads(self.summary.read_text())
        events = json.loads(raw)["traceEvents"]
        names = [event.get("name", "") for event in events]
        self.assertTrue(any("brew bundle" in name for name in names), names)
        self.assertIn("Install Brewfile", names)
        self.assertFalse(any(name.startswith("0") and "brew" in name.lower() for name in names), names)
        processes = {event["pid"]: event["args"]["name"] for event in events if event.get("name") == "process_name"}
        self.assertEqual(processes[1420], "fixture pid 42 - semantic steps")
        self.assertEqual(processes[1421], "fixture pid 42 - major commands")
        self.assertEqual(processes[1422], "fixture pid 42 - all commands")
        tracks = {(event["pid"], event["tid"]): event["args"]["name"]
                  for event in events if event.get("name") == "thread_name"}
        for track, name in {
            (1420, 1): "Install Main", (1420, 2): "  Install Brewfile",
            (1421, 1): "major commands", (1422, 1): "all commands",
        }.items():
            self.assertEqual(tracks[track], name)
        major = [event for event in events if event.get("cat") == "zsh-major-command"]
        self.assertTrue(any("brew bundle" in event["name"] for event in major), major)
        semantic = [event for event in events if event.get("cat") == "zsh-function"]
        self.assertLessEqual({"Install Main", "Install Brewfile"}, {event["name"] for event in semantic})
        self.assertEqual({event["pid"] for event in semantic}, {1420})
        complete = [event for event in events if event.get("ph") == "X"]
        self.assertTrue(complete)
        for event in complete:
            self.assertIn((event["pid"], event["tid"]), tracks)
            self.assertIs(type(event["ts"]), int)
            self.assertGreater(event["dur"], 0)
            expected_pid = {"zsh-command": 1422, "zsh-major-command": 1421, "zsh-function": 1420}
            if event.get("cat") in expected_pid:
                self.assertEqual(event["pid"], expected_pid[event["cat"]])
        self.assertEqual({event["pid"] for event in complete if event.get("cat") in
                          ("zsh-command", "zsh-major-command")}, {1421, 1422})
        layout = {event["name"]: event["tid"] for event in complete if event.get("cat") == "zsh-function"}
        self.assertEqual(layout["Install Main"], 1)
        self.assertEqual(layout["Install Brewfile"], 2)

    def test_viewer_prints_a_loopback_url_and_exits_after_idle_without_opening_browser(self):
        result = self.command([
            str(self.tools / "open-perfetto"), str(self.converted), "--port", "0",
            "--idle-timeout", "1", "--no-open", "--print-url",
        ])
        self.assertTrue(result.stdout.startswith(b"https://ui.perfetto.dev/#!/?url=http%3A%2F%2F127.0.0.1%3A"))

    def test_real_zsh_capture_and_merge_keep_artifacts_private(self):
        sample = self.work / "sample.zsh"
        sample.write_text('#!/bin/zsh\nset -e\nouter() { inner; }\ninner() { echo "sample ok"; }\nouter\n')
        sample.chmod(0o700)
        run_dir = self.work / "run"
        self.command([str(self.tools / "run-zsh"), "--output-dir", str(run_dir),
                      "--process-name", "sample", "--", str(sample)])
        for name in ("stdout.log", "stderr.log", "manifest.json", "trace.perfetto.json"):
            self.assertTrue((run_dir / name).is_file())
        for path in (run_dir, run_dir / "stdout.log", run_dir / "stderr.log", run_dir / "trace.perfetto.json"):
            self.assert_private(path)
        self.assertEqual((run_dir / "stdout.log").read_bytes(), b"sample ok\n")
        actual_trace = json.loads((run_dir / "trace.perfetto.json").read_text())
        merged = self.work / "merged.perfetto.json"
        self.command([str(self.tools / "merge-perfetto"), "--output", str(merged),
                      str(self.converted), str(run_dir / "trace.perfetto.json")])
        self.assert_private(merged)
        expected_events = json.loads(self.converted.read_text())["traceEvents"] + actual_trace["traceEvents"]
        self.assertEqual(Counter(json.dumps(event, sort_keys=True) for event in json.loads(merged.read_text())["traceEvents"]),
                         Counter(json.dumps(event, sort_keys=True) for event in expected_events))

    def test_merge_reports_a_missing_input(self):
        result = self.command([str(self.tools / "merge-perfetto"), "--output", str(self.work / "missing.json"),
                               str(self.converted), str(self.work / "absent.json")], expected_status=1)
        self.assertIn(b"trace file not found", result.stderr)

    def test_command_failure_still_leaves_manifest_and_trace(self):
        run_dir = self.work / "failed-command"
        self.command([str(self.tools / "run-zsh"), "--output-dir", str(run_dir),
                      "--process-name", "failing", "--", "/bin/zsh", "-c", "echo failing; false"], expected_status=1)
        self.assertTrue((run_dir / "trace.perfetto.json").is_file())
        self.assertEqual(json.loads((run_dir / "manifest.json").read_text())["command_rc"], 1)

    def test_conversion_failure_propagates_even_after_a_successful_command(self):
        run_dir = self.work / "failed-conversion"
        (run_dir / "trace.perfetto.json").mkdir(parents=True)
        result = self.command([str(self.tools / "run-zsh"), "--output-dir", str(run_dir),
                               "--process-name", "convert-fail", "--", "/bin/zsh", "-c", "true"], expected_status=1)
        self.assertIn(b"xtrace conversion failed", result.stderr)
        manifest = json.loads((run_dir / "manifest.json").read_text())
        self.assertEqual(manifest["command_rc"], 0)
        self.assertNotEqual(manifest["convert_rc"], 0)

    def test_tart_help_documents_the_current_trace_opt_in(self):
        script = ROOT / "scripts/vm/test-install-tart.sh"
        self.assertIn(b"DOTFILES_TRACE=1", self.command(["bash", str(script), "--help"]).stdout)
        self.assertNotIn("DOTFILES_BOOTSTRAP_TRACE_FILE", script.read_text())
