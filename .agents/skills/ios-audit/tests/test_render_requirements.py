import builtins
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from render import render as render_module  # noqa: E402


class RenderRequirementsTests(unittest.TestCase):
    def test_get_markdown_module_raises_when_markdown_missing(self) -> None:
        original_import = builtins.__import__

        def fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name == "markdown":
                raise ImportError("markdown missing")
            return original_import(name, globals, locals, fromlist, level)

        with mock.patch("builtins.__import__", side_effect=fake_import):
            with self.assertRaisesRegex(RuntimeError, "requires the `markdown` package"):
                render_module._get_markdown_module()

    def test_render_html_raises_when_jinja_missing(self) -> None:
        original_import = builtins.__import__

        def fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name == "jinja2":
                raise ImportError("jinja2 missing")
            return original_import(name, globals, locals, fromlist, level)

        with tempfile.TemporaryDirectory() as tmp:
            out_path = Path(tmp) / "audit.html"
            with mock.patch("builtins.__import__", side_effect=fake_import):
                with self.assertRaisesRegex(RuntimeError, "requires the `jinja2` package"):
                    render_module._render_html(
                        audit={"meta": {}, "findings": [], "summary": {}},
                        out_path=out_path,
                        skill_root=SKILL_ROOT,
                        authored_docs_dir=Path(tmp),
                        sections=[],
                        indexes={},
                        overview={},
                    )


if __name__ == "__main__":
    unittest.main()
