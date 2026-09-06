from .fixtures import ARCHIVED, DocsFixture


class MergeHistoryTests(DocsFixture):
    def setUp(self):
        super().setUp()
        self.base = self.commit("base")

    def advance_base_and_feature(self):
        self.git("branch", "feature")
        self.doc("plans/master-plan.md", "# Master Plan\n\nClosed on the base branch after the feature branch point.",
                 status="archived", **ARCHIVED)
        advanced_base = self.commit("advance base docs")
        self.git("checkout", "-q", "feature")
        self.doc("plans/feature-plan.md", "# Feature Plan")
        feature_tip = self.commit("add feature docs")
        return advanced_base, feature_tip

    def test_diverged_feature_uses_the_merge_base_instead_of_the_advanced_base_tree(self):
        advanced_base, _ = self.advance_base_and_feature()
        self.validate(base=advanced_base)

    def test_synthetic_review_merge_accepts_valid_feature_and_advanced_base_docs(self):
        advanced_base, feature_tip = self.advance_base_and_feature()
        self.git("checkout", "-q", "--detach", advanced_base)
        self.git("checkout", "-q", feature_tip, "--", "docs/plans/feature-plan.md")
        self.merge_tree(advanced_base, feature_tip)
        self.validate(base=advanced_base)

    def test_nonlinear_branch_accepts_a_closed_document_from_its_side_parent(self):
        self.git("branch", "side")
        self.doc("plans/open.md", "# Open")
        feature_tip = self.commit("add open plan")
        self.git("checkout", "-q", "side")
        self.doc("plans/closed.md", "# Closed\n\nClosed on a side branch.", status="archived", **ARCHIVED)
        side_tip = self.commit("add closed plan")
        self.git("checkout", "-q", "--detach", feature_tip)
        self.git("checkout", "-q", side_tip, "--", "docs/plans/closed.md")
        self.merge_tree(feature_tip, side_tip)
        self.validate(base=self.base)

    def test_merge_resolution_cannot_edit_locked_content_from_its_non_first_parent(self):
        self.git("branch", "side")
        self.doc("plans/open.md", "# Open")
        feature_tip = self.commit("add open plan")
        self.git("checkout", "-q", "side")
        self.doc("adr/0001-side-decision.md", "# Side Decision\n\nAccepted on a side branch.", status="accepted", kind="adr")
        side_tip = self.commit("add side decision")
        self.git("checkout", "-q", "--detach", feature_tip)
        self.git("checkout", "-q", side_tip, "--", "docs/adr/0001-side-decision.md")
        self.doc("adr/0001-side-decision.md", "# Side Decision\n\nEdited in merge resolution.", status="accepted", kind="adr")
        self.merge_tree(feature_tip, side_tip)
        self.validate(base=self.base, error="body edits are blocked")

    def test_push_merge_resolution_is_validated_against_the_push_before_ref(self):
        self.doc("adr/0001-decision.md", "# Decision\n\nAccepted body.", status="accepted", kind="adr")
        self.commit("base decision")
        self.git("branch", "feature")
        self.doc("another-guide.md", "# Another Guide", status="current", kind="reference")
        push_before = self.commit("advance first parent")
        self.git("checkout", "-q", "feature")
        self.doc("plans/feature-plan.md", "# Feature Plan")
        feature_tip = self.commit("add feature docs")
        self.git("checkout", "-q", "--detach", push_before)
        self.git("checkout", "-q", feature_tip, "--", "docs/plans/feature-plan.md")
        self.doc("adr/0001-decision.md", "# Decision\n\nEdited in merge resolution.", status="accepted", kind="adr")
        self.merge_tree(push_before, feature_tip)
        self.validate(base=push_before, error="body edits are blocked")

    def test_feature_merge_of_advanced_base_cannot_edit_a_locked_common_document(self):
        self.doc("plans/base-plan.md", "# Base Plan\n\nHistorical body.", status="archived", **ARCHIVED)
        self.commit("base plan")
        self.git("branch", "feature")
        self.doc("plans/master-plan.md", "# Master Plan")
        advanced_base = self.commit("advance base")
        self.git("checkout", "-q", "feature")
        self.doc("plans/feature-plan.md", "# Feature Plan")
        feature_tip = self.commit("add feature plan")
        self.git("checkout", "-q", "--detach", feature_tip)
        self.git("checkout", "-q", advanced_base, "--", "docs/plans/master-plan.md")
        self.doc("plans/base-plan.md", "# Base Plan\n\nEdited in feature merge resolution.", status="archived", **ARCHIVED)
        self.merge_tree(feature_tip, advanced_base)
        self.validate(base=advanced_base, error="body edits are blocked")
