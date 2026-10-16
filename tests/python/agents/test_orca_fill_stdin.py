import contextlib
import hashlib
from importlib.machinery import SourceFileLoader
import io
from pathlib import Path
import sys
import re
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
MODULE = SourceFileLoader('orca_fill_stdin', str(ROOT / 'agent-marketplace/packages/utils-agent/skills/browser/scripts/orca-fill-stdin')).load_module()


class Input:
    def __init__(self, value):
        self.buffer = io.BytesIO(value)
    def isatty(self):
        return False


class OrcaFillTest(unittest.TestCase):
    def test_214_uses_local_rpc_without_secret_in_process_args(self):
        expressions = []
        def version(args, **_):
            self.assertEqual(args, ['orca', '--version'])
            return types.SimpleNamespace(returncode=0, stdout='1.4.214\n')
        def evaluate(_page, expression):
            expressions.append(expression)
            call = expression.splitlines()[-1]
            if 'inputDigest(' in call:
                salt = re.search(r'inputDigest\([^\n]*, "([0-9a-f]{32})"\)', call).group(1)
                return hashlib.sha256((salt + 'dummy-secret').encode()).hexdigest()
            return True
        calls = []
        def rpc(method, params):
            calls.append((method, params))
            return {}
        out = io.StringIO()
        with patch.object(sys, 'argv', ['orca-fill-stdin', '--page', 'page-1', '--origin', 'https://example.test', '--selector', '#password']), patch.object(sys, 'stdin', Input(b'dummy-secret')), patch.object(MODULE.subprocess, 'run', version), patch.object(MODULE, 'evaluate', evaluate), patch.object(MODULE, 'rpc', rpc), contextlib.redirect_stdout(out):
            self.assertEqual(MODULE.main(), 0)
        self.assertIn('"filled": true', out.getvalue())
        self.assertTrue(all('dummy-secret' not in expression for expression in expressions))
        self.assertEqual(calls, [('browser.fill', {'page': 'page-1', 'element': '#password', 'value': 'dummy-secret'})])

    def test_unknown_version_rejected_before_rpc(self):
        with patch.object(sys, 'argv', ['orca-fill-stdin', '--page', 'page-1', '--origin', 'https://example.test', '--selector', '#password']), patch.object(sys, 'stdin', Input(b'dummy-secret')), patch.object(MODULE.subprocess, 'run', return_value=types.SimpleNamespace(returncode=0, stdout='1.4.211\n')), patch.object(MODULE, 'evaluate') as evaluate, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(MODULE.main(), 1)
            evaluate.assert_not_called()


    def test_evaluate_reads_marked_json_text_and_raw_results(self):
        for raw, expected in (('orca-fill-stdin:true', True), ('"orca-fill-stdin:\\"true\\""', 'true'), ('orca-fill-stdin:"null"', 'null'), ('"orca-fill-stdin:null"', None)):
            with patch.object(MODULE, 'rpc', return_value={'result': raw}):
                self.assertEqual(MODULE.evaluate('page-1', 'x'), expected)
        for raw in ('true', True, '"abc"'):
            with patch.object(MODULE, 'rpc', return_value={'result': raw}):
                with self.assertRaises(MODULE.Failure):
                    MODULE.evaluate('page-1', 'x')

    def test_version_gate_accepts_later_numeric_releases_only(self):
        for version, ok in (('1.4.212', True), ('1.4.224', True), ('1.5.0', True), ('2.0.0', True), ('1.4.211', False), ('1.4.224-beta', False), ('1.4', False), ('', False)):
            self.assertEqual(MODULE.supported(version), ok, version)

if __name__ == '__main__':
    unittest.main()
