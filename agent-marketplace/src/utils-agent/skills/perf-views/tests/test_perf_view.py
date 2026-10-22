import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "perf-view"
TRACE = {
    "title": "fork", "unit": "ms",
    "spans": [
        {"name": "launcher", "start": 0, "end": 50},
        {"name": "main", "start": 50, "end": 900},
        {"name": "read focus", "start": 60, "end": 80},
        {"name": "scan", "start": 80, "end": 750},
        {"name": "split", "start": 750, "end": 900, "estimated": True},
        {"name": "vault io", "start": 100, "end": 700, "track": "orca"},
    ],
    "marks": [{"name": "focus captured", "at": 80}],
    "notes": ["warm run"],
}


def run(trace, *args):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *args], input=json.dumps(trace),
                          capture_output=True, text=True)


class PerfViewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.out = Path(self.tmp.name)

    def export(self, flag, name):
        result = run(TRACE, "--quiet", flag, str(self.out / name))
        self.assertEqual(result.returncode, 0, result.stderr)
        return (self.out / name).read_text()

    def test_ascii_marks_estimates_nesting_and_notes(self):
        result = run(TRACE)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        split = next(line for line in lines if "split" in line)
        self.assertIn("░", split)
        self.assertNotIn("█", split)
        self.assertTrue(next(line for line in lines if "read focus" in line).startswith("  read focus"))
        self.assertIn("@ 80.0 ms", next(line for line in lines if "focus captured" in line))
        self.assertIn("900 ms", next(line for line in lines if line.startswith("total")))
        self.assertIn("note: warm run", result.stdout)

    def test_chrome_trace_uses_microsecond_complete_events_per_track(self):
        trace = json.loads(self.export("--chrome", "trace.json"))
        events = trace["traceEvents"]
        names = {e["args"]["name"]: e["tid"] for e in events if e["ph"] == "M" and e["name"] == "thread_name"}
        self.assertEqual(set(names), {"main", "orca"})
        self.assertEqual(sorted(e["name"] for e in events if e["ph"] == "X"), sorted(s["name"] for s in TRACE["spans"]))
        scan = next(e for e in events if e["ph"] == "X" and e["name"] == "scan")
        self.assertEqual((scan["ts"], scan["dur"], scan["tid"]), (80_000, 670_000, names["main"]))
        self.assertEqual(next(e for e in events if e["name"] == "split")["cat"], "estimated")
        self.assertEqual(next(e for e in events if e["name"] == "vault io")["tid"], names["orca"])
        mark = next(e for e in events if e["ph"] == "I")
        self.assertEqual((mark["ts"], mark["s"]), (80_000, "g"))

    def test_speedscope_events_are_balanced_and_ordered(self):
        data = json.loads(self.export("--speedscope", "profile.json"))
        self.assertEqual(data["$schema"], "https://www.speedscope.app/file-format-schema.json")
        self.assertEqual([p["name"] for p in data["profiles"]], ["main", "orca"])
        self.assertEqual({f["name"] for f in data["shared"]["frames"]}, {s["name"] for s in TRACE["spans"]})
        for profile in data["profiles"]:
            self.assertEqual((profile["type"], profile["unit"]), ("evented", "milliseconds"))
            ats = [e["at"] for e in profile["events"]]
            self.assertEqual(ats, sorted(ats))
            open_frames = []
            for event in profile["events"]:
                if event["type"] == "O":
                    open_frames.append(event["frame"])
                else:
                    self.assertEqual(open_frames.pop(), event["frame"])
            self.assertEqual(open_frames, [])

    def test_folded_stacks_carry_self_time_in_nanoseconds(self):
        lines = dict(line.rsplit(" ", 1) for line in self.export("--folded", "stacks.folded").splitlines())
        self.assertEqual(lines["main;main"], "10000000")
        self.assertEqual(lines["main;main;scan"], "670000000")
        self.assertEqual(lines["orca;vault io"], "600000000")
        self.assertNotIn("main;main;read focus;scan", lines)

    def test_times_keep_the_input_origin(self):
        trace = dict(TRACE, spans=[{"name": "late", "start": 5, "end": 15}], marks=[{"name": "m", "at": 10}])
        result = run(trace)
        self.assertIn("5.0 → 15.0 ms", result.stdout)
        self.assertIn("@ 10.0 ms", result.stdout)

    def test_partial_overlap_on_one_track_is_refused(self):
        trace = dict(TRACE, spans=[{"name": "a", "start": 0, "end": 10}, {"name": "b", "start": 5, "end": 15}])
        result = run(trace)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("partially overlaps", result.stderr)

    def test_speedscope_balances_zero_length_spans(self):
        trace = dict(TRACE, spans=[{"name": "a", "start": 0, "end": 10}, {"name": "b", "start": 5, "end": 8},
                                   {"name": "z", "start": 5, "end": 5}, {"name": "edge", "start": 10, "end": 10}])
        result = run(trace, "--quiet", "--speedscope", str(self.out / "zero.json"))
        self.assertEqual(result.returncode, 0, result.stderr)
        events = json.loads((self.out / "zero.json").read_text())["profiles"][0]["events"]
        open_frames = []
        for event in events:
            if event["type"] == "O":
                open_frames.append(event["frame"])
            else:
                self.assertEqual(open_frames.pop(), event["frame"])
        self.assertEqual(open_frames, [])

    def test_marks_outside_the_spans_extend_the_axis(self):
        trace = dict(TRACE, spans=[{"name": "a", "start": 0, "end": 10}],
                     marks=[{"name": "late", "at": 20}], notes=[])
        lines = run(trace, "--width", "20").stdout.splitlines()
        bar = next(line for line in lines if line.startswith("a "))
        mark = next(line for line in lines if "late" in line)
        self.assertEqual(bar.count("█"), 10)
        self.assertEqual(mark.index("▲") - bar.index("█"), 20)

    def test_long_mark_names_are_not_truncated(self):
        trace = dict(TRACE, spans=[{"name": "ab", "start": 0, "end": 10}], marks=[{"name": "first byte", "at": 5}])
        self.assertIn("◆ first byte", run(trace).stdout)

    def test_malformed_input_reports_a_perf_view_error(self):
        for spans, marks in [([{"name": "a", "start": 0}], []), ([{"name": "a", "start": "10", "end": "9"}], []),
                             (["a"], []), ([{"name": "a", "start": 0, "end": 1}], [{"name": "m"}])]:
            result = run(dict(TRACE, spans=spans, marks=marks))
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(result.stderr.startswith("perf-view:"), result.stderr)

    def test_folded_frames_escape_separators_in_tracks_and_names(self):
        trace = dict(TRACE, spans=[{"name": "a;b\nc", "start": 0, "end": 5, "track": "x;y"}])
        result = run(trace, "--quiet", "--folded", str(self.out / "esc.folded"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.out / "esc.folded").read_text(), "x,y;a,b c 5000000\n")

    def test_folded_keeps_nanosecond_self_time(self):
        trace = {"unit": "ns", "spans": [{"name": "tiny", "start": 0, "end": 300}]}
        result = run(trace, "--quiet", "--folded", str(self.out / "ns.folded"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.out / "ns.folded").read_text(), "main;tiny 300\n")

    def test_non_finite_and_mistyped_fields_report_a_perf_view_error(self):
        bad = ['{"spans": [{"name": "a", "start": 0, "end": 1e309}]}', '[]',
               '{"spans": [{"name": "a", "start": 0, "end": 1, "track": 7}]}',
               '{"spans": [{"name": "a", "start": 0, "end": 1, "args": []}]}',
               '{"spans": [{"name": "a", "start": 0, "end": 1}], "marks": [{"name": "m", "at": 0, "track": 7}]}']
        for text in bad:
            result = subprocess.run([sys.executable, "-I", str(SCRIPT)], input=text, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, text)
            self.assertTrue(result.stderr.startswith("perf-view:"), (text, result.stderr))

    def test_width_must_be_usable(self):
        result = run(TRACE, "--width", "0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--width", result.stderr)

    def test_marks_and_notes_render_without_spans(self):
        result = run({"spans": [], "marks": [{"name": "ready", "at": 5}], "notes": ["warm"]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("◆ ready", result.stdout)
        self.assertIn("note: warm", result.stdout)

    def test_mark_on_a_track_without_spans_keeps_its_track(self):
        trace = dict(TRACE, marks=[{"name": "reply", "at": 5, "track": "server"}])
        events = json.loads(run(trace, "--quiet", "--chrome", "/dev/stdout").stdout)["traceEvents"]
        names = {e["args"]["name"]: e["tid"] for e in events if e["ph"] == "M" and e["name"] == "thread_name"}
        mark = next(e for e in events if e["ph"] == "I")
        self.assertEqual((mark["tid"], mark["s"]), (names["server"], "t"))

    def test_negative_times_print_as_given(self):
        trace = {"spans": [{"name": "pre", "start": -5, "end": 5}], "marks": [{"name": "zero", "at": 0}]}
        result = run(trace)
        self.assertIn("-5.0 → 5.0 ms", result.stdout)
        self.assertIn("@ 0.0 ms", result.stdout)

    def test_zero_length_span_renders_as_a_tick_not_a_block(self):
        trace = {"spans": [{"name": "window", "start": 0, "end": 10}, {"name": "instant", "start": 5, "end": 5}]}
        line = next(l for l in run(trace).stdout.splitlines() if "instant" in l)
        self.assertNotIn("█", line)
        self.assertIn("│", line)


if __name__ == "__main__":
    unittest.main()
