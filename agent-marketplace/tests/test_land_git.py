from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

REFERENCE = Path(__file__).resolve().parents[1] / 'packages/review/skills/land-changes/references/direct-git.md'


@unittest.skipUnless(shutil.which('git') and shutil.which('zsh'), 'Git and zsh are required')
class DirectLandingCommandsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='land git ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.wt = self.root / 'candidate checkout'
        self.remote = self.root / 'remote.git'
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                        GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR'):
            self.env.pop(key, None)
        self.git('init', '--bare', '--initial-branch=main', str(self.remote))
        self.git('init', '--initial-branch=main', str(self.wt))
        self.git('-C', str(self.wt), 'remote', 'add', 'publish', str(self.remote))
        (self.wt / 'change.txt').write_text('base\n')
        self.git('-C', str(self.wt), 'add', 'change.txt')
        self.git('-C', str(self.wt), '-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
        self.base = self.git('-C', str(self.wt), 'rev-parse', 'HEAD')
        self.git('-C', str(self.wt), 'push', 'publish', 'main')
        self.git('-C', str(self.wt), 'switch', '-c', 'candidate')
        (self.wt / 'change.txt').write_text('landed\n')
        self.git('-C', str(self.wt), 'add', 'change.txt')
        self.git('-C', str(self.wt), '-c', 'commit.gpgsign=false', 'commit', '-m', 'requested change')
        self.land = self.git('-C', str(self.wt), 'rev-parse', 'HEAD')
        self.env.update(WT=str(self.wt), REMOTE='publish', TARGET='main', LAND=self.land)

    def git(self, *args):
        result = subprocess.run(['git', *args], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_published_snippet_preserves_exact_refspec_and_omits_tags(self):
        self.git('-C', str(self.wt), '-c', 'tag.gpgsign=false', 'tag', '-a', 'unrequested', '-m', 'unrequested')
        self.git('-C', str(self.wt), 'config', 'push.followTags', 'true')
        blocks = re.findall(r'```sh\n(.*?)```', REFERENCE.read_text(), re.S)
        push = next(block for block in blocks if ' push ' in block)
        result = subprocess.run(['zsh', '-f', '-e', '-c', push], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git('--git-dir', str(self.remote), 'rev-parse', 'refs/heads/main'), self.land)
        self.assertEqual(self.git('--git-dir', str(self.remote), 'show', 'main:change.txt'), 'landed')
        self.assertEqual(self.git('--git-dir', str(self.remote), 'rev-list', '--parents', '-n', '1', 'main'), f'{self.land} {self.base}')
        self.assertEqual(self.git('--git-dir', str(self.remote), 'tag', '--list'), '')
        self.assertIn(f'{self.land}\trefs/heads/main', result.stdout)

    def test_published_fetch_records_immutable_base_with_spaced_paths(self):
        fetch = re.findall(r'```sh\n(.*?)```', REFERENCE.read_text(), re.S)[0]
        result = subprocess.run(['zsh', '-f', '-e', '-c', fetch + '\nprint -r -- "$BASE"'],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.base)
        self.assertEqual(self.git('-C', str(self.wt), 'rev-parse', 'HEAD'), self.land)


if __name__ == '__main__':
    unittest.main()
