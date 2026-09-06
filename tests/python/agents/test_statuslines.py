import json
import re
import time

from tests.support.python import ROOT, RepoTestCase


MINIMAL = {"model": {"display_name": "Fable 5"}, "workspace": {"current_dir": "/tmp"}}


class StatuslineCase(RepoTestCase):
    def output(self, payload, *, logical=False):
        raw = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        argv = ["/bin/sh", str(self.script)] + (["--logical"] if logical else [])
        result = self.command(argv, raw)
        self.assertEqual(result.stderr, b"")
        text = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout.decode())
        if not logical:
            self.assertEqual(len(text.splitlines()), 1, text)
        return text.removesuffix("\n")

    def with_context(self, context):
        return self.payload | {"context_window": context}


class ClaudeStatuslineTests(StatuslineCase):
    def setUp(self):
        super().setUp()
        self.script = ROOT / "home/dot_claude/executable_statusline.sh"
        self.payload = {
            "model": {"id": "claude-fable-5", "display_name": "Fable 5"},
            "effort": {"level": "xhigh"},
            "workspace": {"current_dir": "/Users/prungta/code/worktrees/dotfiles/claude-acpx"},
            "cost": {"total_cost_usd": 6.8412, "total_duration_ms": 10200000},
            "context_window": {"used_percentage": 58, "total_input_tokens": 116000, "context_window_size": 200000},
        }

    def subscription(self):
        now = int(time.time())
        return self.payload | {"rate_limits": {
            "five_hour": {"used_percentage": 42, "resets_at": now + 930},
            "seven_day": {"used_percentage": 63, "resets_at": now + 250000},
        }}

    def test_subscription_render_and_logical_document_show_usage_instead_of_cost(self):
        payload = self.subscription()
        text = self.output(payload)
        for expected in ("Fable 5 xhigh", "dotfiles/claude-acpx", "2h50m",
                         "ctx ██████░░░░ 58% 116k/200k", "5h ████░░░░░░ 42% (15m)"):
            self.assertIn(expected, text)
        self.assertNotIn("$", text)
        self.assertNotIn("7d", text)
        logical = json.loads(self.output(payload, logical=True))
        self.assertEqual(logical["model"], {"name": "Fable 5", "effort": "xhigh"})
        self.assertEqual(logical["ctx"]["pct"], 58)
        self.assertEqual(logical["ctx"]["used"], "116k")
        self.assertEqual(logical["ctx"]["level"], "ok")
        self.assertIsNone(logical["cost"])
        self.assertEqual(logical["five_hour"]["pct"], 42)
        self.assertIsNone(logical["seven_day"])

    def test_weekly_usage_appears_above_the_threshold_and_api_sessions_show_cost(self):
        hot = self.subscription()
        hot["rate_limits"]["seven_day"]["used_percentage"] = 85.4
        self.assertIn("7d 85% (3d)", self.output(hot))
        text = self.output(self.payload)
        self.assertIn("$6.84", text)
        self.assertNotIn("5h ", text)
        self.assertNotIn("7d ", text)

    def test_current_usage_wins_over_cumulative_totals_and_percentage_is_the_fallback(self):
        cumulative = self.payload["context_window"] | {"total_input_tokens": 800000}
        current = cumulative | {"current_usage": {
            "input_tokens": 100000, "cache_creation_input_tokens": 6000, "cache_read_input_tokens": 10000,
        }}
        self.assertIn("58% 116k/200k", self.output(self.with_context(current)))
        text = self.output(self.with_context(cumulative))
        self.assertIn("58% 116k/200k", text)
        self.assertNotIn("800k", text)

    def test_zero_percentage_is_recomputed_from_real_tokens_and_empty_context_is_hidden(self):
        context = {"used_percentage": 0, "total_input_tokens": 20000, "context_window_size": 200000}
        self.assertIn("ctx █░░░░░░░░░ 10% 20k/200k", self.output(self.with_context(context)))
        context["total_input_tokens"] = 0
        self.assertNotIn("ctx", self.output(self.with_context(context)))

    def test_compactions_count_system_boundaries_without_counting_escaped_message_text(self):
        transcript = self.work / "transcript.jsonl"
        records = [
            {"type": "system", "subtype": "compact_boundary", "compactMetadata": {"trigger": "auto"}},
            {"type": "user", "message": {"content": 'discussing "subtype":"compact_boundary" markers'}},
            {"type": "system", "subtype": "compact_boundary", "compactMetadata": {"trigger": "manual"}},
        ]
        transcript.write_text("\n".join(json.dumps(row, separators=(",", ":")) for row in records) + "\n")
        self.assertIn("116k/200k (x2)", self.output(self.payload | {"transcript_path": str(transcript)}))
        self.assertNotIn("116k/200k (x", self.output(self.payload))

    def test_minimal_and_malformed_inputs_have_stable_one_line_output(self):
        self.assertEqual(self.output(MINIMAL), "Fable 5 | /tmp")
        for logical in (False, True):
            self.assertEqual(self.output(b"not json", logical=logical), "statusline: unreadable payload")

    def test_managed_settings_point_to_the_applied_statusline(self):
        settings = json.loads(self.render("home/.chezmoitemplates/claude-settings-managed.json.tmpl"))
        self.assertEqual(settings["statusLine"]["command"], "~/.claude/statusline.sh")


class PiStatuslineTests(StatuslineCase):
    def setUp(self):
        super().setUp()
        self.script = ROOT / "home/dot_pi/agent/executable_statusline.sh"
        self.payload = {
            "model": {"id": "claude-fable-5", "display_name": "Fable 5"},
            "workspace": {"current_dir": "/Users/prungta/code/worktrees/dotfiles/pi-status-line-configure"},
            "cost": {"total_duration_ms": 10200000},
            "context_window": {
                "used_percentage": 1, "total_input_tokens": 45000, "total_output_tokens": 9000,
                "context_window_size": 300000, "current_usage": {
                    "input_tokens": 3000, "output_tokens": 600, "cache_creation_input_tokens": 0,
                    "cache_read_input_tokens": 0,
                },
            },
            "pi": {"session_file": None},
        }

    def test_aggregate_input_tokens_drive_physical_and_logical_context(self):
        text = self.output(self.payload)
        for expected in ("Fable 5", "dotfiles/pi-status-line-configure", "2h50m", "ctx ██░░░░░░░░ 15% 45k/300k"):
            self.assertIn(expected, text)
        logical = json.loads(self.output(self.payload, logical=True))
        self.assertEqual(logical["model"]["name"], "Fable 5")
        for field, value in {"pct": 15, "used": "45k", "size": "300k", "level": "ok"}.items():
            self.assertEqual(logical["ctx"][field], value)

    def test_over_window_totals_use_percentage_and_unknown_context_is_hidden(self):
        context = self.payload["context_window"] | {"used_percentage": 58, "total_input_tokens": 800000}
        text = self.output(self.with_context(context))
        self.assertIn("ctx ██████░░░░ 58% 174k/300k", text)
        self.assertNotIn("800k", text)
        context["used_percentage"] = 0
        self.assertNotIn("ctx", self.output(self.with_context(context)))

    def test_compactions_use_pi_session_records_with_either_spacing(self):
        session = self.work / "pi-session.jsonl"
        session.write_text(
            '{"type":"message","message":{"role":"user"}}\n'
            '{"type":"compaction","summary":"first"}\n'
            '{"type":"message","message":{"role":"assistant"}}\n'
            '{"type": "compaction", "summary": "second"}\n'
        )
        self.assertIn("45k/300k (x2)", self.output(self.payload | {"pi": {"session_file": str(session)}}))

    def test_zero_tokens_hide_context_and_minimal_or_malformed_input_stays_readable(self):
        context = {"used_percentage": 0, "total_input_tokens": 0, "context_window_size": 300000}
        self.assertNotIn("ctx", self.output(self.with_context(context)))
        self.assertEqual(self.output(MINIMAL), "Fable 5 | /tmp")
        for logical in (False, True):
            self.assertEqual(self.output(b"not json", logical=logical), "pi-statusline: unreadable payload")
