from .fixtures import ARCHIVED, DocsFixture


class BranchHistoryTests(DocsFixture):
    def setUp(self):
        super().setUp()
        self.base = self.commit("base")

    def test_branch_created_document_cannot_change_body_when_closing(self):
        self.doc("plans/branch-created.md", "# Branch Created\n\nActive body.")
        self.commit("add active plan")
        self.doc("plans/branch-created.md", "# Branch Created\n\nEdited while closing.", status="archived", **ARCHIVED)
        self.commit("close with body edit")
        self.validate(base=self.base, error="body edits are blocked because this change closes the doc")

    def test_moved_closure_is_checked_when_git_does_not_classify_it_as_a_rename(self):
        path = self.doc("plans/moved-plan.md", "# Moved Plan\n\nOriginal short body.")
        base = self.commit("base plan")
        path.unlink()
        self.doc("references/moved-plan.md", "# Moved Plan\n\nA completely different closure body that should not be treated as a metadata-only move.",
                 status="archived", kind="reference", **ARCHIVED)
        self.commit("move and close with body edit")
        changes = self.git("diff", "--find-renames", "--name-status", base, "HEAD", "--", "docs")
        self.assertIn("D\tdocs/plans/moved-plan.md", changes)
        self.assertIn("A\tdocs/references/moved-plan.md", changes)
        self.validate(base=base, error="body edits are blocked because this change closes the doc")

    def test_malformed_intermediate_document_is_not_hidden_by_a_valid_closure(self):
        self.write("plans/branch-created.md", "# Branch Created\n\nMalformed intermediate body.\n")
        self.commit("add malformed plan")
        self.doc("plans/branch-created.md", "# Branch Created\n\nEdited while closing.", status="archived", **ARCHIVED)
        self.commit("close malformed plan")
        self.validate(base=self.base, error="missing YAML frontmatter")

    def test_empty_status_commit_is_rejected(self):
        path = self.doc("plans/empty-status.md", "# Empty Status")
        base = self.commit("valid status")
        path.write_text('---\nstatus:\ndoc_type: plan\n---\n\n# Empty Status\n')
        self.commit("empty status")
        self.validate(base=base, error="status must be one of")

    def test_invalid_added_plan_is_not_hidden_by_a_later_status_fix(self):
        self.doc("plans/bad-current-plan.md", "# Bad Current Plan", status="current")
        self.commit("add invalid current plan")
        self.doc("plans/bad-current-plan.md", "# Bad Current Plan")
        self.commit("fix current plan status")
        self.validate(base=self.base, error="completed plans must be archived or superseded")

    def test_editing_while_open_then_renaming_again_and_closing_is_allowed(self):
        self.doc("plans/foo.md", "# Foo\n\nOriginal body.")
        base = self.commit("base plan")
        self.move("plans/foo.md", "references/foo.md")
        self.doc("references/foo.md", "# Foo\n\nEdited while open.")
        self.commit("move and edit while open")
        self.move("references/foo.md", "runbooks/foo.md")
        self.doc("runbooks/foo.md", "# Foo\n\nEdited while open.", status="archived", **ARCHIVED)
        self.commit("close after intermediate rename")
        self.validate(base=base)

    def test_closure_hidden_behind_a_new_identity_is_rejected_in_worktree_and_history(self):
        path = self.doc("plans/old-name.md", "# Old Name\n\nOriginal body.")
        base = self.commit("base plan")
        path.unlink()
        self.doc("plans/new-name.md", "# New Name\n\nEdited while closing.", status="archived", **ARCHIVED)
        error = "closed doc added while deleting open doc"
        self.validate(base=base, error=error)
        self.commit("hide close behind rename")
        self.validate(base=base, error=error)

    def test_broken_body_link_commit_is_not_hidden_by_adding_its_target_later(self):
        self.doc("plans/broken-link.md", "# Broken Link\n\nSee [missing](missing.md).")
        self.commit("add broken link")
        self.doc("plans/missing.md", "# Missing", kind="reference")
        self.commit("add missing target")
        self.validate(base=self.base, error="Markdown link target must exist: missing.md")

    def test_bad_guidance_commit_is_not_hidden_by_a_later_metadata_fix(self):
        self.doc("plans/bad-guidance.md", "# Bad Guidance", status="archived", closed="2026-05-11", current_guidance="missing.md")
        self.commit("add bad guidance")
        self.doc("plans/bad-guidance.md", "# Bad Guidance", status="archived", **ARCHIVED)
        self.commit("fix guidance")
        self.validate(base=self.base, error="current_guidance target must be a repo-local relative path that exists: missing.md")

    def test_new_archived_document_cannot_be_edited_in_a_later_commit(self):
        self.doc("plans/branch-archived.md", "# Branch Archived\n\nArchived body.", status="archived", **ARCHIVED)
        self.commit("add archived plan")
        self.doc("plans/branch-archived.md", "# Branch Archived\n\nEdited archived body.", status="archived", **ARCHIVED)
        self.commit("edit archived plan body")
        self.validate(base=self.base, error="body edits are blocked")

    def test_unrelated_duplicate_body_cannot_disguise_a_locked_document_deletion(self):
        path = self.doc("adr/0001-decision.md", "# Decision\n\nShared body.", status="accepted", kind="adr")
        base = self.commit("base decision")
        path.unlink()
        self.doc("adr/0002-unrelated.md", "# Unrelated\n\nShared body.", status="accepted", kind="adr")
        self.commit("replace with unrelated duplicate body")
        self.validate(base=base, error="locked historical doc cannot be deleted")
