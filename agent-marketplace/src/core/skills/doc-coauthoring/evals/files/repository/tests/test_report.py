import unittest
from src.report import render_rows
from src.settings import parse_args


class ReportTests(unittest.TestCase):
    def test_default_text(self):
        self.assertEqual(parse_args([]).format, "text")
        self.assertEqual(render_rows([{"id": 7, "name": "Alpha"}]), "Alpha\n")

    def test_rejects_unknown_format(self):
        with self.assertRaisesRegex(ValueError, "unsupported format"):
            render_rows([], "xml")
