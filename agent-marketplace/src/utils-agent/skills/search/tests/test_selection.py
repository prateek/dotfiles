"""Selection and durable diagnostics at the request/state/CLI boundary."""

import copy
import json
import io as stdio
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from searchlib import contracts as c, engine, io, planning, registry
from searchlib.cli import run, execute, parser
from searchlib import selection, diagnostics, identity
from test_engine import envelope, manifest, request


class SelectionTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        env = patch.dict(os.environ, {"XDG_STATE_HOME": str(self.root)})
        env.start()
        self.addCleanup(env.stop)

    def test_conflicting_discovery_dates_fail_before_execution(self):
        with self.assertRaisesRegex(c.Invalid, "Conflicting.*since"):
            planning.plan(
                request(
                    choices={"since": "2026-01-01"},
                    facets=[
                        {
                            "id": "f",
                            "area": "web",
                            "source": "web",
                            "operation": "page.discover",
                            "filters": {"since": "2026-02-01"},
                        }
                    ],
                ),
                saved=False,
            )

    def test_pending_retry_supersedes_old_failure_coverage(self):
        s = engine.new_state(planning.plan(request(), manifest(), saved=False))
        first = engine.drive(s)
        s = engine.host_results(
            s,
            {
                "schema_version": 1,
                "results": [envelope(first, status="timeout", payload={"results": []})],
            },
        )
        retry = engine.drive(s)
        self.assertEqual(retry["coverage"][0]["outcome"], "pending")
        self.assertEqual(retry["coverage"][0]["coverage"], "unverified")
        self.assertEqual(retry["attempts"][0]["status"], "timeout")

    def test_suppressed_provider_preserves_rate_limit_cause(self):
        facets = [
            {
                "id": name,
                "area": "code",
                "source": "github",
                "operation": "code.discover",
                "provider": "github-code",
            }
            for name in ("first", "second")
        ]
        with (
            patch("shutil.which", return_value="fixture"),
            patch.object(
                registry,
                "execute",
                return_value={
                    "status": "rate_limited",
                    "results": [],
                    "detail": "quota",
                },
            ),
        ):
            result = engine.drive(
                engine.new_state(planning.plan(request(facets=facets), saved=False))
            )
        second = result["coverage"][1]
        self.assertEqual(second["outcome"], "rate_limited")
        self.assertEqual(second["suppressed"][0]["facet_id"], "first")
        self.assertEqual(len(result["attempts"]), 1)
        self.assertEqual(result["suggestions"][-1]["prerequisites"], ["github-code"])

    def test_automatic_trace_and_resume_are_private(self):
        result = run(planning.plan(request(), manifest(), saved=False), None)
        path = Path(result["trace"]["state"])
        self.assertTrue(path.is_relative_to(self.root / "agent-search/runs"))
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        for directory in (path.parent, path.parent.parent, path.parent.parent.parent):
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        state = engine.validate_state(io.read(path))
        self.assertEqual(state["run_id"], result["run_id"])
        self.assertEqual(len(state["pending"]), 1)

    def pool(self, caps=None):
        req = request(
            choices={"total_limit": 1, "result_limit": 1},
            intent={
                "request": "Find narrow lifecycle support",
                "hard_constraints": ["installable"],
            },
        )
        report = run(planning.plan(req, caps or manifest(), saved=False), None)
        path = Path(report["trace"]["state"])
        s = engine.validate_state(io.read(path))
        s = engine.host_results(
            s,
            {
                "schema_version": 1,
                "results": [
                    envelope(
                        report,
                        payload={
                            "results": [
                                {
                                    "url": "https://example.org/popular",
                                    "fields": {"stars": 100000},
                                },
                                {
                                    "url": "https://example.org/niche",
                                    "fields": {
                                        "content": "Exact lifecycle instructions",
                                        "stars": 2,
                                    },
                                },
                                {
                                    "url": "https://example.org/niche?utm_source=other",
                                    "fields": {"stars": 3},
                                },
                            ]
                        },
                    )
                ],
            },
        )
        engine.checkpoint(s, path)
        return s, path

    def decision(self, s):
        rows = selection.candidates(s)
        direct = rows[1]
        a = {
            "candidate_id": direct["candidate_id"],
            "evidence_digest": direct["evidence_digest"],
            "fit": "direct",
            "inspected": True,
            "verification": "verified",
            "constraints": {"installable": "met"},
            "reason": "Content contains lifecycle procedure",
            "references": [direct["url"]],
        }
        return {
            "schema_version": 1,
            "run_id": s["run_id"],
            "assessments": [a],
            "selected": [
                {"candidate_id": direct["candidate_id"], "reason": "Narrow task fit"}
            ],
            "criteria": "Task fit then inspected contents; popularity unused",
            "gaps": ["Other candidate uninspected; provider tail unknown"],
            "answer_status": "partial",
        }

    def test_relevance_selection_reaches_past_display_and_preserves_observations(self):
        s, path = self.pool()
        first = engine.report(s)
        self.assertEqual(len(first["candidates"]), 1)
        page = execute(
            parser().parse_args(
                ["candidates", "--state", str(path), "--offset", "1", "--limit", "1"]
            )
        )
        self.assertEqual(page["candidates"][0]["url"], "https://example.org/niche")
        decision = self.decision(s)
        data = self.root / "selection.json"
        io.atomic(data, decision)
        result = execute(
            parser().parse_args(
                ["select", "--state", str(path), "--selection", str(data)]
            )
        )
        self.assertEqual(result["selected"][0]["url"], "https://example.org/niche")
        self.assertEqual(
            [o["rank"] for o in result["selected"][0]["observations"]], [2, 3]
        )
        self.assertEqual(
            [o["fields"]["stars"] for o in result["selected"][0]["observations"]],
            [2, 3],
        )
        self.assertEqual(result["diagnostics"]["counts"]["duplicate_merged"], 1)
        self.assertIn(
            "3 fetched → 2 unique → 1 inspected → 1 selected", result["receipt"]
        )
        saved = engine.validate_state(io.read(path))
        self.assertEqual(saved["inline_receipt"], result["receipt"])
        self.assertEqual(
            saved["plan"]["request"]["intent"]["request"],
            "Find narrow lifecycle support",
        )

    def test_invalid_selection_is_atomic_and_uncertainty_is_explicit(self):
        s, path = self.pool()
        baseline = copy.deepcopy(s)
        for change, error in [
            ({"inspected": False, "fit": "irrelevant"}, "Uninspected"),
            ({"constraints": {"installable": "failed"}}, "no failed"),
            ({"references": ["https://invented.invalid"]}, "this run"),
            ({"evidence_digest": "stale"}, "changed"),
        ]:
            with self.subTest(change=change):
                data = self.decision(s)
                data["assessments"][0].update(change)
                with self.assertRaisesRegex(c.Invalid, error):
                    selection.apply(s, data)
                self.assertEqual(s, baseline)
        data = self.decision(s)
        data["assessments"][0]["constraints"]["installable"] = "unknown"
        selection.apply(s, data)
        self.assertEqual(
            engine.report(s)["selected"][0]["assessment"]["constraints"]["installable"],
            "unknown",
        )

    def test_new_observations_require_reassessment(self):
        s, path = self.pool()
        selection.apply(s, self.decision(s))
        s["outcomes"]["f1"]["results"][1]["observations"][0]["fields"]["content"] = (
            "Changed content"
        )
        report = engine.report(s)
        self.assertEqual(report["selected"], [])
        self.assertEqual(report["diagnostics"]["counts"]["selected"], 0)
        self.assertEqual(report["diagnostics"]["answer_status"], "pending")

    def test_later_inspection_invalidates_the_saved_candidate_assessment(self):
        caps = manifest()
        caps["capabilities"] += manifest("web.fetch")["capabilities"]
        s, path = self.pool(caps)
        selection.apply(s, self.decision(s))
        engine.extend(
            s,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    {
                        "id": "read",
                        "area": "web",
                        "source": "web",
                        "operation": "page.inspect",
                        "filters": {"url": "https://example.org/niche"},
                        "provider": "host-fetch",
                    }
                ],
            },
        )
        report = engine.drive(s, path)
        s = engine.host_results(
            s,
            {
                "schema_version": 1,
                "results": [
                    envelope(
                        report,
                        payload={
                            "results": [
                                {
                                    "url": "https://example.org/niche",
                                    "fields": {"content": "Updated instructions"},
                                }
                            ]
                        },
                    )
                ],
            },
        )
        report = engine.report(s)
        self.assertEqual(report["selected"], [])
        self.assertEqual(report["diagnostics"]["answer_status"], "pending")
        self.assertEqual(report["diagnostics"]["counts"]["fetched"], 3)
        self.assertEqual(report["diagnostics"]["counts"]["unique"], 2)

    def test_fetched_count_includes_rows_rejected_before_fallback(self):
        responses = [
            stdio.BytesIO(b'{"organic": [{}]}'),
            stdio.BytesIO(b'{"results": [{"url": "https://example.org/good"}]}'),
        ]
        with (
            patch.dict(
                os.environ, {"SERPER_API_KEY": "fake-serper", "EXA_API_KEY": "fake-exa"}
            ),
            patch("urllib.request.OpenerDirector.open", side_effect=responses),
        ):
            report = run(
                planning.plan(
                    request(
                        choices={"prefer_provider": "serper"},
                        authorized_paid=["serper", "exa"],
                    ),
                    saved=False,
                ),
                None,
            )
        self.assertEqual(report["diagnostics"]["counts"]["fetched"], 2)
        self.assertEqual(report["diagnostics"]["counts"]["unique"], 1)
        self.assertEqual(report["diagnostics"]["counts"]["rejected_schema"], 1)
        self.assertEqual(len(report["attempts"]), 2)
        self.assertIn("1 rejected", report["receipt"])

    def test_unrelated_content_cannot_validate_another_candidate(self):
        s, _ = self.pool()
        data = self.decision(s)
        other = selection.candidates(s)[0]
        data["assessments"][0].update(
            candidate_id=other["candidate_id"], evidence_digest=other["evidence_digest"]
        )
        data["selected"][0]["candidate_id"] = other["candidate_id"]
        with self.assertRaisesRegex(c.Invalid, "this candidate"):
            selection.apply(s, data)

    def test_trace_write_failure_prevents_provider_calls(self):
        bad = self.root / "not-a-directory"
        bad.write_text("occupied")
        with patch.object(registry, "execute") as transport:
            with self.assertRaises(OSError):
                run(planning.plan(request(), manifest(), saved=False), bad / "run.json")
            transport.assert_not_called()

    def test_journal_failure_leaves_pending_work_without_transport_replay(self):
        with (
            patch.dict(os.environ, {"SERPER_API_KEY": "fixture-secret"}),
            patch(
                "urllib.request.OpenerDirector.open",
                return_value=stdio.BytesIO(b'{"organic": []}'),
            ) as network,
            patch.object(
                diagnostics, "append", side_effect=OSError("journal unavailable")
            ),
        ):
            with self.assertRaisesRegex(OSError, "journal unavailable"):
                run(
                    planning.plan(
                        request(
                            choices={"provider": "serper"}, authorized_paid=["serper"]
                        ),
                        saved=False,
                    ),
                    None,
                )
            network.assert_not_called()
        paths = list(self.root.glob("agent-search/runs/*/*/state.json"))
        self.assertEqual(len(paths), 1)
        state = engine.validate_state(io.read(paths[0]))
        self.assertEqual(len(state["pending"]), 1)
        self.assertEqual(state["usage"]["calls"], 0)
        with patch("urllib.request.OpenerDirector.open") as network:
            report = engine.drive(state, paths[0])
            self.assertEqual(len(report["pending"]), 1)
            network.assert_not_called()

    def test_secret_and_raw_response_content_are_not_durable(self):
        s, path = self.pool()
        with patch.dict(os.environ, {"SERPER_API_KEY": "fixture-secret-value"}):
            s["outcomes"]["f1"]["raw"] = {"stdout": "private native stderr/body"}
            s["outcomes"]["f1"]["detail"] = (
                "failure fixture-secret-value Authorization: Bearer abc123"
            )
            engine.checkpoint(s, path)
            body = path.read_text()
            self.assertNotIn("fixture-secret-value", body)
            self.assertIn("Bearer abc123", body)
            self.assertNotIn("private native stderr/body", body)
            engine.validate_state(io.read(path))

    def test_authentication_search_terms_are_not_credentials(self):
        for terms in (
            "Bearer token refresh flow",
            "password=reset UX",
            "rotate api_key: header",
        ):
            with self.subTest(terms=terms):
                result = run(
                    planning.plan(request(terms=terms), manifest(), saved=False), None
                )
                self.assertEqual(len(result["pending"]), 1)

    def test_reported_digest_survives_redaction_and_resume(self):
        report = run(planning.plan(request(), manifest(), saved=False), None)
        path = Path(report["trace"]["state"])
        state = engine.validate_state(io.read(path))
        with patch.dict(os.environ, {"SERPER_API_KEY": "private-fixture-value"}):
            state = engine.host_results(
                state,
                {
                    "schema_version": 1,
                    "results": [
                        envelope(
                            report,
                            payload={
                                "results": [
                                    {
                                        "url": "https://example.org/auth",
                                        "excerpt": "Send Authorization: Bearer example123",
                                        "fields": {
                                            "content": "private-fixture-value",
                                            "api_key": "unrecognized-secret",
                                        },
                                    }
                                ]
                            },
                        )
                    ],
                },
            )
            engine.checkpoint(state, path)
            live = engine.report(state)
            saved = engine.report(engine.validate_state(io.read(path)))
            self.assertEqual(
                live["candidates"][0]["evidence_digest"],
                saved["candidates"][0]["evidence_digest"],
            )
            self.assertNotIn("private-fixture-value", json.dumps(live))
            self.assertNotIn("unrecognized-secret", json.dumps(live))
            self.assertTrue(live["diagnostics"]["redactions"])
            self.assertIn("Bearer example123", path.read_text())
            row = live["candidates"][0]
            decision = {
                "schema_version": 1,
                "run_id": live["run_id"],
                "assessments": [
                    {
                        "candidate_id": row["candidate_id"],
                        "evidence_digest": row["evidence_digest"],
                        "fit": "direct",
                        "inspected": True,
                        "verification": "unverified",
                        "constraints": {},
                        "reason": "Authentication example with redacted fields",
                        "references": [row["url"]],
                    }
                ],
                "selected": [
                    {"candidate_id": row["candidate_id"], "reason": "Provisional fit"}
                ],
                "criteria": "Task fit",
                "gaps": ["Credential fields redacted"],
                "answer_status": "partial",
            }
            decision_path = self.root / "auth-selection.json"
            io.atomic(decision_path, decision)
            selected = execute(
                parser().parse_args(
                    ["select", "--state", str(path), "--selection", str(decision_path)]
                )
            )
            self.assertEqual(len(selected["selected"]), 1)

    def test_mixed_retention_receipt_preserves_counts_and_discloses_omission(self):
        state, path = self.pool()
        decision = self.decision(state)
        selection.apply(state, decision)
        engine.extend(
            state,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    {
                        "id": "restricted",
                        "area": "web",
                        "source": "web",
                        "operation": "page.discover",
                        "provider": "brave",
                        "terms": "query",
                    }
                ],
            },
        )
        restricted = copy.deepcopy(state["outcomes"]["f1"])
        restricted["facet_id"] = "restricted"
        restricted["results"] = identity.normalize(
            [{"url": "https://restricted.invalid/content"}],
            state["plan"]["jobs"][-1]["facet"],
            registry.REGISTRY["brave"],
            engine.now(),
        )
        restricted["count"] = restricted["fetched_count"] = 1
        restricted["provider"] = "brave"
        state["outcomes"]["restricted"] = restricted
        engine.checkpoint(state, path)
        live = engine.report(state)
        saved = engine.report(engine.validate_state(io.read(path)))
        self.assertEqual(saved["diagnostics"]["counts"]["selected"], 1)
        self.assertEqual(live["diagnostics"]["counts"]["selected"], 1)
        self.assertIn("omits all selection text", live["receipt"])
        self.assertNotIn("Narrow task fit", path.read_text())

    def test_credential_parameters_are_redacted_in_reference_lists(self):
        value = diagnostics.redact(
            {
                "references": ["https://example.org/?access_token=unknown-value"],
                "content_evidence": ["https://example.org/?api_key=another-value"],
            }
        )
        self.assertNotIn("unknown-value", json.dumps(value))
        self.assertNotIn("another-value", json.dumps(value))
        self.assertIn("%5Bredacted%5D", value["references"][0])

    def test_constraint_labels_are_not_mistaken_for_credential_fields(self):
        self.assertEqual(
            diagnostics.redact(
                {
                    "constraints": {"no API key required": "failed"},
                    "fields": {"api_key": "private"},
                }
            ),
            {
                "constraints": {"no API key required": "failed"},
                "fields": {"api_key": "[redacted]"},
            },
        )

    def test_restricted_retention_does_not_claim_zero_unique_or_store_decisions(self):
        with (
            patch.dict(os.environ, {"BRAVE_SEARCH_API_KEY": "fixture"}),
            patch.object(
                registry,
                "execute",
                return_value={
                    "status": "success",
                    "results": [
                        {
                            "url": "https://restricted.invalid/secret",
                            "excerpt": "restricted body",
                        }
                    ],
                },
            ),
        ):
            result = run(
                planning.plan(
                    request(choices={"provider": "brave"}, authorized_paid=["brave"]),
                    saved=False,
                ),
                None,
            )
        path = Path(result["trace"]["state"])
        self.assertNotIn("restricted.invalid", path.read_text())
        self.assertNotIn("restricted body", path.read_text())
        report = engine.report(engine.validate_state(io.read(path)))
        self.assertEqual(report["diagnostics"]["counts"]["fetched"], 1)
        self.assertIsNone(report["diagnostics"]["counts"]["unique"])
        self.assertIn("unknown unique", report["receipt"])

    def test_interrupted_transport_has_private_started_event_without_response_body(
        self,
    ):
        trace = diagnostics.trace_info(self.root / "transport/state.json")
        work = {
            "run_id": "run",
            "attempt_id": "attempt",
            "facet_id": "f",
            "provider": "serper",
        }
        with patch.dict(os.environ, {"SERPER_API_KEY": "fixture-secret-value"}):
            with self.assertRaises(KeyboardInterrupt), diagnostics.attempt(trace, work):
                with diagnostics.transport(
                    "http", {"url": "https://example.org/?api_key=fixture-secret-value"}
                ):
                    raise KeyboardInterrupt()
        path = Path(trace["events"])
        events = [json.loads(line) for line in path.read_text().splitlines()]
        self.assertEqual([e["phase"] for e in events], ["started", "finished"])
        self.assertEqual(events[-1]["status"], "interrupted_or_failed")
        self.assertNotIn("fixture-secret-value", path.read_text())
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
