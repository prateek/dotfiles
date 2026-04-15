import sys
import tempfile
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

import audit as audit_module  # noqa: E402


class AuditFreshOutputTests(unittest.TestCase):
    def test_reset_audit_output_removes_existing_generated_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = Path(tmp) / "repo"
            output = repo_root / ".audit"
            (output / "docs").mkdir(parents=True)
            (output / "docs" / "stale.md").write_text("old", encoding="utf-8")

            audit_module._reset_audit_output(output=output, repo_root=repo_root)

            self.assertFalse(output.exists())

    def test_reset_audit_output_rejects_repo_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = Path(tmp) / "repo"
            repo_root.mkdir()

            with self.assertRaisesRegex(RuntimeError, "refusing to reset unsafe audit output path"):
                audit_module._reset_audit_output(output=repo_root, repo_root=repo_root)


if __name__ == "__main__":
    unittest.main()
