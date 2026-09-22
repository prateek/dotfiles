from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'packages/review/skills/land-changes/scripts/options.py'


def item(name, kind='action', meaning=None, **scope):
    return {'id': name, 'kind': kind, 'source': 'justfile',
            'meaning': meaning or name, 'scope': scope or {'execution': 'local'}}


class LandChoicesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / 'config'), HOME=str(self.root / 'home'))
        self.catalog = {'items': [item('unit'), item('lint'), item('hook'),
                                 item('apply', host='this-mac', environment='personal'),
                                 item('required-ci', 'gate', actor='me'), item('direct', 'method')],
                        'groups': [dict(item('tests', meaning='all local test suites'), members=['unit'])]}
        self.catalog_path = self.root / 'discovery.json'

    def command(self, *flags, repo='github.com/me/widget', target='main', catalog=True):
        self.catalog_path.write_text(json.dumps(self.catalog))
        return [sys.executable, '-B', str(SCRIPT), '--repo-id', repo, '--target', target,
                *(['--discovery', str(self.catalog_path)] if catalog else []), *flags]

    def run_options(self, *flags, error=None, **kwargs):
        result = subprocess.run(self.command(*flags, **kwargs), env=self.env, text=True, capture_output=True)
        if error:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn(error, result.stderr)
            return result
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def decisions(self, result):
        return {(c['id'], c['operation']): c['origin'] for c in result['choices']}

    def test_read_only_and_one_time_choices(self):
        for flag in ((), ('--show-defaults',), ('--inspect',)):
            self.assertEqual(self.run_options(*flag)['choices'], [])
        chosen = self.run_options('--via=direct', '--skip=unit', '--bypass=required-ci', '--after=apply')
        self.assertEqual(self.decisions(chosen), {('direct', 'via'): 'argument', ('unit', 'skip'): 'argument',
                                                ('required-ci', 'bypass'): 'argument', ('apply', 'after'): 'argument'})
        self.assertFalse((self.root / 'config').exists())
        self.assertEqual(self.run_options()['choices'], [])

    def test_save_override_and_remove_followup(self):
        saved = self.run_options('--skip=unit', '--after=apply', '--save-defaults')
        path = Path(saved['defaults_path']); before = path.read_bytes()
        override = self.run_options('--run=unit', '--without-after=apply')
        self.assertEqual(self.decisions(override), {('unit', 'run'): 'argument', ('apply', 'without-after'): 'argument'})
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
        merged = self.run_options('--bypass=required-ci', '--save-defaults')
        self.assertEqual(set(self.decisions(merged)), {('unit', 'skip'), ('apply', 'after'), ('required-ci', 'bypass')})
        self.run_options('--reset-defaults')
        self.assertFalse(path.exists())

    def test_snapshot_group_does_not_expand_permission(self):
        self.run_options('--skip=tests', '--save-defaults')
        self.catalog['items'].append(item('integration'))
        self.catalog['groups'][0]['members'].append('integration')
        self.assertEqual(self.decisions(self.run_options()), {('unit', 'skip'): 'saved'})

    def test_explicit_dynamic_group_and_concrete_exception(self):
        self.run_options('--skip=tests', '--dynamic=tests', '--save-defaults')
        self.catalog['items'].append(item('integration'))
        self.catalog['groups'][0]['members'].append('integration')
        result = self.run_options('--run=unit')
        self.assertEqual(self.decisions(result), {('unit', 'run'): 'argument', ('integration', 'skip'): 'saved'})
        self.assertNotIn(('hook', 'skip'), self.decisions(result))
        self.run_options('--run=unit', '--save-defaults')
        self.assertEqual(self.decisions(self.run_options()), {('unit', 'run'): 'saved', ('integration', 'skip'): 'saved'})

    def test_changed_or_missing_meaning_is_stale(self):
        self.run_options('--after=apply', '--skip=unit', '--save-defaults')
        self.catalog['items'][3]['scope']['environment'] = 'production'
        result = self.run_options()
        self.assertEqual(self.decisions(result), {('unit', 'skip'): 'saved'})
        self.assertEqual(result['stale'][0]['choice']['id'], 'apply')
        self.assertIn('changed', result['stale'][0]['reason'])
        self.catalog['items'] = [i for i in self.catalog['items'] if i['id'] != 'apply']
        self.assertIn('missing', self.run_options()['stale'][0]['reason'])

    def test_discovery_is_required_to_activate_saved_choices(self):
        self.run_options('--after=apply', '--save-defaults')
        result = self.run_options(catalog=False)
        self.assertEqual(result['choices'], [])
        self.assertIn('discovery', result['stale'][0]['reason'])
        self.assertEqual(len(result['saved_choices']), 1)

    def test_dynamic_scope_cannot_expand(self):
        self.run_options('--skip=tests', '--dynamic=tests', '--save-defaults')
        self.catalog['items'].append(item('remote-tests', execution='ci'))
        self.catalog['groups'][0]['members'].append('remote-tests')
        self.run_options(error='group scope')

    def test_saved_group_replaces_old_members_but_keeps_explicit_exception(self):
        self.run_options('--run=unit', '--save-defaults')
        self.run_options('--skip=tests', '--dynamic=tests', '--save-defaults')
        self.assertEqual(self.decisions(self.run_options()), {('unit', 'skip'): 'saved'})
        chosen = self.run_options('--skip=tests', '--run=unit', '--save-defaults')
        self.assertEqual(self.decisions(chosen), {('unit', 'run'): 'argument'})
        self.assertEqual(self.decisions(self.run_options()), {('unit', 'run'): 'saved'})

    def test_execution_waiting_and_gate_choices_are_independent(self):
        self.run_options('--skip=unit', '--no-wait=unit', '--bypass=required-ci', '--save-defaults')
        result = self.run_options('--require=required-ci', '--wait=unit')
        self.assertEqual(self.decisions(result), {('unit', 'skip'): 'saved', ('unit', 'wait'): 'argument',
                                                 ('required-ci', 'require'): 'argument'})

    def test_invalid_discovery_is_rejected_without_writes(self):
        original = json.loads(json.dumps(self.catalog))
        for mutation in ('duplicate', 'missing_member', 'bad_scope', 'extra', 'bad_kind'):
            self.catalog = json.loads(json.dumps(original))
            if mutation == 'duplicate':
                self.catalog['items'].append(self.catalog['items'][0])
            elif mutation == 'missing_member':
                self.catalog['groups'][0]['members'] = ['missing']
            elif mutation == 'bad_scope':
                self.catalog['items'][0]['scope'] = {'host': []}
            elif mutation == 'extra':
                self.catalog['items'][0]['command'] = 'echo should-never-run'
            else:
                self.catalog['items'][0]['kind'] = 'command'
            result = subprocess.run(self.command('--skip=unit', '--save-defaults'), env=self.env,
                                    text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.root / 'config').exists())

    def test_invalid_choices_do_not_write(self):
        for flags, error in [(['--skip=missing'], 'unknown'), (['--skip=direct'], 'kind'),
                             (['--skip=unit', '--run=unit'], 'conflicting'),
                             (['--save-defaults'], 'requires'),
                             (['--show-defaults', '--after=apply'], 'cannot combine'),
                             (['--inspect', '--save-defaults', '--skip=unit'], 'cannot combine'),
                             (['--skip=unit', '--dynamic=unit', '--save-defaults'], 'group'),
                             (['--deploy=true'], 'unrecognized'),
                             (['--skip=unit', '--skip=unit'], 'duplicate')]:
            with self.subTest(flags=flags):self.run_options(*flags, error=error)
        self.assertFalse((self.root / 'config').exists())

    def test_v1_is_inert_until_deliberate_migration(self):
        result = self.run_options(); path = Path(result['defaults_path']); path.parent.mkdir(parents=True)
        old = {'version': 1, 'repo_id': 'github.com/me/widget', 'target': 'main',
               'defaults': {'deploy': True, 'tests': 'skip', 'review_gate': 'skip'}}
        path.write_text(json.dumps(old)); before = path.read_bytes()
        result = self.run_options()
        self.assertEqual(result['legacy_defaults'], old['defaults'])
        self.assertEqual(result['choices'], [])
        self.assertEqual(path.read_bytes(), before)
        self.run_options('--after=apply', '--save-defaults', error='migrate')
        self.run_options('--after=apply', '--save-defaults', '--migrate-defaults')
        self.assertEqual(json.loads(path.read_text())['version'], 2)
        self.assertEqual(self.decisions(self.run_options()), {('apply', 'after'): 'saved'})

    def test_malformed_v1_values_do_not_become_authorization(self):
        path = Path(self.run_options()['defaults_path'])
        path.parent.mkdir(parents=True)
        for defaults in ({'deploy': 'false'}, {'deploy': 0}, {'tests': False}, {'tests': []},
                         {'review_gate': []}, {'review_gate': 'bypass'}, {'command': 'execute'}):
            raw = json.dumps({'version': 1, 'repo_id': 'github.com/me/widget', 'target': 'main',
                              'defaults': defaults})
            path.write_text(raw)
            self.run_options('--after=apply', error='invalid defaults')
            self.assertEqual(path.read_text(), raw)

    def test_identity_scopes_and_cwd(self):
        self.run_options('--after=apply', '--save-defaults')
        for repo, target in [('github.com/fork/widget', 'main'), ('git.example/me/widget', 'main'),
                             ('github.com/me/widget', 'release/stable')]:
            with self.subTest(repo=repo, target=target):
                self.assertEqual(self.run_options(repo=repo, target=target)['choices'], [])
                self.run_options('--skip=unit', '--save-defaults', repo=repo, target=target)
        other = self.root / 'other'; other.mkdir()
        result = subprocess.run(self.command(), env=self.env, cwd=other, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.decisions(json.loads(result.stdout)), {('apply', 'after'): 'saved'})
        self.run_options('--reset-defaults')
        self.assertEqual(self.decisions(self.run_options(repo='github.com/fork/widget')), {('unit', 'skip'): 'saved'})

    def test_malformed_records_never_fall_back(self):
        path = Path(self.run_options('--after=apply', '--save-defaults')['defaults_path'])
        valid = json.loads(path.read_text())
        changed = [dict(valid, version=True), dict(valid, target='elsewhere'), dict(valid, choices={}),
                   dict(valid, extra='unknown'), dict(valid, choices=[dict(valid['choices'][0], fingerprint='bad')]),
                   dict(valid, choices=[dict(valid['choices'][0], operation='execute')]),
                   dict(valid, choices=[dict(valid['choices'][0], scope={'host': []})])]
        for raw in ['not json', *map(json.dumps, changed), path.read_text().replace('"version": 2', '"version": 2, "version": 2')]:
            with self.subTest(raw=raw):
                path.write_text(raw)
                self.run_options('--without-after=apply', error='invalid defaults')
                self.run_options('--skip=unit', '--save-defaults', error='invalid defaults')
                self.assertEqual(path.read_text(), raw)
        self.run_options('--reset-defaults')
        self.assertEqual(self.run_options()['choices'], [])

    def test_symlink_reset_preserves_target(self):
        path = Path(self.run_options('--after=apply', '--save-defaults')['defaults_path'])
        other = self.root / 'other.json'; path.rename(other); before = other.read_bytes(); path.symlink_to(other)
        self.run_options(error='symlinked')
        self.run_options('--reset-defaults')
        self.assertEqual(other.read_bytes(), before)
        self.assertFalse(path.is_symlink())

    def test_concurrent_saves_merge(self):
        commands = [self.command(flag, '--save-defaults') for flag in ['--skip=unit', '--after=apply', '--bypass=required-ci']]
        processes = [subprocess.Popen(c, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for c in commands]
        outcomes = [(process, process.communicate(timeout=10)) for process in processes]
        for process, (_, error) in outcomes:
            self.assertEqual(process.returncode, 0, error)
        self.assertEqual(set(self.decisions(self.run_options())), {('unit', 'skip'), ('apply', 'after'), ('required-ci', 'bypass')})

    def test_invalid_identity_xdg_and_duplicate_controls(self):
        for repo in ['https://github.com/me/widget', 'git@github.com:me/widget', 'github.com/a/../b',
                     'github.com//widget', 'widget', 'github.com/me/bad name']:
            self.run_options('--skip=unit', '--save-defaults', repo=repo, error='identity')
        self.run_options(target='', error='identity')
        self.run_options('--show-defaults', '--show-defaults', error='duplicate')
        self.run_options('--show-defaults', '--reset-defaults', error='not allowed')
        self.env['XDG_CONFIG_HOME'] = 'relative'
        self.run_options(error='absolute')
        self.env.pop('XDG_CONFIG_HOME')
        result = self.run_options()
        self.assertTrue(result['defaults_path'].startswith(str(self.root / 'home/.config/')))


if __name__ == '__main__':
    unittest.main()
