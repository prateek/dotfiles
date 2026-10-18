"""Public request/result guarantees with fake network boundaries and real state files."""

import copy
import http.client
import io as stdio
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from searchlib import contracts as c, planning, engine, registry, identity, io
from searchlib.adapters import web, host
from searchlib.cli import run, execute, parser
from searchlib.io import atomic, lock


def request(**overrides):
    return {"schema_version": 1, "terms": "Python releases", **overrides}


def manifest(provider="web.search", **extra):
    return {
        "schema_version": 1,
        "capabilities": [
            {
                "id": provider,
                "tool": "test.actual_tool",
                "cost": "free",
                "operations": list(web.WEB_OPS) + ["code.discover", "page.inspect"],
                **extra,
            }
        ],
    }


def envelope(report, **overrides):
    work = report["pending"][0]
    return {
        "run_id": report["run_id"],
        "work_item_id": work["work_item_id"],
        "attempt_id": work["attempt_id"],
        "observed_at": "2026-10-17T12:00:00+00:00",
        "status": "success",
        "payload": {
            "results": [{"url": "https://python.org/downloads", "title": "Python"}]
        },
        **overrides,
    }


class SearchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = patch.dict(
            os.environ, {"XDG_CONFIG_HOME": str(self.home / "config")}, clear=False
        )
        self.env.start()
        self.addCleanup(self.env.stop)

    def cli(self, *args, input=None):
        return subprocess.run(
            [sys.executable, str(SCRIPTS / "agent-search"), *args],
            input=input,
            capture_output=True,
            text=True,
            cwd=self.home,
        )

    def test_inspect_no_writes_and_hard_pin(self):
        p = self.cli(
            "query", "Python", "--provider", "serper", "--inspect", "--no-defaults"
        )
        self.assertEqual(p.returncode, 0, p.stderr)
        doc = json.loads(p.stdout)
        self.assertEqual(doc["jobs"][0]["routes"], [])
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertEqual(doc["choices"]["provider"]["kind"], "constraint")

    def test_all_excluded_is_never_complete(self):
        with self.assertRaisesRegex(c.Invalid, "excluded"):
            planning.plan(
                request(choices={"area": ["shopping"], "exclude_source": ["amazon"]}),
                saved=False,
            )
        p = planning.plan(
            request(
                facets=[
                    {
                        "id": "a",
                        "area": "shopping",
                        "source": "amazon",
                        "operation": "product.discover",
                    }
                ],
                choices={"exclude_source": ["amazon"]},
            ),
            saved=False,
        )
        self.assertFalse(engine.report(engine.new_state(p))["complete"])

    def test_global_limit_preserves_each_facet_and_reports_truncation(self):
        p = planning.plan(
            request(
                choices={
                    "area": ["web", "code", "social", "shopping"],
                    "total_limit": 6,
                }
            ),
            saved=False,
        )
        s = engine.new_state(p)
        for job in p["jobs"]:
            f = job["facet"]
            rows = identity.normalize(
                [{"url": f"https://example.org/{f['id']}/{i}"} for i in range(10)],
                f,
                registry.REGISTRY["serper"],
                engine.now(),
            )
            s["outcomes"][f["id"]] = {"status": "success", "results": rows, "count": 10}
        report = engine.report(s)
        self.assertEqual(len(report["results"]), 6)
        self.assertEqual(
            {o["facet_id"] for row in report["results"] for o in row["observations"]},
            {j["facet"]["id"] for j in p["jobs"]},
        )
        self.assertEqual(sum(cov["returned_count"] for cov in report["coverage"]), 6)
        self.assertTrue(all(cov["count"] == 10 for cov in report["coverage"]))

    def test_retry_cannot_displace_unattempted_facet(self):
        facets = [
            {
                "id": name,
                "area": "code",
                "source": "skills" if name == "skills-cli" else "github",
                "operation": "code.discover",
                "provider": name,
            }
            for name in ("gh-skill", "sourcegraph", "skills-cli", "github-code")
        ]
        calls = []

        def invoke(p, f, timeout):
            calls.append(p["id"])
            return {"status": "timeout", "results": []}

        with (
            patch("shutil.which", return_value="fixture-tool"),
            patch.object(registry, "execute", side_effect=invoke),
        ):
            p = planning.plan(
                request(
                    facets=facets,
                    budget={
                        "calls": 4,
                        "discovery": 4,
                        "enrichment": 0,
                        "opens": 0,
                        "wall_seconds": 10,
                    },
                ),
                saved=False,
            )
            report = engine.drive(engine.new_state(p))
        self.assertCountEqual(calls, [f["id"] for f in facets])
        self.assertEqual(report["usage"]["calls"], 4)

    def test_host_queue_is_deferred_not_exhausted(self):
        caps = manifest()
        caps["capabilities"] += manifest("mcp:grep.app")["capabilities"]
        facets = [
            {
                "id": name,
                "area": "code",
                "source": "github",
                "operation": "code.discover",
                "provider": name,
            }
            for name in ("host-web", "grep-app", "github-code")
        ]
        facets[0].update(area="web", source="web", operation="page.discover")
        with patch("shutil.which", return_value="fixture-tool"):
            p = planning.plan(request(facets=facets), caps, saved=False)
            report = engine.drive(engine.new_state(p))
        cov = report["coverage"][2]
        self.assertEqual((cov["outcome"], cov["coverage"]), ("deferred", "unverified"))
        self.assertEqual(report["usage"]["calls"], 0)

    def test_retry_waits_for_serialized_first_attempts(self):
        providers = ("github-code", "github-repos", "github-issues", "sourcegraph")
        facets = [
            {
                "id": name,
                "area": "code",
                "source": "github",
                "operation": registry.REGISTRY[name]["operations"][0],
                "provider": name,
            }
            for name in providers
        ]
        called = []

        def invoke(p, f, timeout):
            called.append(p["id"])
            return {
                "status": "timeout" if p["id"] == "sourcegraph" else "empty",
                "results": [],
            }

        with (
            patch("shutil.which", return_value="fixture-tool"),
            patch.object(registry, "execute", side_effect=invoke),
        ):
            p = planning.plan(
                request(
                    facets=facets,
                    budget={
                        "calls": 4,
                        "discovery": 4,
                        "enrichment": 0,
                        "opens": 0,
                        "wall_seconds": 10,
                    },
                ),
                saved=False,
            )
            engine.drive(engine.new_state(p))
        self.assertCountEqual(called, providers)

    def test_save_omits_obsolete_preference_with_notice(self):
        atomic(
            planning.preference_path("user"),
            {"schema_version": 1, "choices": {"prefer_via": "mcp", "max_calls": 3}},
        )
        result = self.cli("query", "--save-defaults", "--limit", "5", "--scope", "user")
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = json.loads(result.stdout)
        self.assertEqual(saved["choices"], {"max_calls": 3, "limit": 5})
        self.assertTrue(saved["notices"])

    def test_sourcegraph_repository_rows_are_not_schema_failures(self):
        data = {
            "Results": [
                {"__typename": "Repository", "name": "github.com/acme/tools"},
                {
                    "__typename": "FileMatch",
                    "repository": {"name": "github.com/acme/tools"},
                    "file": {"path": "SKILL.md"},
                },
            ]
        }
        with (
            patch("shutil.which", return_value="fixture-tool"),
            patch.object(
                io,
                "command",
                return_value={"rc": 0, "stdout": json.dumps(data), "stderr": ""},
            ),
        ):
            p = planning.plan(
                request(
                    facets=[
                        {
                            "id": "skills",
                            "area": "code",
                            "source": "github",
                            "operation": "code.discover",
                            "provider": "sourcegraph",
                        }
                    ]
                ),
                saved=False,
            )
            report = engine.drive(engine.new_state(p))
        self.assertEqual(report["coverage"][0]["outcome"], "success")
        self.assertEqual(len(report["results"]), 1)

    def test_bad_provider_row_preserves_valid_candidates(self):
        with (
            patch.dict(os.environ, {"SERPER_API_KEY": "fixture-key"}),
            patch.object(
                io,
                "http",
                return_value={
                    "organic": [
                        {"link": "https://python.org/"},
                        {"link": "ftp://invalid.example/file"},
                        None,
                        {"title": "Missing URL"},
                    ]
                },
            ),
        ):
            p = planning.plan(
                request(choices={"provider": "serper"}, authorized_paid=["serper"]),
                saved=False,
            )
            report = engine.drive(engine.new_state(p))
        self.assertEqual(report["coverage"][0]["outcome"], "partial")
        self.assertEqual([r["url"] for r in report["results"]], ["https://python.org/"])

    def test_malformed_native_rows_preserve_siblings(self):
        samples = {
            "gh-skill": [None, {"repo": "acme/tools", "path": "SKILL.md"}],
            "sourcegraph": {
                "Results": [
                    None,
                    {"repository": None},
                    {
                        "repository": {"name": "github.com/acme/tools"},
                        "file": {"path": "SKILL.md"},
                    },
                ]
            },
        }
        for provider, payload in samples.items():
            with (
                self.subTest(provider=provider),
                patch("shutil.which", return_value="fixture-tool"),
                patch.object(
                    io,
                    "command",
                    return_value={"rc": 0, "stdout": json.dumps(payload), "stderr": ""},
                ),
            ):
                p = planning.plan(
                    request(
                        facets=[
                            {
                                "id": "skills",
                                "area": "code",
                                "source": "github",
                                "operation": "code.discover",
                                "provider": provider,
                            }
                        ]
                    ),
                    saved=False,
                )
                report = engine.drive(engine.new_state(p))
                self.assertEqual(report["coverage"][0]["outcome"], "partial")
                self.assertEqual(
                    [r["fields"]["repo"] for r in report["results"]], ["acme/tools"]
                )

    def test_conflicting_provider_pin_is_rejected(self):
        with self.assertRaisesRegex(c.Invalid, "free-only constraint"):
            planning.plan(
                request(choices={"provider": "serper", "free_only": True}), saved=False
            )

    def test_invalid_saved_soft_preference_is_omitted(self):
        atomic(
            planning.preference_path("user"),
            {
                "schema_version": 1,
                "choices": {"prefer_via": "mcp", "strategy": "retired"},
            },
        )
        p = planning.plan(request(), manifest())
        self.assertEqual(p["jobs"][0]["routes"], ["host-web"])
        self.assertEqual(len(p["notices"]), 2)

    def test_malformed_request_uses_json_error_envelope(self):
        facet = {
            "id": "f",
            "area": "web",
            "source": "web",
            "operation": "page.discover",
        }
        examples = [
            [1],
            request(choices=[]),
            request(facets=[{**facet, "source": {}}]),
            request(facets=[{**facet, "operation": []}]),
        ]
        for value in examples:
            with self.subTest(value=value):
                result = self.cli(
                    "plan", "--request", "-", "--no-defaults", input=json.dumps(value)
                )
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("error", json.loads(result.stderr))

    def test_invalid_fields_and_conflicts_fail_before_calls(self):
        examples = [
            request(unexpected="no"),
            request(choices={"provider": "made-up"}),
            request(choices={"source": ["reddit"], "exclude_source": ["reddit"]}),
            request(choices={"since": "2026-10-18", "until": "2026-10-17"}),
            request(
                budget={
                    "calls": 1,
                    "discovery": 2,
                    "enrichment": 0,
                    "opens": 0,
                    "wall_seconds": 2,
                }
            ),
        ]
        for value in examples:
            with self.subTest(value=value), self.assertRaises(c.Invalid):
                planning.plan(value, saved=False)

    def test_saved_constraint_and_preference_precedence(self):
        planning.save_preferences("user", {"provider": "serper", "free_only": True})
        p = planning.plan(request(choices={"provider": "host-web"}), manifest())
        self.assertEqual(p["jobs"][0]["routes"], ["host-web"])
        self.assertTrue(p["request"]["choices"]["free_only"])
        self.assertEqual(p["choices"]["provider"]["scope"], "explicit")
        self.assertEqual(
            os.stat(planning.preference_path("user")).st_mode & 0o777, 0o600
        )
        atomic(
            planning.preference_path("user"),
            {"schema_version": 1, "choices": {"prefer_provider": "retired"}},
        )
        p = planning.plan(request(), manifest())
        self.assertTrue(p["notices"])
        atomic(
            planning.preference_path("user"),
            {"schema_version": 1, "choices": {"provider": "retired"}},
        )
        with self.assertRaisesRegex(c.Invalid, "provider constraint"):
            planning.plan(request(), manifest())

    def test_inspect_cannot_save(self):
        p = self.cli(
            "query", "Python", "--inspect", "--save-defaults", "--provider", "serper"
        )
        self.assertEqual(p.returncode, 2)
        self.assertFalse((self.home / "config").exists())

    def test_conflicting_flags_and_duplicate_json_rejected(self):
        result = self.cli(
            "query", "Python", "--provider=serper", "--provider=exa", "--inspect"
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Conflicting explicit", result.stderr)
        result = self.cli(
            "plan",
            "--request",
            "-",
            input='{"schema_version":1,"terms":"a","terms":"b"}',
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Duplicate JSON field", result.stderr)

    def test_optional_access_and_paid_authorization(self):
        with patch.dict(os.environ, {"SERPER_API_KEY": "fixture-key"}):
            p = planning.plan(request(choices={"provider": "serper"}), saved=False)
            self.assertEqual(
                p["jobs"][0]["skipped"][0]["reason"], "requires_authorization"
            )
            with self.assertRaisesRegex(c.Invalid, "free-only constraint"):
                planning.plan(
                    request(
                        choices={"provider": "serper", "free_only": True},
                        authorized_paid=["serper"],
                    ),
                    saved=False,
                )
            p = planning.plan(
                request(choices={"provider": "serper"}, authorized_paid=["serper"]),
                saved=False,
            )
            self.assertEqual(p["jobs"][0]["routes"], ["serper"])

    def test_shared_budget_and_runtime_constraint(self):
        p = planning.plan(
            request(choices={"area": ["code", "social"], "max_calls": 4}), saved=False
        )
        self.assertEqual(
            p["budget"],
            {
                "calls": 4,
                "discovery": 2,
                "enrichment": 2,
                "opens": 6,
                "wall_seconds": 120,
            },
        )
        p = planning.plan(
            request(choices={"via": "browser", "browser": "camofox"}),
            manifest("browser", runtime="other"),
            saved=False,
        )
        self.assertFalse(p["jobs"][0]["routes"])
        p = planning.plan(
            request(choices={"via": "browser", "browser": "camofox"}),
            manifest("browser", runtime="camofox"),
            saved=False,
        )
        self.assertEqual(p["jobs"][0]["routes"][:2], ["startpage", "ddg"])

    def test_no_host_binding_is_reported_without_guessing(self):
        p = planning.plan(request(choices={"provider": "host-web"}), saved=False)
        r = run(p, None)
        self.assertFalse(r["complete"])
        self.assertEqual(r["usage"]["calls"], 0)
        self.assertEqual(r["suggestions"][0]["gap"], "unconfigured")
        self.assertEqual(r["coverage"][0]["skipped"][0]["reason"], "requires_host")

    def test_host_checkpoint_resume_idempotence_and_assessment(self):
        p = planning.plan(
            request(choices={"provider": "host-web"}), manifest(), saved=False
        )
        path = self.home / "state.json"
        report = run(p, path)
        self.assertTrue(path.exists())
        self.assertEqual(report["usage"]["calls"], 0)
        self.assertEqual(len(report["pending"]), 1)
        receipt = envelope(report)
        atomic(self.home / "receipt.json", {"schema_version": 1, "results": [receipt]})
        args = (
            "continue",
            "--state",
            str(path),
            "--host-results",
            str(self.home / "receipt.json"),
        )
        result = self.cli(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        first = json.loads(result.stdout)
        self.assertEqual(first["usage"]["calls"], 1)
        self.assertFalse(first["complete"])
        self.assertEqual(first["coverage"][0]["coverage"], "discovery-only")
        result = self.cli(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["usage"], first["usage"])
        self.assertEqual(json.loads(result.stdout)["deadline"], report["deadline"])
        a = {
            "schema_version": 1,
            "run_id": first["run_id"],
            "assessments": [
                {
                    "facet_id": "f1",
                    "checks": ["relevance"],
                    "references": ["https://python.org/downloads"],
                }
            ],
        }
        atomic(self.home / "assessment.json", a)
        result = self.cli(
            "assess",
            "--state",
            str(path),
            "--assessment",
            str(self.home / "assessment.json"),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["complete"])

    def test_stale_unknown_and_overspent_host_envelopes_are_atomic(self):
        s = engine.new_state(
            planning.plan(
                request(choices={"provider": "host-web"}), manifest(), saved=False
            )
        )
        r = engine.drive(s)
        good = envelope(r)
        for change in (
            {"run_id": "wrong"},
            {"attempt_id": "stale"},
            {"usage": {"calls": 2, "discovery": 2, "enrichment": 0, "opens": 0}},
            {"extra": "no"},
        ):
            with self.subTest(change=change), self.assertRaises(c.Invalid):
                engine.host_results(
                    s, {"schema_version": 1, "results": [good, {**good, **change}]}
                )
            self.assertEqual(s["usage"]["calls"], 0)
        s = engine.host_results(s, {"schema_version": 1, "results": [good]})
        with self.assertRaisesRegex(c.Invalid, "duplicate"):
            engine.host_results(
                s, {"schema_version": 1, "results": [{**good, "status": "empty"}]}
            )

    def test_expired_run_settles_pending_without_starting_new_work(self):
        s = engine.new_state(
            planning.plan(
                request(choices={"provider": "host-web"}), manifest(), saved=False
            )
        )
        r = engine.drive(s)
        s["deadline"] = 0
        s = engine.host_results(s, {"schema_version": 1, "results": [envelope(r)]})
        self.assertEqual(engine.drive(s)["usage"]["calls"], 1)
        self.assertEqual(s["deadline"], 0)

    def test_missing_required_source_preserves_other_results(self):
        req = request(
            facets=[
                {
                    "id": "web",
                    "area": "web",
                    "source": "web",
                    "operation": "page.discover",
                    "provider": "host-web",
                },
                {
                    "id": "comments",
                    "area": "social",
                    "source": "reddit",
                    "operation": "comments.read",
                    "filters": {"url": "https://reddit.com/r/python/comments/abc"},
                },
            ],
            choices={"require_source": ["reddit"]},
        )
        s = engine.new_state(planning.plan(req, manifest(), saved=False))
        r = engine.drive(s)
        s = engine.host_results(s, {"schema_version": 1, "results": [envelope(r)]})
        r = engine.report(s)
        self.assertEqual(len(r["results"]), 1)
        self.assertFalse(r["complete"])
        self.assertEqual(r["coverage"][1]["coverage"], "unavailable")

    def test_wrong_source_cannot_be_success(self):
        p = planning.plan(
            request(choices={"source": ["reddit"], "provider": "host-web"}),
            manifest(),
            saved=False,
        )
        s = engine.new_state(p)
        r = engine.drive(s)
        s = engine.host_results(s, {"schema_version": 1, "results": [envelope(r)]})
        self.assertEqual(
            engine.report(s)["coverage"][0]["outcome"], "constraint_failed"
        )
        self.assertFalse(engine.report(s)["results"])

    def test_host_budget_cannot_reset_on_fallback(self):
        p = planning.plan(
            request(choices={"via": "browser", "max_calls": 1}),
            manifest("browser"),
            saved=False,
        )
        s = engine.new_state(p)
        r = engine.drive(s)
        s = engine.host_results(
            s,
            {
                "schema_version": 1,
                "results": [envelope(r, status="challenge", payload={})],
            },
        )
        r = engine.drive(s)
        self.assertEqual(r["usage"]["calls"], 1)
        self.assertEqual(r["pending"], [])
        self.assertEqual(r["coverage"][0]["outcome"], "challenge")

    def test_inspection_extension_keeps_original_deadline_and_budget(self):
        caps = manifest()
        caps["capabilities"].append(
            {
                "id": "web.fetch",
                "tool": "actual.fetch",
                "cost": "free",
                "operations": ["page.inspect"],
            }
        )
        req = request(
            budget={
                "calls": 2,
                "discovery": 1,
                "enrichment": 1,
                "opens": 1,
                "wall_seconds": 60,
            }
        )
        s = engine.new_state(planning.plan(req, caps, saved=False))
        r = engine.drive(s)
        s = engine.host_results(s, {"schema_version": 1, "results": [envelope(r)]})
        deadline = s["deadline"]
        extra = {
            "schema_version": 1,
            "prepared_jobs": [
                {
                    "id": "inspect",
                    "area": "web",
                    "source": "web",
                    "operation": "page.inspect",
                    "filters": {"url": "https://python.org/downloads"},
                }
            ],
        }
        engine.extend(s, extra)
        r = engine.drive(s)
        self.assertEqual(r["deadline"], deadline)
        self.assertEqual(
            r["pending"][0]["reserved_budget"],
            {"calls": 1, "discovery": 0, "enrichment": 1, "opens": 1},
        )
        s = engine.host_results(s, {"schema_version": 1, "results": [envelope(r)]})
        extra["prepared_jobs"][0]["id"] = "excess"
        engine.extend(s, extra)
        r = engine.drive(s)
        self.assertEqual(r["pending"], [])
        self.assertEqual(r["usage"]["calls"], 2)
        self.assertEqual(r["coverage"][-1]["outcome"], "budget_exhausted")

    def test_state_lock_and_corruption(self):
        path = self.home / "state.json"
        with lock(path):
            with self.assertRaisesRegex(c.Invalid, "locked"):
                with lock(path):
                    pass
        p = planning.plan(request(), saved=False)
        p["budget"]["calls"] += 1
        with self.assertRaisesRegex(c.Invalid, "fingerprint"):
            planning.validate_plan(p)

    def test_browser_generic_page_is_not_empty(self):
        self.assertEqual(
            host.parse("ddg", "<h1>Search the web</h1>")["status"], "schema_error"
        )
        self.assertEqual(
            host.parse("startpage", "<p>Verify you are human</p>")["status"],
            "challenge",
        )
        self.assertEqual(
            host.parse("ddg", "<p>No results found</p>")["status"], "empty"
        )
        parsed = host.parse(
            "ddg",
            '<a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fpython.org">Python</a>',
        )
        self.assertEqual(parsed["results"][0]["url"], "https://python.org")
        self.assertEqual(
            host.parse(
                "startpage",
                '<a class="w-gl__result-title" href="https://python.org">Python</a>',
            )["status"],
            "success",
        )

    def test_startpage_pow_is_a_challenge(self):
        result = host.parse(
            "startpage", "<p>Verifying your request... Calculating... Difficulty: 4</p>"
        )
        self.assertEqual(result["status"], "challenge")

    def test_resource_identity_preserves_ids_revisions_and_offer_values(self):
        rows = [
            dict(
                source="youtube",
                kind="video",
                url="https://youtube.com/watch?v=" + id,
                fields={},
            )
            for id in ("a", "b")
        ]
        self.assertNotEqual(identity.identity(rows[0]), identity.identity(rows[1]))
        r = {
            "source": "github",
            "kind": "code",
            "url": "https://github.com/a/b/blob/main/x.py",
            "fields": {"repo": "a/b", "path": "x.py"},
        }
        self.assertNotEqual(
            identity.identity(r),
            identity.identity({**r, "fields": {**r["fields"], "revision": "abc"}}),
        )
        f = {"id": "f", "source": "amazon", "operation": "product.discover"}
        p = registry.REGISTRY["searchapi"]
        normalized = identity.normalize(
            [
                {
                    "url": "https://amazon.com/dp/ASIN",
                    "fields": {"item_id": "ASIN", "price": 20},
                },
                {
                    "url": "https://amazon.com/dp/ASIN",
                    "fields": {"item_id": "ASIN", "price": 12},
                },
            ],
            f,
            p,
            "now",
        )
        grouped = identity.merge(normalized)
        self.assertEqual(
            [o["fields"]["price"] for o in grouped[0]["observations"]], [20, 12]
        )

    def test_http_contracts_success_empty_schema_and_provenance(self):
        samples = {
            "serper": {"organic": []},
            "brave": {"web": {"results": []}},
            "exa": {"results": []},
            "parallel": {"results": []},
            "tavily": {"results": []},
            "perplexity": {"results": []},
            "kagi": {"data": {"search": []}},
            "octen": {"code": 0, "data": {"results": []}},
            "searchapi": {"organic_results": []},
            "searxng": {"results": []},
            "degoog": {"results": []},
            "hn": {"hits": []},
        }
        for name, data in samples.items():
            with self.subTest(provider=name):
                p = registry.REGISTRY[name]
                f = {
                    "source": "hn" if name == "hn" else "web",
                    "operation": "post.discover" if name == "hn" else "page.discover",
                    "terms": "Python",
                    "limit": 1,
                }
                self.assertEqual(web.parse(p, f, data)["status"], "empty")
                nonempty = copy.deepcopy(data)
                target = nonempty
                while not any(isinstance(v, list) for v in target.values()):
                    target = next(v for v in target.values() if isinstance(v, dict))
                key = next(k for k, v in target.items() if isinstance(v, list))
                target[key] = [
                    {"url": "https://python.org", "title": "Python", "objectID": "1"}
                ]
                self.assertEqual(web.parse(p, f, nonempty)["status"], "success")
                with self.assertRaises(Exception):
                    web.parse(p, f, {"unexpected": []})

    def test_http_calls_auth_budget_errors_and_brave_retention(self):
        captured = []

        def response(req, **kwargs):
            captured.append(req)
            return stdio.BytesIO(
                json.dumps(
                    {"organic": [{"link": "https://python.org", "title": "Python"}]}
                ).encode()
            )

        with (
            patch.dict(os.environ, {"SERPER_API_KEY": "not-a-real-key"}),
            patch("urllib.request.OpenerDirector.open", side_effect=response),
        ):
            p = planning.plan(
                request(choices={"provider": "serper"}, authorized_paid=["serper"]),
                saved=False,
            )
            r = run(p, self.home / "s.json")
            self.assertEqual(r["usage"]["calls"], 1)
            self.assertEqual(captured[0].get_header("X-api-key"), "not-a-real-key")
            self.assertNotIn("not-a-real-key", (self.home / "s.json").read_text())
            self.assertEqual(r["results"][0]["observations"][0]["upstream"], "google")
        with (
            patch.dict(os.environ, {"BRAVE_SEARCH_API_KEY": "fixture"}),
            patch(
                "urllib.request.OpenerDirector.open",
                return_value=stdio.BytesIO(
                    b'{"web":{"results":[{"url":"https://private-result.invalid","description":"retention-test"}]}}'
                ),
            ),
        ):
            p = planning.plan(
                request(choices={"provider": "brave"}, authorized_paid=["brave"]),
                saved=False,
            )
            r = run(p, self.home / "b.json")
            self.assertEqual(len(r["results"]), 1)
            self.assertNotIn(
                "private-result.invalid", (self.home / "b.json").read_text()
            )
            self.assertNotIn("retention-test", (self.home / "b.json").read_text())

    def test_rate_limit_stops_and_timeout_retries_once(self):
        for error, expected_calls in (
            (HTTPError("https://test", 429, "limit", {}, stdio.BytesIO(b"")), 1),
            (TimeoutError(), 2),
        ):
            with (
                self.subTest(error=type(error)),
                patch.dict(os.environ, {"SERPER_API_KEY": "fixture"}),
                patch(
                    "urllib.request.OpenerDirector.open", side_effect=error
                ) as network,
            ):
                p = planning.plan(
                    request(choices={"provider": "serper"}, authorized_paid=["serper"]),
                    saved=False,
                )
                r = run(p, None)
                self.assertEqual(network.call_count, expected_calls)
                self.assertEqual(r["usage"]["calls"], expected_calls)
                self.assertFalse(r["complete"])

    def test_native_query_dialect_not_translated_twice(self):
        p = registry.REGISTRY["sourcegraph"]
        from searchlib.adapters.native import query

        f = {
            "native_query": {
                "dialect": "sourcegraph",
                "text": "file:SKILL.md count:12",
            },
            "limit": 12,
        }
        self.assertEqual(query(p, f), "file:SKILL.md count:12")
        with self.assertRaises(c.Invalid):
            planning.plan(
                request(
                    facets=[
                        {
                            "id": "x",
                            "area": "code",
                            "source": "github",
                            "operation": "code.discover",
                            **f,
                            "filters": {"path": "x"},
                        }
                    ]
                ),
                saved=False,
            )

    def test_saved_plan_rejects_execution_overrides(self):
        with patch.dict(os.environ, {"SERPER_API_KEY": "fixture"}):
            plan = planning.plan(
                request(choices={"provider": "serper"}, authorized_paid=["serper"]),
                saved=False,
            )
            path = self.home / "plan.json"
            atomic(path, plan)
            for flags in (
                ("--free-only",),
                ("--max-calls", "1"),
                ("--capabilities", "missing.json"),
            ):
                with (
                    self.subTest(flags=flags),
                    patch(
                        "urllib.request.OpenerDirector.open",
                        side_effect=lambda *a, **k: stdio.BytesIO(b'{"organic":[]}'),
                    ),
                ):
                    with self.assertRaisesRegex(c.Invalid, "execution options"):
                        execute(
                            parser().parse_args(["run", "--plan", str(path), *flags])
                        )

    def test_explicit_budget_cannot_ignore_choice_limits(self):
        for choice in ({"max_calls": 1}, {"max_opens": 0}, {"timeout": 1}):
            with (
                self.subTest(choice=choice),
                self.assertRaisesRegex(c.Invalid, "budget"),
            ):
                planning.plan(
                    request(
                        choices=choice,
                        budget={
                            "calls": 3,
                            "discovery": 2,
                            "enrichment": 1,
                            "opens": 1,
                            "wall_seconds": 60,
                        },
                    ),
                    saved=False,
                )

    def test_timed_out_page_consumes_call_before_next_facet(self):
        calls = []

        def command(argv, timeout):
            calls.append(argv)
            if len(calls) == 2:
                raise io.Failure("timeout")
            return {
                "rc": 0,
                "stderr": "",
                "stdout": json.dumps(
                    {
                        "total_count": 200,
                        "items": [
                            {
                                "full_name": f"a/r{i}",
                                "html_url": f"https://github.com/a/r{i}",
                            }
                            for i in range(100)
                        ],
                    }
                ),
            }

        facets = [
            {
                "id": f"f{i}",
                "area": "code",
                "source": "github",
                "operation": "repo.discover",
                "provider": "github-repos",
                "limit": limit,
            }
            for i, limit in ((1, 200), (2, 1))
        ]
        with (
            patch("shutil.which", return_value="/fixture/gh"),
            patch.object(io, "command", side_effect=command),
        ):
            report = run(
                planning.plan(
                    request(
                        facets=facets,
                        choices={"total_limit": 200},
                        budget={
                            "calls": 2,
                            "discovery": 2,
                            "enrichment": 0,
                            "opens": 0,
                            "wall_seconds": 10,
                        },
                    ),
                    saved=False,
                ),
                None,
            )
        self.assertEqual(len(calls), 2)
        self.assertEqual(report["usage"]["calls"], 2)
        self.assertEqual(report["coverage"][1]["outcome"], "budget_exhausted")
        self.assertEqual(len(report["outcomes"]["f1"]["results"]), 100)

    def test_transport_failure_settles_and_preserves_sibling(self):
        def response(req, **kwargs):
            if "serper" in req.full_url:
                raise http.client.IncompleteRead(b"partial")
            return stdio.BytesIO(b'{"results":[{"url":"https://example.com/good"}]}')

        facets = [
            {
                "id": p,
                "area": "web",
                "source": "web",
                "operation": "page.discover",
                "provider": p,
            }
            for p in ("serper", "exa")
        ]
        with (
            patch.dict(
                os.environ, {"SERPER_API_KEY": "fixture", "EXA_API_KEY": "fixture"}
            ),
            patch("urllib.request.OpenerDirector.open", side_effect=response),
        ):
            path = self.home / "failed-transport.json"
            report = run(
                planning.plan(
                    request(
                        facets=facets,
                        authorized_paid=["serper", "exa"],
                        choices={"max_calls": 4},
                    ),
                    saved=False,
                ),
                path,
            )
        self.assertFalse(report["pending"])
        self.assertEqual(report["outcomes"]["serper"]["status"], "transient")
        self.assertEqual(report["results"][0]["url"], "https://example.com/good")
        self.assertEqual(report["usage"]["calls"], 3)
        self.assertFalse(json.loads(path.read_text())["pending"])

    def test_browser_result_text_cannot_block_provider(self):
        for provider, css in (
            ("ddg", "result__a"),
            ("startpage", "w-gl__result-title"),
        ):
            for title in (
                "Rate limits",
                "CAPTCHA documentation",
                "Sign in to search explained",
            ):
                with self.subTest(provider=provider, title=title):
                    result = host.parse(
                        provider,
                        f'<a class="{css}" href="https://example.com/docs">{title}</a>',
                    )
                    self.assertEqual(result["status"], "success")
                    self.assertEqual(len(result["results"]), 1)
        for text in (
            "Casino bonuses found here",
            "This guide says no results found",
            "Nothing relevant",
        ):
            self.assertEqual(
                host.parse("ddg", f"<p>{text}</p>")["status"], "schema_error"
            )

    def test_default_dated_search_can_extend_to_inspection(self):
        caps = manifest()
        caps["capabilities"].append(
            {
                "id": "web.fetch",
                "tool": "test.fetch",
                "cost": "free",
                "operations": ["page.inspect"],
            }
        )
        state = engine.new_state(
            planning.plan(request(choices={"since": "2026-01-01"}), caps, saved=False)
        )
        result = engine.drive(state)
        state = engine.host_results(
            state, {"schema_version": 1, "results": [envelope(result)]}
        )
        budget, deadline = state["plan"]["budget"].copy(), state["deadline"]
        engine.extend(
            state,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    {
                        "id": "read",
                        "area": "web",
                        "source": "web",
                        "operation": "page.inspect",
                        "filters": {"url": "https://python.org/downloads"},
                    }
                ],
            },
        )
        result = engine.drive(state)
        self.assertEqual(len(result["pending"]), 1)
        self.assertEqual(result["pending"][0]["operation"], "page.inspect")
        self.assertEqual(
            result["pending"][0]["payload"]["filters"],
            {"url": "https://python.org/downloads"},
        )
        self.assertEqual(result["budget"], budget)
        self.assertEqual(result["deadline"], deadline)

    def test_provider_ids_do_not_split_platform_identity(self):
        for source, operation, url in (
            ("youtube", "video.discover", "https://youtube.com/watch?v=abc123"),
            ("amazon", "product.discover", "https://amazon.com/dp/B012345678"),
            ("hn", "post.discover", "https://news.ycombinator.com/item?id=42"),
        ):
            with self.subTest(source=source):
                facet = {
                    "id": "f",
                    "source": source,
                    "operation": operation,
                    "limit": 5,
                }
                rows = []
                for provider, data in (
                    ("exa", {"results": [{"url": url, "id": url}]}),
                    ("serper", {"organic": [{"link": url}]}),
                ):
                    spec = registry.REGISTRY[provider]
                    parsed = web.parse(spec, facet, data)
                    rows += identity.normalize(
                        parsed["results"], facet, spec, "2026-10-17T00:00:00Z"
                    )
                grouped = identity.merge(rows)
                self.assertEqual(len(grouped), 1)
                self.assertEqual(len(grouped[0]["observations"]), 2)

    def test_raw_output_survives_normalization_failure(self):
        output = {
            "rc": 0,
            "stdout": "warning: version changed\nnot JSON",
            "stderr": "diagnostic",
        }
        facet = {
            "id": "raw",
            "area": "code",
            "source": "github",
            "operation": "code.discover",
            "provider": "sourcegraph",
            "raw": True,
        }
        with (
            patch("shutil.which", return_value="/fixture/src"),
            patch.object(io, "command", return_value=output),
        ):
            report = run(planning.plan(request(facets=[facet]), saved=False), None)
        self.assertEqual(report["outcomes"]["raw"]["raw"], output)

    def test_unqualified_date_filters_do_not_select_routes(self):
        for provider in (
            "brave",
            "parallel",
            "tavily",
            "perplexity",
            "kagi",
            "octen",
            "ddg",
            "startpage",
        ):
            key = registry.REGISTRY[provider].get("credential")
            with (
                self.subTest(provider=provider),
                patch.dict(os.environ, {key: "fixture"} if key else {}),
                self.assertRaisesRegex(c.Invalid, "unsupported filters"),
            ):
                planning.plan(
                    request(
                        choices={"since": "2026-01-01", "provider": provider},
                        authorized_paid=[provider],
                    ),
                    manifest("browser"),
                    saved=False,
                )

    def test_colored_skills_output_preserves_candidates(self):
        output = {
            "rc": 0,
            "stdout": "\x1b[36macme/tools@testing\x1b[0m \x1b[32m12.3K\x1b[0m installs\n",
            "stderr": "",
        }
        facet = {
            "id": "skills",
            "area": "code",
            "source": "skills",
            "operation": "code.discover",
            "provider": "skills-cli",
        }
        with (
            patch("shutil.which", return_value="/fixture/npx"),
            patch.object(io, "command", return_value=output),
        ):
            report = run(planning.plan(request(facets=[facet]), saved=False), None)
        self.assertEqual(report["results"][0]["fields"]["installs"], 12300)

    def test_corrupt_state_is_rejected_before_resume(self):
        state = engine.new_state(planning.plan(request(), saved=False))
        state["attempts"] = [
            {
                "facet_id": "f1",
                "provider": "unknown",
                "status": "success",
                "count": 1,
                "observed_at": "now",
            }
        ]
        with self.assertRaises(c.Invalid):
            engine.validate_state(state)


if __name__ == "__main__":
    unittest.main()
