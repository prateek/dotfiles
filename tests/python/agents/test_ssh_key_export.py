import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / 'scripts/1password/export-ssh-key'


class SshKeyExportTest(unittest.TestCase):
    def test_exports_validated_openssh_format_without_replacing_existing_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = root / 'fixture.json'
            source = root / 'source'
            target = root / 'installed'
            command = root / 'op-stub'
            subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(source)], check=True)
            fixture.write_text(json.dumps({'private_key': {'value': 'wrong-format', 'ssh_formats': {'openssh': source.read_text()}}}))
            command.write_text(f'#!/bin/sh\n[ "$1 $2 $4" = "item get --vault" ] || exit 2\ncat "{fixture}"\n')
            command.chmod(0o700)
            args = [str(HELPER), '--vault', 'Dummy', '--item', 'Synthetic', '--output', str(target), '--op-command', str(command)]
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertTrue(subprocess.run(['ssh-keygen', '-y', '-f', str(target)], capture_output=True).stdout.startswith(b'ssh-ed25519 '))
            self.assertNotEqual(subprocess.run(args, capture_output=True).returncode, 0)
            self.assertEqual(target.read_text(), source.read_text())
            target.unlink()
            fixture.write_text(json.dumps({'private_key': {'value': 'wrong-format'}}))
            failure = subprocess.run(args, capture_output=True, text=True)
            self.assertNotEqual(failure.returncode, 0)
            self.assertFalse(target.exists())
            self.assertNotIn('wrong-format', failure.stderr)


if __name__ == '__main__':
    unittest.main()
