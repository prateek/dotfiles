from .fixtures import ARCHIVED, REJECTED, SUPERSEDED, DocsFixture
from .invalid_frontmatter import INVALID_DOCS


class CurrentTreeTests(DocsFixture):
    def test_accepts_the_document_type_status_matrix_and_inline_successor_lists(self):
        allowed = {
            "adr": "proposed active accepted superseded rejected archived",
            "plan": "draft proposed accepted active superseded rejected archived",
            "runbook": "active current superseded archived",
            "reference": "active current superseded archived",
            "research": "draft active current superseded archived",
            "convention": "active current superseded archived",
        }
        for kind, statuses in allowed.items():
            for number, status in enumerate(statuses.split(), start=1):
                metadata = {"archived": ARCHIVED, "superseded": SUPERSEDED, "rejected": REJECTED}.get(status, {})
                name = f"adr/{number:04d}-{status}.md" if kind == "adr" else f"matrix/{kind}-{status}.md"
                self.doc(name, status=status, kind=kind, **metadata)
        self.doc("index.md", "# Documentation Index", status="active", kind="index")
        self.doc("retired.md", "# Retirement Ledger\n\n| Closed | Path | Doc | Status | Where it went |\n| --- | --- | --- | --- | --- |\n",
                 status="active", kind="index")
        self.doc("plans/inline-guidance.md", status="archived", kind="research",
                 closed="2026-05-11", current_guidance=["../current-guide.md"])
        self.validate()
        self.validate(docs_root=self.docs)

    def test_rejects_invalid_type_status_combinations(self):
        for kind, status, error in (
            ("adr", "current", "ADRs must not use status 'current'"),
            ("plan", "current", "completed plans must be archived or superseded"),
            ("runbook", "proposed", "doc_type 'runbook' cannot use status 'proposed'"),
            ("reference", "accepted", "doc_type 'reference' cannot use status 'accepted'"),
            ("research", "proposed", "doc_type 'research' cannot use status 'proposed'"),
            ("convention", "proposed", "doc_type 'convention' cannot use status 'proposed'"),
            ("index", "archived", "doc_type index must use status active or current"),
        ):
            with self.subTest(kind=kind, status=status):
                name = "adr/0001-invalid.md" if kind == "adr" else "matrix/invalid.md"
                self.doc(name, status=status, kind=kind, **(ARCHIVED if status == "archived" else {}))
                self.validate(error=error)

    def test_index_and_adr_document_types_are_tied_to_their_paths(self):
        self.doc("plans/not-an-index.md", status="current", kind="index")
        self.validate(error="plans/not-an-index.md: doc_type index is for exactly index.md, inventory.md, retired.md at the docs root")
        self.doc("plans/not-an-index.md", status="active", kind="adr")
        self.validate(error="plans/not-an-index.md: doc_type adr is for exactly the adr/NNNN-slug.md files")
        (self.docs / "plans/not-an-index.md").unlink()
        self.doc("adr/0001-plan-shaped.md", status="active", kind="plan")
        self.validate(error="adr/0001-plan-shaped.md: doc_type adr is for exactly the adr/NNNN-slug.md files")

    def test_rejects_each_invalid_frontmatter_example_with_its_diagnostic(self):
        for name, text, error in INVALID_DOCS:
            with self.subTest(example=name):
                path = self.write("plans/" + name, text)
                try:
                    self.validate(error=error)
                finally:
                    path.unlink()

    def test_rejects_successor_paths_that_escape_the_repository(self):
        (self.work / "outside.md").write_text("# Outside\n")
        self.doc("plans/escaping.md", status="archived", closed="2026-05-11",
                 current_guidance="../../../outside.md")
        self.validate(error="current_guidance target must be a repo-local relative path that exists")

    def test_custom_root_accepts_its_own_index_and_dev_directory(self):
        self.docs = self.repo / "guides"
        self.doc("guide.md", "# Guide", status="current", kind="reference")
        self.validate(docs_root=self.docs)
        self.doc("dev/guide.md", "# Custom Dev Guide", status="current", kind="reference")
        self.validate(docs_root=self.docs)

    def test_docs_root_requires_an_index_with_the_index_document_type(self):
        (self.docs / "index.md").unlink()
        self.validate(error="docs root must include index.md", refresh_index=False)
        self.doc("index.md", "# Documentation Index", status="current", kind="reference")
        self.validate(error="docs/index.md: doc_type index is for exactly", refresh_index=False)
        self.doc("index.md", "# Documentation Index", status="archived", kind="index",
                 closed="2026-05-11", current_guidance="current-guide.md")
        self.validate(error="doc_type index must use status active or current", refresh_index=False)

    def test_non_markdown_capture_is_refused_but_gitignored_bytecode_is_ignored(self):
        capture = self.write("plans/capture.html", "<html></html>\n")
        self.validate(error="non-Markdown content is not allowed under docs/")
        capture.unlink()
        (self.repo / ".gitignore").write_text("__pycache__/\n")
        self.write("__pycache__/validate-doc-lifecycle.cpython-313.pyc", "ignored bytecode\n")
        self.validate()

    def test_research_data_subfolders_may_hold_non_markdown_files(self):
        self.write("research/topic/data/flows.json", "[]\n")
        self.write("research/topic/data/integrations/manifest.json", "{}\n")
        self.validate()
        stray = self.write("research/topic/flows.json", "[]\n")
        self.validate(error="research/topic/flows.json: non-Markdown content is not allowed under docs/")
        stray.unlink()
        self.write("plans/data/capture.html", "<html></html>\n")
        self.validate(error="plans/data/capture.html: non-Markdown content is not allowed under docs/")

    def test_index_is_a_router_whose_links_must_resolve(self):
        self.doc("plans/unrouted.md", status="proposed")
        self.index()
        path = self.docs / "index.md"
        path.write_text("\n".join(line for line in path.read_text().splitlines() if "plans/unrouted.md" not in line) + "\n")
        self.validate(refresh_index=False)
        with path.open("a") as stream:
            stream.write("- [Missing](plans/missing.md)\n")
        self.validate(error="docs/index.md: Markdown link target must exist: plans/missing.md", refresh_index=False)

    def test_index_frontmatter_links_do_not_create_dead_links(self):
        self.docs = self.repo / "hidden"
        self.doc("guide.md", "# Guide", status="current", kind="reference")
        self.doc("index.md", "# Hidden Index\n\n- [Index](index.md)", status="current", kind="index",
                 status_detail="See [gone](missing.md).")
        self.validate(docs_root=self.docs, refresh_index=False)

    def test_inventory_is_generated_from_frontmatter_and_must_be_fresh(self):
        self.doc("plans/listed.md", "# Listed Plan\n\nBody.", status="proposed", summary="Covers the listed thing.")
        self.doc("plans/parked.md", "# Parked Plan\n\nBody.", status="draft", status_detail="Parked: waiting on hardware.")
        self.validate()
        inventory = (self.docs / "inventory.md").read_text()
        self.assertIn("| [Listed Plan](plans/listed.md) | proposed | Covers the listed thing. |  |", inventory)
        self.assertIn("## Parked plans", inventory)
        self.assertIn("[Parked Plan](plans/parked.md)", inventory.split("## Parked plans")[1])
        self.doc("plans/listed.md", "# Listed Plan\n\nBody.", status="proposed", summary="Covers something else.")
        self.validate(error="docs/inventory.md: inventory is stale; run just docs-inventory",
                      refresh_index=False, refresh_inventory=False)
        (self.docs / "inventory.md").unlink()
        self.validate(error="docs/inventory.md: inventory is missing; run just docs-inventory",
                      refresh_index=False, refresh_inventory=False)

    def test_every_document_needs_a_summary(self):
        self.write("plans/no-summary.md", "---\nstatus: proposed\ndoc_type: plan\n---\n\n# No Summary\n")
        self.validate(error="plans/no-summary.md: summary is required")

    def test_body_links_and_retired_path_references_ignore_fenced_examples(self):
        for body, error in (
            ("See [missing](missing.md).", "Markdown link target must exist: missing.md"),
            ("Read docs/dev/old-plan.md.", "stale moved docs path reference"),
        ):
            with self.subTest(body=body):
                self.doc("plans/body.md", "# Body\n\n" + body, status="proposed")
                self.validate(error=error)
                self.doc("plans/body.md", "# Body\n\n```markdown\n" + body + "\n```", status="proposed")
                self.validate()

    def test_closed_docs_are_not_held_to_inline_link_targets(self):
        body = "# Body\n\nSee [gone](missing.md)."
        for label, status, kind in (("proposed plan", "proposed", "plan"), ("accepted adr", "accepted", "adr")):
            with self.subTest(checked=label):
                self.doc("plans/body.md", body, status=status, kind=kind)
                self.validate(error="Markdown link target must exist: missing.md")
        for label, status, metadata in (
            ("archived", "archived", ARCHIVED),
            ("superseded", "superseded", SUPERSEDED),
            ("rejected", "rejected", REJECTED),
        ):
            with self.subTest(closed=label):
                self.doc("plans/body.md", body, status=status, **metadata)
                self.validate()

    def test_retired_docs_dev_is_rejected_even_without_frontmatter(self):
        path = self.doc("dev/foo.md", "# Retired Dev Folder", status="proposed")
        self.validate(error="docs/dev is retired")
        path.write_text("# Retired Dev Folder Without Frontmatter\n")
        self.validate(error="docs/dev is retired")
