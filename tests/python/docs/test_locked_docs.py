from .fixtures import ARCHIVED, REJECTED, SUPERSEDED, DocsFixture


LINK_BODY = "# Link Source\n\nSee [target.md](target.md).\nSee [other.md](other.md)."


class LockedDocsTests(DocsFixture):
    def setUp(self):
        super().setUp()
        self.doc("adr/0001-decision.md", "# Decision\n\nAccepted decision body.", status="accepted", kind="adr")
        self.doc("plans/old-plan.md", "# Old Plan\n\nHistorical body.", status="archived", **ARCHIVED)
        self.doc("plans/link-source.md", LINK_BODY, status="archived", kind="research", **ARCHIVED)
        self.doc("plans/target.md", "# Target\n\nTarget body.", status="proposed")
        self.doc("plans/other.md", "# Other\n\nOther body.", status="proposed")
        self.base = self.commit()

    def test_locked_move_can_rewrite_link_destinations_and_path_labels(self):
        for update_labels in (False, True):
            with self.subTest(update_labels=update_labels):
                self.move("plans/link-source.md", "research/link-source.md")
                body = LINK_BODY.replace(
                    "[target.md](target.md)",
                    "[../plans/target.md](../plans/target.md)" if update_labels else "[target.md](../plans/target.md)",
                ).replace(
                    "[other.md](other.md)",
                    "[../plans/other.md](../plans/other.md)" if update_labels else "[other.md](../plans/other.md)",
                )
                self.doc("research/link-source.md", body, status="archived", kind="research", **ARCHIVED)
                self.validate(base=self.base)
                self.git("restore", "--source", self.base, "--staged", "--worktree", "--", "docs")

    def test_partially_rewritten_move_cannot_retarget_an_unchanged_link(self):
        self.move("plans/link-source.md", "research/link-source.md")
        body = LINK_BODY.replace("[target.md](target.md)", "[../plans/target.md](../plans/target.md)")
        self.doc("research/link-source.md", body, status="archived", kind="research", **ARCHIVED)
        self.doc("research/other.md", "# Wrong Other", kind="research")
        self.validate(base=self.base, error="body edits are blocked")

    def test_historical_links_follow_detected_skill_moves_outside_docs(self):
        old = self.repo / "old-skills/example/SKILL.md"
        old.parent.mkdir(parents=True)
        old.write_text("---\nname: example\ndescription: Example skill.\n---\n")
        body = "# Old Plan\n\nSee [example](../../old-skills/example/SKILL.md)."
        self.doc("plans/old-plan.md", body, status="archived", **ARCHIVED)
        base = self.commit()
        new = self.repo / "agent-marketplace/packages/example/skills/example/SKILL.md"
        new.parent.mkdir(parents=True)
        self.git("mv", str(old), str(new))
        self.doc("plans/old-plan.md", body.replace("old-skills/example", "agent-marketplace/packages/example/skills/example"),
                 status="archived", **ARCHIVED)
        self.validate(base=base)
        self.doc("plans/old-plan.md", body.replace("old-skills/example", "agent-marketplace/packages/example/skills/example") + "\nChanged history.",
                 status="archived", **ARCHIVED)
        self.validate(base=base, error="body edits are blocked")

    def test_unchanged_move_cannot_silently_retarget_relative_links(self):
        self.move("plans/link-source.md", "research/link-source.md")
        self.doc("research/target.md", "# Wrong Target", kind="research")
        self.doc("research/other.md", "# Wrong Other", kind="research")
        self.validate(base=self.base, error="locked doc move must preserve Markdown link targets")

    def test_accepted_decision_can_be_renamed_but_its_body_stays_locked(self):
        self.move("adr/0001-decision.md", "adr/0001-renamed-decision.md")
        self.validate(base=self.base)
        self.doc("adr/0001-renamed-decision.md", "# Decision\n\nEdited accepted decision body.", status="accepted", kind="adr")
        self.validate(base=self.base, error="body edits are blocked")

    def test_accepted_and_archived_documents_cannot_be_deleted_or_edited(self):
        for name in ("adr/0001-decision.md", "plans/old-plan.md"):
            with self.subTest(name=name):
                path = self.docs / name
                original = path.read_text()
                path.unlink()
                self.validate(base=self.base, error="locked historical doc cannot be deleted")
                path.write_text(original + "\nEdited body.\n")
                self.validate(base=self.base, error="body edits are blocked")
                path.write_text(original)
        self.validate(base=self.base)

    def test_metadata_only_edits_are_allowed_and_missing_base_is_diagnosed(self):
        self.doc("plans/old-plan.md", "# Old Plan\n\nHistorical body.", status="archived",
                 status_detail="metadata-only edits are allowed", **ARCHIVED)
        self.validate(base=self.base)
        self.validate(base="missing-ref", error="base ref does not exist")

    def test_status_and_document_type_transitions_follow_the_lifecycle_contract(self):
        cases = (
            ("adr", "accepted", "adr", "active", "accepted ADRs can only remain accepted or close"),
            ("adr", "accepted", "adr", "current", "accepted ADRs can only remain accepted or close"),
            ("adr", "active", "adr", "current", "ADRs must not use status 'current'"),
            ("research", "draft", "research", "current", "invalid status transition"),
            ("plan", "proposed", "plan", "archived", "invalid status transition"),
            ("plan", "accepted", "plan", "active", None),
            ("reference", "current", "research", "current", "invalid doc_type transition"),
            ("adr", "active", "adr", "accepted", None),
            ("plan", "active", "reference", "current", None),
            ("plan", "active", "runbook", "current", None),
            ("plan", "rejected", "plan", "archived", None),
            ("plan", "superseded", "plan", "archived", None),
        )
        closed = {"archived": ARCHIVED, "rejected": REJECTED, "superseded": SUPERSEDED}
        for before_kind, before_status, after_kind, after_status, error in cases:
            with self.subTest(before=(before_kind, before_status), after=(after_kind, after_status)):
                self.doc("plans/transition.md", kind=before_kind, status=before_status, **closed.get(before_status, {}))
                base = self.commit()
                self.doc("plans/transition.md", kind=after_kind, status=after_status, **closed.get(after_status, {}))
                self.validate(base=base, error=error)

    def test_closing_a_draft_allows_metadata_changes_but_no_body_edit(self):
        self.doc("plans/open-plan.md", "# Open Plan\n\nDraft body.", status="draft")
        base = self.commit()
        self.doc("plans/open-plan.md", "# Open Plan\n\nEdited while closing.", status="archived", **ARCHIVED)
        self.validate(base=base, error="body edits are blocked")
        self.doc("plans/open-plan.md", "# Open Plan\n\nDraft body.", status="archived", **ARCHIVED)
        self.validate(base=base)
