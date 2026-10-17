from .fixtures import ARCHIVED, DocsFixture

DONE_ROW = ("2026-05-12", "plans/done-plan.md", "Done Plan", "archived", "Rationale in [the guide](current-guide.md).")


class RetirementTests(DocsFixture):
    def setUp(self):
        super().setUp()
        self.doc("adr/0001-decision.md", "# Decision\n\nSee [the plan](../plans/done-plan.md).", status="accepted", kind="adr",
                 related=["../plans/done-plan.md"])
        self.doc("plans/done-plan.md", "# Done Plan\n\nHistorical body.", status="archived", **ARCHIVED)
        self.doc("plans/open-plan.md", "# Open Plan\n\nSee [the plan](done-plan.md).")
        self.ledger()
        self.base = self.commit()

    def retire_done_plan(self, repoint_open_plan=True):
        (self.docs / "plans/done-plan.md").unlink()
        self.ledger(DONE_ROW)
        if repoint_open_plan:
            self.doc("plans/open-plan.md", "# Open Plan\n\nSee [the ledger](../retired.md).")

    def test_retired_paths_may_be_linked_only_from_locked_docs_and_the_ledger(self):
        self.retire_done_plan(repoint_open_plan=False)
        self.validate(base=self.base, error="plans/open-plan.md: Markdown link target must exist: done-plan.md")
        self.doc("plans/open-plan.md", "# Open Plan\n\nSee [the ledger](../retired.md).")
        self.validate(base=self.base)
        self.doc("plans/open-plan.md", "# Open Plan\n\nSee [the ledger](../retired.md).", related=["done-plan.md"])
        self.validate(base=self.base, error="plans/open-plan.md: related target must be a repo-local relative path that exists: done-plan.md")
        self.doc("plans/open-plan.md", "# Open Plan\n\nSee [the ledger](../retired.md).")
        (self.docs / "retired.md").unlink()
        self.validate(base=self.base, error="deleted doc needs a retirement row")

    def test_ledger_links_may_rot_and_an_open_doc_may_leave_docs(self):
        self.retire_done_plan()
        self.ledger(("2026-05-12", "plans/done-plan.md", "Done Plan", "archived", "Moved to [a skill](../skills/gone/SKILL.md)."))
        self.validate(base=self.base)
        (self.repo / "elsewhere").mkdir()
        self.git("mv", "docs/plans/open-plan.md", "elsewhere/open-plan.md")
        self.validate(base=self.base)

    def test_ledger_rows_are_append_only_and_name_paths_that_are_gone(self):
        self.retire_done_plan()
        retired = self.commit("retire")
        self.validate(base=self.base)
        self.ledger()
        self.validate(base=retired, error="retirement rows are append-only; restore the row for plans/done-plan.md")
        self.ledger(("2026-05-12", "plans/done-plan.md", "Done Plan (title fixed)", "archived", "Rationale in [the guide](current-guide.md)."))
        self.validate(base=retired)
        self.doc("plans/done-plan.md", "# Done Plan\n\nRestored.", status="archived", **ARCHIVED)
        self.validate(base=retired, error="retired path still exists; retired docs come back under a new name: plans/done-plan.md")
        (self.docs / "plans/done-plan.md").unlink()
        self.ledger()
        self.commit("drop the row")
        self.validate(base=retired, error="retirement rows are append-only; restore the row for plans/done-plan.md")

    def test_ledger_rows_are_checked_for_shape(self):
        self.ledger(("yesterday", "plans/done-plan.md", "Done Plan", "archived", "Gone."))
        self.validate(error="ledger Closed must be an ISO date")
        self.ledger(("2026-05-12", "docs/plans/done-plan.md", "Done Plan", "active", "Gone."))
        self.validate(error="ledger Path must be relative to docs/")
        self.validate(error="ledger Status must be one of")
        self.doc("retired.md", "# Retirement Ledger\n\n| Path | Doc |\n| --- | --- |\n", status="current", kind="index")
        self.validate(error="ledger table must have columns")

    def test_a_locked_body_may_gain_exactly_one_supersession_banner(self):
        self.doc("adr/0002-successor.md", "# Successor\n\nBody.", status="accepted", kind="adr")
        self.doc("adr/0003-proposal.md", "# Proposal\n\nBody.", status="proposed", kind="adr")
        base = self.commit("add successor")

        def supersede(name, body):
            self.doc(name, body, status="superseded", kind="adr", closed="2026-05-12", superseded_by="0002-successor.md")

        banner = "> Superseded by [ADR 0002](0002-successor.md).\n\n"
        body = "# Decision\n\n" + banner + "See [the plan](../plans/done-plan.md)."
        supersede("adr/0001-decision.md", body)
        supersede("adr/0003-proposal.md", "# Proposal\n\n" + banner + "Body.")
        self.validate(base=base)
        self.commit("banner")
        self.validate(base=base)
        supersede("adr/0001-decision.md", body + "\nMore.")
        self.validate(base=base, error="body edits are blocked")
        supersede("adr/0001-decision.md", "# Decision\n\n> Superseded by [elsewhere](0003-other.md).\n\nSee [the plan](../plans/done-plan.md).")
        self.validate(base=base, error="body edits are blocked")

    def test_adr_numbers_are_never_reused(self):
        self.doc("adr/0001-second-decision.md", "# Second Decision\n\nBody.", status="proposed", kind="adr")
        self.validate(base=self.base, error="adr/0001-second-decision.md: ADR number 0001 is already used by docs/adr/0001-decision.md")
        self.commit("duplicate number")
        self.validate(base=self.base, error="ADR number 0001 is already used")
        self.validate()

    def test_due_report_lists_parked_and_stale_plans_and_settled_research(self):
        self.doc("plans/parked-plan.md", "# Parked\n\nBody.", status="draft", status_detail="Parked: waiting on hardware.")
        self.doc("research/orphan.md", "# Orphan\n\nBody.", kind="research")
        self.doc("research/informed.md", "# Informed\n\nBody.", kind="research", related=["../adr/0001-decision.md"])
        self.doc("research/live.md", "# Live\n\nBody.", kind="research", related=["../plans/open-plan.md"])
        self.doc("plans/open-plan.md", "# Open Plan\n\nAn older body.")
        self.git("add", ".")
        self.git("commit", "-q", "-m", "old", "--", "docs/plans/parked-plan.md", "docs/research/orphan.md", "docs/plans/open-plan.md",
                 env={"GIT_COMMITTER_DATE": "2026-01-01T00:00:00", "GIT_AUTHOR_DATE": "2026-01-01T00:00:00"})
        self.commit("rest")
        report = self.validator("--due").stdout.decode()
        self.assertIn("Parked plans past a quarter: 1", report)
        self.assertIn("docs/plans/parked-plan.md: parked, last commit 2026-01-01", report)
        self.assertIn("Open plans with no commit in a quarter: 1", report)
        self.assertIn("docs/plans/open-plan.md: open, last commit 2026-01-01", report)
        self.assertIn("Research due for a decision: 2", report)
        self.assertIn("docs/research/orphan.md: no plan or ADR consumer in related, added 2026-01-01", report)
        self.assertIn("docs/research/informed.md: every consumer is settled (docs/adr/0001-decision.md)", report)
        self.assertNotIn("research/live.md", report)
