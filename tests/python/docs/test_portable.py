import shutil
import sys

from tests.support.python import ROOT
from .fixtures import DocsFixture


class PortableLifecycleTests(DocsFixture):
    def setUp(self):
        super().setUp()
        self.script = self.repo / "scripts/validate-doc-lifecycle.py"
        self.script.parent.mkdir()
        shutil.copyfile(
            ROOT / "agent-marketplace/packages/core/skills/document-lifecycle/scripts/validate-doc-lifecycle.py",
            self.script,
        )

    def portable(self, *args, expected_status=0):
        return self.command(
            [sys.executable, str(self.script), *args],
            cwd=self.repo, expected_status=expected_status,
        )

    def test_standalone_copy_generates_inventory_and_rejects_stale_output(self):
        self.doc("dev/guide.md", "# Developer Guide", status="current", kind="reference",
                 summary="Developer setup.")
        self.portable("--write-inventory")
        inventory = (self.docs / "inventory.md").read_text()
        self.assertIn("[Developer Guide](dev/guide.md) | current | Developer setup.", inventory)
        self.portable()
        self.doc("dev/guide.md", "# Updated Guide", status="current", kind="reference")
        result = self.portable(expected_status=1)
        self.assertIn(b"inventory is stale", result.stderr)
        self.portable("--write-inventory")
        self.portable()
        self.portable("--due")

    def test_standalone_copy_preserves_history_and_retirement_guarantees(self):
        self.doc("adr/0001-decision.md", "# Decision\n\nOriginal decision.",
                 status="accepted", kind="adr")
        plan = self.doc("plans/task.md", "# Task", status="active")
        self.index()
        self.portable("--write-inventory")
        self.git("add", ".")
        self.git("commit", "-qm", "adopt lifecycle")
        adr = self.docs / "adr/0001-decision.md"
        original = adr.read_text()
        adr.write_text(original.replace("Original decision.", "Changed decision."))
        result = self.portable("--base", "HEAD", expected_status=1)
        self.assertIn(b"body edits are blocked", result.stderr)
        adr.write_text(original)
        plan.unlink()
        self.doc("index.md", "# Documentation", status="current", kind="index")
        self.portable("--write-inventory")
        result = self.portable("--base", "HEAD", expected_status=1)
        self.assertIn(b"deleted doc needs a retirement row in docs/retired.md for plans/task.md", result.stderr)
        self.ledger(("2026-10-17", "plans/task.md", "Task", "archived", "Nothing to retain."))
        self.portable("--write-inventory")
        self.portable("--base", "HEAD")

    def test_custom_root_and_invalid_root_are_explicit(self):
        custom = self.repo / "guides"
        self.docs.rename(custom)
        self.portable("--docs-root", str(custom), "--write-inventory")
        self.portable("--docs-root", str(custom))
        self.assertIn("Every document under guides/", (custom / "inventory.md").read_text())
        for path in (self.repo / "missing", self.work):
            with self.subTest(path=path):
                result = self.portable("--docs-root", str(path), expected_status=2)
                self.assertIn(b"existing directory within --repo-root", result.stderr)

    def test_custom_root_retires_documents_in_a_docs_subdirectory(self):
        custom = self.repo / "guides"
        self.docs.rename(custom)
        self.docs = custom
        plan = self.doc("docs/task.md", "# Task", status="active")
        self.portable("--docs-root", str(custom), "--write-inventory")
        self.git("add", ".")
        self.git("commit", "-qm", "adopt custom docs root")
        plan.unlink()
        ledger = self.ledger(("2026-10-17", "docs/task.md", "Task", "archived", "Nothing to retain."))
        self.portable("--docs-root", str(custom), "--write-inventory")
        self.portable("--docs-root", str(custom), "--base", "HEAD")
        ledger.write_text(ledger.read_text().replace("| docs/task.md |", "| guides/docs/task.md |"))
        result = self.portable("--docs-root", str(custom), expected_status=1)
        self.assertIn(b"ledger Path must be relative to guides/", result.stderr)

    def test_non_markdown_adapter_exception_belongs_to_the_adopter(self):
        self.write("validate-doc-lifecycle.py", "print('local adapter')\n")
        self.portable("--write-inventory")
        result = self.portable(expected_status=1)
        self.assertIn(b"docs/validate-doc-lifecycle.py: non-Markdown content", result.stderr)
        self.validate()
