"""Source selection through public request, transport and saved-run boundaries."""

import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from searchlib import contracts as c, engine, planning, registry, selection, identity
from searchlib.adapters import web
from searchlib.cli import execute, parser


def facet(source="site:example.org/forum", area="social", **extra):
    return {
        "id": "first",
        "source": source,
        "area": area,
        "operation": "post.discover",
        "terms": "repair experience",
        **extra,
    }


def plan(facets=None, **extra):
    return planning.plan(
        {"schema_version": 1, "facets": facets or [facet()], **extra},
        {
            "schema_version": 1,
            "capabilities": [
                {
                    "id": "web.search",
                    "tool": "fixture.search",
                    "cost": "free",
                    "operations": list(web.WEB_OPS),
                }
            ],
        },
        saved=False,
    )


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        env = patch.dict(
            os.environ,
            {"XDG_CONFIG_HOME": self.tmp.name, "XDG_STATE_HOME": self.tmp.name},
        )
        env.start()
        self.addCleanup(env.stop)

    def test_new_site_cross_area_and_capabilities(self):
        for source, area in [
            ("site:news.hada.io", "social"),
            ("github", "social"),
            ("site:example.org/auctions", "shopping"),
        ]:
            operation = "product.discover" if area == "shopping" else "post.discover"
            p = plan([facet(source, area, operation=operation)])
            self.assertIn("host-web", p["jobs"][0]["routes"])
        rows = registry.capabilities({"schema_version": 1, "capabilities": []})
        provider = next(p for p in rows if p["id"] == "serper")
        self.assertEqual(provider["source_scope"], "public-web")
        self.assertEqual(provider["sources"], [])
        with self.assertRaisesRegex(c.Invalid, "unsupported"):
            plan([facet(provider="hn")])

    def test_scope_intersection_and_segments(self):
        f = facet("reddit", filters={"domains": ["old.reddit.com/r/repair"]})
        plan([f])
        self.assertEqual(
            web.keywords(f), "repair experience (site:old.reddit.com/r/repair)"
        )
        self.assertTrue(
            engine.source_matches("https://old.reddit.com/r/repair/comments/a", f)
        )
        for url in [
            "https://old.reddit.com/r/repairs/a",
            "https://reddit.com/r/repair/a",
            "https://old.reddit.com.evil.org/r/repair/a",
        ]:
            self.assertFalse(engine.source_matches(url, f), url)
        with self.assertRaisesRegex(c.Invalid, "scope|intersection"):
            plan([facet("reddit", filters={"domains": ["example.org"]})])
        crossed = facet("site:example.org/a", filters={"domains": ["sub.example.org"]})
        plan([crossed])
        self.assertEqual(
            web.keywords(crossed), "repair experience (site:sub.example.org/a)"
        )

    def test_inspection_target_respects_scope_before_dispatch(self):
        with self.assertRaisesRegex(c.Invalid, "scope"):
            plan(
                [
                    facet(
                        "site:example.org/forum",
                        operation="page.inspect",
                        filters={"url": "https://example.org/private"},
                    )
                ]
            )
        p = plan(
            [
                facet(
                    "web",
                    "web",
                    operation="page.inspect",
                    filters={"url": "https://reddit.com/r/repair"},
                )
            ],
            choices={"exclude_source": ["reddit"]},
        )
        self.assertTrue(p["jobs"][0]["excluded"])

    def test_required_source_cannot_expand_an_explicit_source_pin(self):
        with self.assertRaisesRegex(c.Invalid, "selected sources"):
            plan(
                [facet("reddit"), facet("github", id="other")],
                choices={"source": ["reddit"], "require_source": ["github"]},
            )

    def test_encoded_control_and_separator_scopes_are_rejected(self):
        for source in [
            "site:example.org/a%00b",
            "site:example.org/a%5Cb",
            "site:example.org/a%2fb",
        ]:
            with self.subTest(source=source), self.assertRaises(c.Invalid):
                plan([facet(source)])

    def test_malformed_scopes_rejected_before_calls(self):
        for source in [
            "typo",
            "site:user@host.org",
            "site:host.org?q=x",
            "site:host.org#x",
            "site:https://host.org",
            "site:127.0.0.1",
            "site:localhost",
            "site:host.org/forum/../private",
            "site:host.org:8080",
            "site:host.org/a%252fb",
        ]:
            with self.subTest(source=source), self.assertRaises(c.Invalid):
                plan([facet(source)])

    def test_idn_and_path_case(self):
        f = facet("site:BÜCHER.de/Forum")
        plan([f])
        self.assertTrue(engine.source_matches("https://xn--bcher-kva.de/Forum/post", f))
        self.assertFalse(
            engine.source_matches("https://xn--bcher-kva.de/forum/post", f)
        )
        self.assertTrue(
            engine.source_matches(
                "https://example.org/docs/100%25", facet("site:example.org/docs")
            )
        )

    def test_encoded_destination_host_cannot_bypass_exclusion(self):
        from searchlib.sources import destination_allowed

        for url in ("https:///post", "https://:443/post"):
            self.assertFalse(destination_allowed(url, facet("web")))
        self.assertFalse(
            destination_allowed(
                "https://ex%61mple.org/post", facet("web"), ["site:example.org"]
            )
        )
        self.assertTrue(
            destination_allowed(
                "https://ex%61mple.org/forum/post", facet("site:example.org/forum")
            )
        )

    def test_ambiguous_unicode_scopes_require_explicit_punycode(self):
        for host in ("faß.de", "FAẞ.de", "ς.gr", "ϲ.gr", "a\u200cb.de", "a\u200db.de"):
            with self.subTest(host=host), self.assertRaisesRegex(c.Invalid, "punycode"):
                plan([facet("site:" + host)])
        f = facet("site:xn--fa-hia.de")
        plan([f])
        self.assertEqual(web.keywords(f), "repair experience (site:xn--fa-hia.de)")
        self.assertTrue(engine.source_matches("https://xn--fa-hia.de/post", f))
        self.assertFalse(engine.source_matches("https://fass.de/post", f))

    def test_ambiguous_unicode_destinations_fail_closed(self):
        for source, excluded, expected in (
            ("site:fass.de", [], ["https://fass.de/post"]),
            ("web", ["site:xn--fa-hia.de"], ["https://fass.de/post"]),
        ):
            with self.subTest(source=source):
                s = engine.new_state(
                    plan([facet(source)], choices={"exclude_source": excluded})
                )
                work = engine.reserve(
                    s,
                    s["plan"]["jobs"][0]["facet"],
                    registry.REGISTRY["host-web"],
                    None,
                )
                engine.settle(
                    s,
                    work,
                    {
                        "status": "success",
                        "results": [
                            {"url": "https://faß.de/post"},
                            {"url": "https://fa%C3%9F.de/post"},
                            {
                                "url": "https://fass.de/redirect",
                                "fields": {"final_url": "https://faß.de/post"},
                            },
                            {"url": "https://xn--fa-hia.de/post"},
                            {"url": "https://fass.de/post"},
                        ],
                    },
                )
                self.assertEqual(
                    [r["url"] for r in engine.report(s)["results"]], expected
                )
                self.assertEqual(s["outcomes"]["first"]["rejected_source"], 4)

    def test_uppercase_greek_hosts_keep_unambiguous_idna_mapping(self):
        for source in ("site:ΑΣ-1.gr", "site:xn---1-b9b6e.gr"):
            with self.subTest(source=source):
                f = facet(source)
                plan([f])
                self.assertEqual(
                    web.keywords(f), "repair experience (site:xn---1-b9b6e.gr)"
                )
        for url in (
            "https://ΑΣ-1.gr/post",
            "https://ΑΣ-1.gr:443/post",
            "https://%CE%91%CE%A3-1.gr/post",
            "https://xn---1-b9b6e.gr/post",
        ):
            with self.subTest(url=url):
                self.assertTrue(
                    engine.source_matches(url, facet("site:xn---1-b9b6e.gr"))
                )

    def test_alias_constraints_and_global_pins(self):
        with self.assertRaisesRegex(c.Invalid, "conflict"):
            plan(
                [facet("reddit")],
                choices={"source": ["reddit"], "exclude_source": ["site:reddit.com"]},
            )
        p = plan([facet("site:old.reddit.com")], choices={"exclude_source": ["reddit"]})
        self.assertTrue(p["jobs"][0]["excluded"])
        s = engine.new_state(plan([facet("reddit")]))
        budget, deadline = copy.deepcopy(s["plan"]["budget"]), s["deadline"]
        engine.extend(
            s,
            {"schema_version": 1, "prepared_jobs": [facet("site:zenn.dev", id="next")]},
        )
        self.assertEqual(s["plan"]["budget"], budget)
        self.assertEqual(s["deadline"], deadline)
        pinned = engine.new_state(
            plan([facet("reddit")], choices={"source": ["reddit"]})
        )
        before = copy.deepcopy(pinned)
        with self.assertRaisesRegex(c.Invalid, "selected sources"):
            engine.extend(
                pinned,
                {
                    "schema_version": 1,
                    "prepared_jobs": [facet("site:zenn.dev", id="next")],
                },
            )
        self.assertEqual(pinned, before)

    def test_source_exclusions_apply_to_general_results_and_redirects(self):
        s = engine.new_state(
            plan(
                [facet("web", "web", operation="page.discover")],
                choices={"exclude_source": ["reddit"]},
            )
        )
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["host-web"], None
        )
        engine.settle(
            s,
            work,
            {
                "status": "success",
                "results": [
                    {"url": "https://old.reddit.com/r/repair/comments/a"},
                    {
                        "url": "https://example.org/redirect",
                        "fields": {"final_url": "https://reddit.com/r/repair"},
                    },
                    {"url": "https://example.org/guide"},
                ],
            },
        )
        self.assertEqual(
            [r["url"] for r in engine.report(s)["results"]],
            ["https://example.org/guide"],
        )

    def test_ambiguous_destination_cannot_bypass_exclusion(self):
        s = engine.new_state(
            plan(
                [facet("web", "web", operation="page.discover")],
                choices={"exclude_source": ["reddit"]},
            )
        )
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["host-web"], None
        )
        engine.settle(
            s,
            work,
            {
                "status": "success",
                "results": [
                    {"url": "https://reddit.com/r%2frepair"},
                    {"url": "https://reddit.com/a%00b"},
                ],
            },
        )
        self.assertEqual(selection.candidates(s), [])
        self.assertTrue(
            engine.source_matches("https://reddit.com/r/a%25b/x", facet("reddit"))
        )
        for url in [
            "https://reddit.com/r//comments/x",
            "https://my_sub.reddit.com/r/x",
            "https://reddit.com/r/./x",
        ]:
            s = engine.new_state(
                plan(
                    [facet("web", "web", operation="page.discover")],
                    choices={"exclude_source": ["site:reddit.com/r/private"]},
                )
            )
            work = engine.reserve(
                s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["host-web"], None
            )
            engine.settle(s, work, {"status": "success", "results": [{"url": url}]})
            if "my_sub" not in url:
                self.assertEqual(selection.candidates(s), [])

    def test_source_decisions_cannot_claim_another_facets_outcome(self):
        d = {
            "id": "d",
            "family": "community",
            "sources": ["reddit"],
            "reason": "owner reports",
            "disposition": "selected",
            "facet_ids": ["first"],
        }
        with self.assertRaisesRegex(c.Invalid, "scope"):
            plan([facet("site:news.hada.io")], source_decisions=[d])
        with self.assertRaisesRegex(c.Invalid, "Only selected"):
            plan([facet("reddit")], source_decisions=[{**d, "disposition": "deferred"}])
        plan(
            [facet("web", filters={"domains": ["old.reddit.com"]})],
            source_decisions=[d],
        )

    def test_redirect_read_supports_original_candidate_without_reidentifying_it(self):
        s = engine.new_state(plan([facet("web", "web", operation="page.discover")]))
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["host-web"], None
        )
        original, final = "https://example.org/old", "https://example.org/current"
        engine.settle(s, work, {"status": "success", "results": [{"url": original}]})
        candidate = selection.candidates(s)[0]
        engine.extend(
            s,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    facet(
                        "web",
                        "web",
                        id="read",
                        operation="page.inspect",
                        filters={"url": original},
                    )
                ],
            },
        )
        work = engine.reserve(
            s, s["plan"]["jobs"][-1]["facet"], registry.REGISTRY["host-fetch"], None
        )
        engine.settle(
            s,
            work,
            {
                "status": "success",
                "results": [
                    {
                        "url": original,
                        "fields": {
                            "final_url": final,
                            "content": "Observed current document",
                        },
                    }
                ],
            },
        )
        updated = selection.candidates(s)[0]
        self.assertEqual(updated["candidate_id"], candidate["candidate_id"])
        self.assertEqual(updated["content_evidence"], [final])
        self.assertNotEqual(updated["evidence_digest"], candidate["evidence_digest"])
        engine.validate_state(engine.persisted(s))

    def test_alias_and_site_identity_keep_one_candidate(self):
        s = engine.new_state(
            plan([facet("reddit"), facet("site:reddit.com", id="second")])
        )
        for j in s["plan"]["jobs"]:
            work = engine.reserve(s, j["facet"], registry.REGISTRY["host-web"], None)
            engine.settle(
                s,
                work,
                {
                    "status": "success",
                    "results": [
                        {"url": "https://www.reddit.com/r/repair/comments/abc/thread"}
                    ],
                },
            )
        rows = selection.candidates(s)
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0]["observations"]), 2)

    def test_context_decisions_extend_and_report(self):
        intent = {
            "request": "Korean discussion",
            "context": [
                {"name": "answer_language", "value": "en", "origin": "explicit"}
            ],
            "breadth": "wide",
        }
        decision = {
            "id": "first-choice",
            "family": "technical-community",
            "sources": ["site:news.hada.io"],
            "reason": "Korean technical discussion",
            "disposition": "selected",
            "facet_ids": ["first"],
        }
        s = engine.new_state(
            plan(
                [facet("site:news.hada.io", terms="음성 인식", query_language="ko")],
                intent=intent,
                source_decisions=[decision],
            )
        )
        self.assertEqual(s["plan"]["jobs"][0]["facet"]["terms"], "음성 인식")
        self.assertNotIn("language", s["plan"]["jobs"][0]["facet"]["filters"])
        extra = {
            "id": "later",
            "family": "video",
            "sources": ["youtube"],
            "reason": "No inspection allowance",
            "disposition": "deferred",
            "facet_ids": [],
        }
        engine.extend(
            s, {"schema_version": 1, "prepared_jobs": [], "source_decisions": [extra]}
        )
        report = engine.report(s)
        self.assertEqual(report["exploration"]["context"], intent["context"])
        self.assertEqual(
            report["exploration"]["decisions"][-1]["disposition"], "deferred"
        )
        before = copy.deepcopy(s)
        with self.assertRaisesRegex(c.Invalid, "facet"):
            engine.extend(
                s,
                {
                    "schema_version": 1,
                    "prepared_jobs": [],
                    "source_decisions": [
                        {**extra, "id": "bad", "facet_ids": ["unknown"]}
                    ],
                },
            )
        self.assertEqual(s, before)

    def test_cli_source_selection_and_discovery_operation(self):
        with self.assertRaisesRegex(c.Invalid, "source|facet"):
            execute(
                parser().parse_args(
                    ["query", "repair", "--area=social", "--inspect", "--no-defaults"]
                )
            )
        p = execute(
            parser().parse_args(
                [
                    "query",
                    "SSD",
                    "--area=shopping",
                    "--source=site:example.org",
                    "--operation=product.discover",
                    "--inspect",
                    "--no-defaults",
                ]
            )
        )
        self.assertEqual(p["jobs"][0]["facet"]["operation"], "product.discover")
        native = execute(
            parser().parse_args(
                [
                    "query",
                    "SQLite",
                    "--area=social",
                    "--provider=hn",
                    "--inspect",
                    "--no-defaults",
                ]
            )
        )
        self.assertEqual(native["jobs"][0]["facet"]["source"], "hn")

    def test_cli_site_operation_error_names_explicit_area(self):
        args = [
            "query",
            "SSD",
            "--source=site:example.org/auctions",
            "--operation=product.discover",
            "--inspect",
            "--no-defaults",
        ]
        with self.assertRaisesRegex(c.Invalid, r"--area.*shopping"):
            execute(parser().parse_args(args))
        self.assertEqual(list(Path(self.tmp.name).rglob("state.json")), [])
        p = execute(parser().parse_args([*args, "--area=shopping"]))
        self.assertEqual(p["jobs"][0]["facet"]["area"], "shopping")
        self.assertEqual(p["jobs"][0]["facet"]["operation"], "product.discover")

    def test_legacy_checkpoint_settlement_preserves_identity(self):
        s = json.loads(
            (
                Path(__file__).parent / "fixtures/source-selection-legacy-state.json"
            ).read_text()
        )
        engine.validate_state(s)
        expected = "cebf551971279b3c42b1124d2f18afe7fe24708fbf11f07c72bf09d728b80cab"
        self.assertEqual(selection.candidates(s)[0]["candidate_id"], expected)
        work = next(iter(s["pending"].values()))
        data = {
            "schema_version": 1,
            "results": [
                {
                    **{
                        key: work[key]
                        for key in ("run_id", "work_item_id", "attempt_id")
                    },
                    "status": "success",
                    "observed_at": "2026-10-18T10:00:00+00:00",
                    "payload": {
                        "results": [
                            {
                                "url": "https://www.reddit.com/r/repair/comments/abc/thread",
                                "fields": {
                                    "content": "Repair guide",
                                    "final_url": "https://old.reddit.com/r/repair/comments/abc/thread/",
                                },
                            }
                        ]
                    },
                }
            ],
        }
        s = engine.host_results(s, data)
        self.assertEqual(engine.host_results(s, data), s)
        self.assertEqual(selection.candidates(s)[0]["candidate_id"], expected)
        self.assertEqual(
            selection.candidates(s)[0]["content_evidence"],
            ["https://www.reddit.com/r/repair/comments/abc/thread"],
        )
        engine.validate_state(s)
        engine.extend(
            s, {"schema_version": 1, "prepared_jobs": [facet("reddit", id="next")]}
        )
        engine.validate_state(s)
        before = copy.deepcopy(s)
        with self.assertRaisesRegex(c.Invalid, "Legacy"):
            engine.extend(
                s, {"schema_version": 1, "prepared_jobs": [facet(id="new-scope")]}
            )
        self.assertEqual(s, before)

    def test_legacy_web_comments_checkpoint_can_extend(self):
        s = json.loads(
            (
                Path(__file__).parent / "fixtures/legacy-web-comments-state.json"
            ).read_text()
        )
        engine.validate_state(s)
        pending = copy.deepcopy(s["pending"])
        engine.extend(
            s,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    facet("web", "web", id="new-discovery", operation="page.discover")
                ],
            },
        )
        engine.validate_state(s)
        self.assertEqual(s["pending"], pending)
        self.assertEqual(s["plan"]["jobs"][0]["facet"]["operation"], "comments.read")

    def test_legacy_required_source_checkpoint_can_extend_within_original_scope(self):
        s = json.loads(
            (
                Path(__file__).parent / "fixtures/legacy-required-source-state.json"
            ).read_text()
        )
        engine.validate_state(s)
        before = copy.deepcopy(s)
        engine.extend(
            s,
            {
                "schema_version": 1,
                "prepared_jobs": [
                    facet(
                        "reddit",
                        id="read-reddit",
                        operation="page.inspect",
                        filters={
                            "url": "https://www.reddit.com/r/repair/comments/123/example"
                        },
                    ),
                    facet("hn", id="required-discovery"),
                ],
            },
        )
        engine.validate_state(s)
        self.assertEqual(
            [j["facet"]["source"] for j in s["plan"]["jobs"]],
            ["reddit", "hn", "reddit", "hn"],
        )
        self.assertEqual(s["plan"]["jobs"][:2], before["plan"]["jobs"])
        for key in ("usage", "pending", "deadline", "run_id"):
            self.assertEqual(s[key], before[key])
        self.assertTrue(s["pending"])
        self.assertEqual(s["plan"]["budget"], before["plan"]["budget"])
        self.assertEqual(s["plan"]["request"]["authorized_paid"], ["exa"])
        before = copy.deepcopy(s)
        with self.assertRaisesRegex(c.Invalid, "selected sources"):
            engine.extend(
                s, {"schema_version": 1, "prepared_jobs": [facet("x", id="outside")]}
            )
        self.assertEqual(s, before)

    def test_native_repository_metadata_does_not_bypass_public_host_scope(self):
        s = engine.new_state(plan([facet("github", "code", operation="code.discover")]))
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["github-code"], None
        )
        engine.settle(
            s,
            work,
            {
                "status": "success",
                "results": [
                    {
                        "url": "https://github.example.org/a/b/blob/main/x.py",
                        "kind": "code",
                        "fields": {"repo": "a/b", "path": "x.py"},
                    }
                ],
            },
        )
        self.assertEqual(selection.candidates(s), [])

    def test_expansion_preserves_pending_reservations_and_authorization(self):
        s = engine.new_state(
            plan(
                [facet("reddit")],
                authorized_paid=["exa"],
                choices={"via": "host"},
                budget={
                    "calls": 3,
                    "discovery": 2,
                    "enrichment": 1,
                    "opens": 1,
                    "wall_seconds": 120,
                },
            )
        )
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["host-web"], None
        )
        before = copy.deepcopy(s)
        engine.extend(s, {"schema_version": 1, "prepared_jobs": [facet(id="second")]})
        for key in ("usage", "pending", "deadline", "run_id"):
            self.assertEqual(s[key], before[key])
        self.assertIn(work["work_item_id"], s["pending"])
        self.assertEqual(s["plan"]["budget"], before["plan"]["budget"])
        self.assertEqual(s["plan"]["request"]["authorized_paid"], ["exa"])

    def test_qualified_identity_separates_markets_instances_and_variants(self):
        def key(url, **extra):
            return identity.identity(
                {
                    "source": "web",
                    "url": url,
                    "kind": "offer",
                    "observed_at": "2026-10-18",
                    "fields": {"item_id": "same", **extra},
                },
                2,
            )

        self.assertNotEqual(
            key("https://amazon.com/dp/B000000001"),
            key("https://amazon.de/dp/B000000001"),
        )
        self.assertNotEqual(
            key("https://amazon.com/dp/B000000001", variant="1TB"),
            key("https://amazon.com/dp/B000000001", variant="2TB"),
        )
        self.assertNotEqual(
            key("https://social.example.org/posts/1"),
            key("https://social.example.net/posts/1"),
        )
        self.assertNotEqual(
            key("https://example.org/posts/1"), key("https://example.org/posts/2")
        )
        self.assertNotEqual(
            key("https://github.com/a/b/blob/" + "a" * 40 + "/x.py"),
            key("https://github.com/a/b/blob/" + "b" * 40 + "/x.py"),
        )

    def test_host_scope_binding_and_explicit_probe(self):
        manifest = {
            "schema_version": 1,
            "capabilities": [
                {
                    "id": "web.search",
                    "tool": "fixture.search",
                    "cost": "free",
                    "operations": ["post.discover"],
                    "sources": ["reddit"],
                }
            ],
        }
        p = planning.plan(
            {
                "schema_version": 1,
                "facets": [
                    facet("site:old.reddit.com"),
                    facet("site:example.org", id="other"),
                ],
            },
            manifest,
            saved=False,
        )
        self.assertIn("host-web", p["jobs"][0]["routes"])
        self.assertNotIn("host-web", p["jobs"][1]["routes"])
        rows = registry.capabilities(manifest)
        self.assertEqual(
            next(p for p in rows if p["id"] == "host-web")["probe"]["source"], "web"
        )
        self.assertIsNone(next(p for p in rows if p["id"] == "host-fetch")["probe"])

    def test_retention_omits_exploration_prose_and_preserves_resumability(self):
        decision = {
            "id": "d",
            "family": "forums",
            "sources": ["reddit"],
            "reason": "restricted wording",
            "disposition": "selected",
            "facet_ids": ["first"],
        }
        s = engine.new_state(
            plan(
                [facet("reddit")],
                source_decisions=[decision],
                intent={
                    "request": "repair",
                    "context": [
                        {
                            "name": "detail",
                            "value": "restricted wording",
                            "origin": "assumption",
                        }
                    ],
                },
            )
        )
        work = engine.reserve(
            s, s["plan"]["jobs"][0]["facet"], registry.REGISTRY["brave"], None
        )
        engine.settle(
            s,
            work,
            {"status": "success", "results": [{"url": "https://reddit.com/r/repair"}]},
        )
        durable = engine.persisted(s)
        self.assertNotIn("restricted wording", json.dumps(durable))
        self.assertTrue(engine.report(durable)["exploration"]["retention_omitted"])
        engine.validate_state(durable)

    def test_metadata_redaction_recomputes_durable_plan_fingerprint(self):
        s = engine.new_state(
            plan(
                intent={
                    "request": "repair",
                    "context": [
                        {
                            "name": "public_note",
                            "value": "fixture-newly-known-secret",
                            "origin": "assumption",
                        }
                    ],
                }
            )
        )
        with patch.dict(os.environ, {"FIXTURE_API_KEY": "fixture-newly-known-secret"}):
            durable = engine.persisted(s)
            self.assertNotIn("fixture-newly-known-secret", json.dumps(durable))
            engine.validate_state(durable)

    def test_context_bounds_and_operation_defaults_reject_without_mutation(self):
        for context in [
            [{"name": "x", "value": "a" * 513, "origin": "explicit"}],
            [{"name": "x", "value": {"nested": "x"}, "origin": "explicit"}],
            [{"name": "x", "value": "x", "origin": "invented"}],
        ]:
            with self.assertRaises(c.Invalid):
                plan(intent={"request": "repair", "context": context})
        with self.assertRaisesRegex(c.Invalid, "per-query"):
            execute(
                parser().parse_args(
                    [
                        "query",
                        "--operation=post.discover",
                        "--save-defaults",
                        "--source=reddit",
                    ]
                )
            )
        self.assertFalse(
            (Path(self.tmp.name) / "agent-search/preferences.json").exists()
        )


if __name__ == "__main__":
    unittest.main()
