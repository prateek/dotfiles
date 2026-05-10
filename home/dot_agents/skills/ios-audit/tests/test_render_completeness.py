import json
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from common import write_json  # noqa: E402
from render import render as render_module  # noqa: E402


class RenderCompletenessTests(unittest.TestCase):
    def test_validate_authored_audit_rejects_missing_required_docs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            raw_dir = root / "raw"
            docs_dir = root / "docs"
            findings_dir = root / "findings"
            raw_dir.mkdir(parents=True)
            docs_dir.mkdir(parents=True)
            findings_dir.mkdir(parents=True)

            write_json(raw_dir / "meta.json", {"pillars_run": ["ux"]})
            write_json(findings_dir / "ux.json", [])
            write_json(raw_dir / "ux_run" / "results.json", {"workflows": [{"name": "Sign In"}]})
            (docs_dir / "00-exec-brief.md").write_text("# Brief\n", encoding="utf-8")

            with self.assertRaisesRegex(RuntimeError, "missing required authored doc"):
                render_module._validate_authored_audit(
                    raw_dir=raw_dir,
                    findings_dir=findings_dir,
                    authored_docs_dir=docs_dir,
                    meta={"pillars_run": ["ux"]},
                )

    def test_validate_authored_audit_accepts_complete_minimum_set(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            raw_dir = root / "raw"
            docs_dir = root / "docs"
            findings_dir = root / "findings"
            (raw_dir / "ux_run").mkdir(parents=True)
            (docs_dir / "ux" / "flows" / "_screenshots" / "sign_in").mkdir(parents=True)
            findings_dir.mkdir(parents=True)

            write_json(raw_dir / "meta.json", {"pillars_run": ["ux"]})
            write_json(raw_dir / "ux_run" / "results.json", {"workflows": [{"name": "Sign In"}]})
            write_json(findings_dir / "ux.json", [])

            required_docs = [
                "00-exec-brief.md",
                "ux/screen-inventory.md",
                "ux/navigation-graph.md",
                "ux/component-catalog.md",
                "ux/device-matrix.md",
                "ux/consistency-audit.md",
                "ux/layer-hierarchies.md",
                "ux/gesture-audit.md",
                "ux/accessibility-audit.md",
                "ux/flows/sign_in.md",
            ]
            for rel in required_docs:
                path = docs_dir / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"# {path.stem}\n", encoding="utf-8")

            screenshot = docs_dir / "ux" / "flows" / "_screenshots" / "sign_in" / "step0.png"
            screenshot.write_bytes(b"png")

            render_module._validate_authored_audit(
                raw_dir=raw_dir,
                findings_dir=findings_dir,
                authored_docs_dir=docs_dir,
                meta={"pillars_run": ["ux"]},
            )


if __name__ == "__main__":
    unittest.main()
