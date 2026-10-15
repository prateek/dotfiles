import json
from pathlib import Path
import shutil
import tomllib

from tests.support.python import ROOT, RepoTestCase

PYTHON = ROOT / 'scripts/packages/dotpkgs/.venv/bin/python'
ENTRY = ROOT / 'home/dot_local/bin/executable_dotpkgs'


class DotpkgsTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.bin = self.work / 'bin'
        self.bin.mkdir()
        self.source = self.work / 'source/home'
        (self.source / '.chezmoidata').mkdir(parents=True)
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\nbrews = [{name="one"}]\n')
        self.env.update(DOTPKGS_SOURCE=str(self.source), FIXTURE=str(self.work), PATH=str(self.bin) + ':/usr/bin:/bin')
        self.env['DOTPKGS_MISE_BIN'] = str(self.bin / 'mise')
        self.env['DOTPKGS_BREW_BIN'] = str(self.bin / 'brew')
        self.env['DOTPKGS_CHEZMOI_BIN'] = str(self.bin / 'chezmoi')
        self.env['DOTPKGS_GH_BIN'] = str(self.bin / 'gh')
        self.target = Path(self.env['XDG_CONFIG_HOME']) / 'mise/conf.d/runtimes.toml'
        self.manifest = self.source / 'dot_config/mise/conf.d/runtimes.toml'
        self.manifest.parent.mkdir(parents=True)
        self.manifest.write_text('# preserve this comment\n[tools]\nnode = "20.0.0"\nruby = "latest"\n')
        self.inventory = {
            'node': [{'version': '20.0.0', 'requested_version': '20.0.0', 'installed': True, 'source': {'path': str(self.target)}}],
            'ruby': [{'version': '3.0.0', 'requested_version': 'latest', 'installed': True, 'source': {'path': str(self.target)}}],
        }
        self.save('mise-ls', self.inventory)
        self.save('mise-allowed', {'ruby': {'current': '3.0.0', 'latest': '3.1.0'}})
        self.save('mise-latest', {'node': {'current': '20.0.0', 'latest': '22.0.0'}, 'ruby': {'current': '3.0.0', 'latest': '3.1.0'}})
        self.save('brew-info', {'formulae': [dict(name='one', full_name='one', installed=[{'version':'1'}], versions={'stable':'2'}, pinned=True)], 'casks': []})
        self.save('brew-outdated', {'formulae': [dict(name='one', installed_versions=['1'], current_version='2')], 'casks': []})
        script = f'''#!{PYTHON}
import json, os, pathlib, sys, tomllib
root = pathlib.Path(os.environ['FIXTURE'])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / 'calls').open('a') as f: f.write(json.dumps([name, args, os.getcwd()]) + '\\n')
if os.environ.get('FAIL') == name:
    print('token=SHOULD_NOT_LEAK', file=sys.stderr)
    raise SystemExit(7)
if name == 'mise':
    if args[0] == 'ls': key = 'mise-ls'
    elif args[0] == 'outdated': key = 'mise-latest' if '--bump' in args else 'mise-allowed'
    else: print('native write output'); raise SystemExit(0)
elif name == 'brew':
    if args[0] == 'info': key = 'brew-info'
    elif args[0] == 'outdated': key = 'brew-outdated'
    else: print('native write output'); raise SystemExit(0)
elif name == 'chezmoi':
    if 'source-path' in args:
        print(root / 'source/home/dot_config/mise/conf.d/runtimes.toml')
    elif 'execute-template' in args:
        if 'brewfile.tmpl' in args[-1]:
            data = tomllib.loads((root / 'source/home/.chezmoidata/packages.toml').read_text())['packages']['groups']['core']
            for kind, section in [('brew', 'brews'), ('cask', 'casks')]:
                for item in data.get(section, []): print(kind + ' ' + json.dumps(item['name']))
        else:
            print(json.dumps({{'groups':['core'], 'agent_clis': []}}))
    raise SystemExit(0)
elif name == 'gh':
    if args == ['extension', 'list']: print('gh example\\towner/gh-example\\tv1.0.0')
    elif args[:1] == ['api']: print(json.dumps({{'tag_name':'v2.0.0'}}))
    raise SystemExit(0)
else: raise SystemExit(99)
print((root / (key + '.json')).read_text())
'''
        for name in ('mise', 'brew', 'chezmoi', 'gh'):
            path = self.bin / name
            path.write_text(script)
            path.chmod(0o755)

    def save(self, name, value):
        (self.work / (name + '.json')).write_text(json.dumps(value))

    def cli(self, *args, status=0, env=None):
        result = self.command([str(PYTHON), str(ENTRY), '--json', *args], expected_status=status, env=env)
        return json.loads(result.stdout)

    def calls(self):
        path = self.work / 'calls'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_status_distinguishes_pin_from_permitted_update_and_is_machine_scoped(self):
        data = self.cli('status', '--manager', 'mise')
        rows = {p['name']: p for p in data['results'][0]['packages']}
        self.assertEqual((rows['node']['status'], rows['node']['latest_allowed'], rows['node']['latest']), ('pinned_outdated', '20.0.0', '22.0.0'))
        self.assertEqual(rows['ruby']['status'], 'update_available')
        self.assertTrue(all(Path(call[2]).resolve() == self.home.resolve() for call in self.calls()))
        self.assertEqual(self.cli('status', '--manager', 'mise', '--cached')['results'][0]['packages'], list(rows.values()))
        self.assertEqual(len(self.calls()), 3)

    def test_missing_and_current_are_distinct_from_unknown_inventory(self):
        self.inventory['ruby'][0]['installed'] = False
        self.save('mise-ls', self.inventory)
        self.save('mise-allowed', {})
        self.save('mise-latest', {})
        rows = self.cli('status', '--manager', 'mise')['results'][0]['packages']
        self.assertEqual([r['status'] for r in rows], ['current', 'missing'])
        rows = self.cli('list', '--manager', 'mise')['results'][0]['packages']
        self.assertEqual([r['status'] for r in rows], ['unknown', 'missing'])

    def test_native_failure_is_json_nonzero_and_never_claims_current(self):
        data = self.cli('status', '--manager', 'mise', status=1, env={'FAIL':'mise'})
        self.assertFalse(data['ok'])
        self.assertEqual(data['results'][0]['status'], 'error')
        self.assertNotIn('SHOULD_NOT_LEAK', json.dumps(data))
        self.assertFalse((Path(self.env['XDG_STATE_HOME']) / 'dotfiles/dotpkgs/mise.json').exists())

    def test_brew_pins_are_visible_and_regular_update_preserves_them(self):
        row = self.cli('status', '--manager', 'brew')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'pinned_outdated')
        data = self.cli('update', '--manager', 'brew', '--all', '--dry-run')
        commands = [s['argv'] for s in data['results'][0]['plan']['steps']]
        self.assertFalse(any('upgrade' in cmd or 'unpin' in cmd for cmd in commands))
        data = self.cli('update', '--manager', 'brew', '--all', '--latest', '--dry-run')
        commands = [s['argv'] for s in data['results'][0]['plan']['steps']]
        self.assertIn(['brew', 'unpin', 'one'], commands)
        self.assertIn(['brew', 'upgrade', '--formula', 'one'], commands)
        self.assertFalse(any(c[1][0] in ('upgrade','unpin','update') for c in self.calls()))

    def test_brew_normal_policy_excludes_self_managed_casks_but_retains_catalog_versions(self):
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\n')
        self.save('brew-info', {'formulae': [], 'casks': [
            dict(token='ordinary', installed='1', version='2'),
            dict(token='autoapp', installed='1', version='2', auto_updates=True),
            dict(token='unversioned', installed='1', version='latest'),
        ]})
        self.save('brew-outdated', {'formulae': [], 'casks': [dict(name='ordinary')]})
        rows = self.cli('status', '--manager', 'brew')['results'][0]['packages']
        self.assertEqual([row['status'] for row in rows], ['update_available', 'current', 'current'])
        self.assertEqual([row['latest'] for row in rows], ['2', '2', 'latest'])
        self.assertEqual([call[1] for call in self.calls() if call[1][0] == 'outdated'], [['outdated', '--json=v2']])
        plan = self.cli('update', '--all', '--manager', 'brew', '--dry-run')['results'][0]['plan']
        self.assertEqual([s['argv'] for s in plan['steps'] if 'upgrade' in s['argv']],
                         [['brew', 'upgrade', '--cask', 'ordinary']])
        latest = self.cli('update', '--all', '--manager', 'brew', '--latest', '--dry-run')['results'][0]['plan']
        self.assertIn(['brew', 'upgrade', '--cask', '--greedy', 'ordinary', 'autoapp', 'unversioned'],
                      [s['argv'] for s in latest['steps']])

    def test_bulk_latest_plans_source_edits_and_dry_run_leaves_bytes_untouched(self):
        before = self.manifest.read_bytes()
        data = self.cli('update', '--manager', 'mise', '--all', '--latest', '--dry-run')
        plan = data['results'][0]['plan']
        self.assertIn('+node = "latest"', plan['edits'][0]['diff'])
        self.assertEqual(self.manifest.read_bytes(), before)
        self.assertFalse(any(c[1][0] in ('upgrade','install') for c in self.calls()))

    def test_pin_writes_source_preserves_comments_and_separates_native_stdout(self):
        self.cli('status', '--manager', 'mise')
        data = self.cli('pin', 'mise:node', '--version', '22.0.0')
        self.assertEqual(data['results'][0]['status'], 'completed')
        parsed = tomllib.loads(self.manifest.read_text())
        self.assertEqual(parsed['tools'], {'node':'22.0.0', 'ruby':'latest'})
        self.assertIn('# preserve this comment', self.manifest.read_text())
        self.assertFalse((Path(self.env['XDG_STATE_HOME']) / 'dotfiles/dotpkgs/mise.json').exists())

    def test_invalid_selection_and_unsupported_pin_do_not_write(self):
        before = self.manifest.read_bytes()
        data = self.cli('pin', 'mise:node', 'gh:owner/gh-example', '--version', '', status=1)
        self.assertFalse(data['ok'])
        self.assertEqual(self.manifest.read_bytes(), before)
        self.assertFalse(any(c[1][0] == 'install' for c in self.calls()))
        self.cli('update', status=2)
        self.cli('remove', '--all', status=2)

    def test_unsupported_version_options_fail_before_inventory_or_writes(self):
        cases = [('install', f'{manager}:example') for manager in
                 ('brew', 'gh', 'mas', 'setapp', 'claude', 'codex', 'cursor', 'zinit', 'apm', 'raycast', 'externals', 'swift')]
        cases += [('update', 'mise:node'), ('remove', 'mise:node'), ('unpin', 'mise:node'),
                  ('unpin', 'codex:codex'), ('update', 'xcode:Xcode'), ('unpin', 'xcode:Xcode')]
        for action, package in cases:
            with self.subTest(action=action, package=package):
                code = 2 if action in ('update', 'unpin') else 1
                result = self.cli(action, package, '--version', '9.9', '--dry-run', status=code)
                error = result['error'] if code == 2 else result['results'][0]['error']
                if code == 2:
                    self.assertIn('unrecognized arguments: --version', error)
                else:
                    self.assertEqual(error, package.split(':')[0] + ' ' + action + ' does not support --version')
        self.assertEqual(self.calls(), [])
        rejected = self.cli('install', 'mise:node', '--version', '9.9', '--dry-run', status=1)
        self.assertIn('use pin', rejected['results'][0]['error'])
        supported = self.cli('install', 'mise:new-tool', '--version', '9.9', '--dry-run')['results'][0]['plan']
        self.assertIn('+new-tool = "9.9"', supported['edits'][0]['diff'])

    def test_cross_manager_edits_to_one_manifest_are_merged(self):
        path = self.source / '.chezmoidata/packages.toml'
        path.write_text('[packages.groups.core]\nbrews = [{name="one"}]\ngh_extensions = [{name="owner/gh-example"}]\n')
        self.cli('remove', 'brew:one', 'gh:owner/gh-example')
        data = tomllib.loads(path.read_text())['packages']['groups']['core']
        self.assertEqual(data['brews'], [])
        self.assertEqual(data['gh_extensions'], [])

    def test_gh_pins_use_native_manifest_and_current_commit_markers(self):
        root = Path(self.env['XDG_DATA_HOME']) / 'gh/extensions'
        binary = root / 'gh-binary'
        binary.mkdir(parents=True)
        (binary / 'manifest.yml').write_text('owner: owner\nname: gh-binary\ntag: v1.0.0\nispinned: true\n')
        script = root / 'gh-script'
        (script / '.git').mkdir(parents=True)
        commit = 'abcdef01' * 5
        marker = script / ('.pin-' + commit)
        marker.touch()
        self.binary('gh', '''if sys.argv[1:] == ['extension', 'list']:
 print('gh binary\\towner/gh-binary\\tv1.0.0\\ngh script\\towner/gh-script\\tabcdef01')
elif sys.argv[1] == 'api': print(json.dumps({'tag_name':'v2.0.0'}))
else: raise SystemExit(99)
''')
        self.binary('git', f"print('new-commit\\tHEAD' if 'ls-remote' in sys.argv else {commit!r})\n")
        rows = self.cli('status', '--manager', 'gh')['results'][0]['packages']
        self.assertEqual([row['pinned'] for row in rows], [True, True])
        self.assertEqual([row['status'] for row in rows], ['pinned_outdated', 'pinned_outdated'])
        plan = self.cli('update', '--all', '--manager', 'gh', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'], [])
        marker.rename(script / '.pin-stale-commit')
        row = self.cli('list', 'gh:owner/gh-script')['results'][0]['packages'][0]
        self.assertFalse(row['pinned'])

    def test_gh_pin_replaces_only_selected_extension_at_requested_version(self):
        state = self.work / 'gh-state.json'
        original = {'owner/gh-example': {'version':'v1.0.0', 'pinned':False},
                    'owner/gh-untouched': {'version':'v7.0.0', 'pinned':False}}
        state.write_text(json.dumps(original))
        self.binary('gh', '''path = pathlib.Path(os.environ['FIXTURE']) / 'gh-state.json'
state = json.loads(path.read_text())
args = sys.argv[1:]
if args == ['extension', 'list']:
 for name, item in state.items(): print('gh example\\t' + name + '\\t' + item['version'])
elif args[:2] == ['extension', 'remove']: del state[args[2]]
elif args[:2] == ['extension', 'install']:
 name = args[2]
 if name in state and '--force' in args: state[name] = {'version':'v9.0.0', 'pinned':False}
 else: state[name] = {'version':args[args.index('--pin') + 1], 'pinned':True}
else: raise SystemExit(99)
path.write_text(json.dumps(state))
''')
        self.cli('pin', 'gh:owner/gh-example', '--version', 'v0.5.0', '--dry-run')
        self.assertEqual(json.loads(state.read_text()), original)
        self.cli('pin', 'gh:owner/gh-example', '--version', 'v0.5.0')
        self.assertEqual(json.loads(state.read_text()), original | {'owner/gh-example': {'version':'v0.5.0', 'pinned':True}})

    def test_manager_filters_cannot_expand_explicit_removals(self):
        before = self.manifest.read_bytes()
        rejected = self.cli('remove', '--manager', 'brew', 'mise:node', '--dry-run', status=2)
        self.assertIn('outside selected managers', rejected['error'])
        self.assertEqual(self.calls(), [])
        selected = self.cli('remove', '--manager', 'brew', '--manager', 'mise', 'brew:one', '--dry-run')
        self.assertEqual([result['manager'] for result in selected['results']], ['brew'])
        self.assertEqual(self.manifest.read_bytes(), before)

    def test_gh_latest_upgrades_unpinned_extensions_in_place_and_replaces_pinned_ones(self):
        root = Path(self.env['XDG_DATA_HOME']) / 'gh/extensions/gh-binary'
        root.mkdir(parents=True)
        (root / 'manifest.yml').write_text('owner: owner\nname: gh-binary\ntag: v1.0.0\nispinned: true\n')
        self.binary('gh', '''if sys.argv[1:] == ['extension', 'list']:
 print('gh example\\towner/gh-example\\tv1.0.0\\ngh binary\\towner/gh-binary\\tv1.0.0')
elif sys.argv[1] == 'api': print(json.dumps({'tag_name':'v2.0.0'}))
else: raise SystemExit(99)
''')
        plan = self.cli('update', '--all', '--manager', 'gh', '--latest', '--dry-run')['results'][0]['plan']
        self.assertEqual([step['argv'] for step in plan['steps']], [
            ['gh', 'extension', 'upgrade', 'owner/gh-example'],
            ['gh', 'extension', 'remove', 'owner/gh-binary'],
            ['gh', 'extension', 'install', 'owner/gh-binary'],
        ])

    def test_mise_remove_refuses_a_host_local_override_without_uninstalling(self):
        target = Path(self.env['XDG_CONFIG_HOME']) / 'mise/conf.d/zz-local.toml'
        target.parent.mkdir(parents=True)
        target.write_text('[tools]\nnode = "21.0.0"\n')
        self.inventory['node'][0].update(version='21.0.0', requested_version='21.0.0', source={'path': str(target)})
        self.save('mise-ls', self.inventory)
        self.binary('chezmoi', "if 'source-path' in sys.argv: raise SystemExit(1)\n")
        before = (target.read_bytes(), self.manifest.read_bytes())
        rejected = self.cli('remove', 'mise:node', status=1)
        self.assertIn('underlying declarations', rejected['results'][0]['error'])
        self.assertEqual((target.read_bytes(), self.manifest.read_bytes()), before)
        self.assertFalse(any(call[1][0] == 'uninstall' for call in self.calls()))

    def test_summary_counts_pinned_updates_and_emits_same_records(self):
        result = self.command([str(PYTHON), str(ENTRY), 'summary', '--manager', 'mise'])
        counts, raw = result.stdout.decode().splitlines()
        self.assertEqual(counts, '2\t2\t1\t0')
        self.assertEqual(json.loads(raw)[0]['status'], 'pinned_outdated')

    def test_installed_entrypoint_works_from_another_directory(self):
        target = self.home / '.local/bin/dotpkgs'
        target.parent.mkdir(parents=True)
        target.write_bytes(ENTRY.read_bytes())
        shutil.copytree(ROOT / 'home/dot_local/lib/dotpkgs', self.home / '.local/lib/dotpkgs')
        result = self.command([str(PYTHON), str(target), '--json', 'managers'], cwd=self.work)
        self.assertEqual(len(json.loads(result.stdout)['managers']), 14)

    def binary(self, name, body):
        path = self.bin / name
        path.write_text(f'#!{PYTHON}\nimport json, os, pathlib, sys\n' + body)
        path.chmod(0o755)
        self.env['DOTPKGS_' + name.upper().replace('-', '_') + '_BIN'] = str(path)

    def test_native_channel_checks_and_codex_pin_plan(self):
        for name, installed in [('claude','2.0.0'),('codex','0.1.0'),('cursor-agent','2026.01.01-aaa')]:
            self.binary(name, f'print({installed!r})\n')
        marker = self.home / '.codex/packages/standalone/auto-update-version'
        marker.parent.mkdir(parents=True)
        marker.write_text('0.1.0')
        self.binary('curl', '''url = sys.argv[-1]
if 'claude-code-releases' in url: print('2.0.0')
elif 'releases.openai' in url: print(json.dumps({'tag_name':'rust-v0.2.0'}))
else: print('DOWNLOAD_URL="https://downloads.cursor.com/lab/2026.02.01-bbb/${OS}/${ARCH}/agent-cli-package.tar.gz"')
''')
        data = self.cli('status', '--manager', 'claude', '--manager', 'codex', '--manager', 'cursor')
        rows = [r['packages'][0] for r in data['results']]
        self.assertEqual([r['status'] for r in rows], ['current','update_available','update_available'])
        self.assertEqual(rows[1]['latest'], '0.2.0')
        marker.unlink()
        row = self.cli('status', '--manager', 'codex')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'pinned_outdated')
        plan = self.cli('pin', 'codex:codex', '--version', '0.2.0', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'][0]['args'], ['--release','0.2.0'])
        self.assertIn('+codex = "0.2.0"', plan['edits'][0]['diff'])
        self.assertFalse((self.source / '.chezmoidata/package_policy.toml').exists())

    def test_claude_distinguishes_stable_channel_updates_from_newer_latest_releases(self):
        settings = self.home / '.claude/settings.json'
        settings.parent.mkdir()
        settings.write_text('{"autoUpdatesChannel":"stable"}\n')
        self.binary('claude', "print('2.0.0')\n")
        self.binary('curl', "print(os.environ.get('STABLE_VERSION', '2.0.0') if sys.argv[-1].endswith('/stable') else '2.1.0')\n")
        row = self.cli('status', 'claude:claude')['results'][0]['packages'][0]
        self.assertEqual((row['status'], row['latest_allowed'], row['latest']), ('pinned_outdated', '2.0.0', '2.1.0'))
        allowed = self.cli('status', 'claude:claude', env={'STABLE_VERSION': '2.0.1'})['results'][0]['packages'][0]
        self.assertEqual(allowed['status'], 'update_available')

    def test_apm_compares_locked_commits_without_deploying_and_requires_shared_updates(self):
        root = self.source.parent / 'agent-marketplace'
        root.mkdir()
        (root / 'apm.yml').write_text('devDependencies:\n  apm:\n  - owner/one#v1\n  - owner/two\n')
        (root / 'apm.lock.yaml').write_text('dependencies:\n- repo_url: owner/one\n  resolved_commit: old-one\n- repo_url: owner/two\n  resolved_commit: old-two\n')
        self.binary('apm', "print('apm 0.29.1')\n")
        self.binary('git', "print('new-commit\\tHEAD')\n")
        rows = self.cli('status', '--manager', 'apm')['results'][0]['packages']
        self.assertEqual([r['status'] for r in rows], ['pinned_outdated','update_available'])
        self.cli('update', 'apm:owner/one', '--dry-run', status=1)
        plan = self.cli('update', '--all', '--manager', 'apm', '--latest', '--dry-run')['results'][0]['plan']
        self.assertIn('+  - owner/one', plan['edits'][0]['diff'])
        self.assertEqual(plan['steps'][-1]['type'], 'manual')
        self.assertIn('owner/one#v1', (root / 'apm.yml').read_text())

    def test_apm_preserves_declared_case_and_never_promotes_transitive_dependencies(self):
        root = self.source.parent / 'agent-marketplace'
        root.mkdir()
        manifest = root / 'apm.yml'
        def declarations():
            result = self.command([str(PYTHON), '-c',
                                   'import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1]))["devDependencies"]["apm"]))',
                                   str(manifest)])
            return json.loads(result.stdout)
        original = 'devDependencies:\n  apm:\n  - Owner/Repo/Skills/Case#v1\n  - Owner/Repo/skills/case#v2\n'
        manifest.write_text(original)
        (root / 'apm.lock.yaml').write_text('dependencies:\n- repo_url: owner/repo\n  virtual_path: Skills/Case\n  resolved_commit: one\n- repo_url: owner/repo\n  virtual_path: skills/case\n  resolved_commit: two\n- repo_url: other/transitive\n  resolved_commit: three\n')
        self.binary('apm', '')
        self.binary('just', '')
        self.binary('git', "print('new-commit\\tHEAD')\n")
        rows = self.cli('status', '--manager', 'apm')['results'][0]['packages']
        self.assertEqual([row['requested'] for row in rows[:2]], ['v1', 'v2'])
        self.cli('update', '--all', '--manager', 'apm', '--latest', '--dry-run')
        self.assertEqual(manifest.read_text(), original)
        self.cli('update', '--all', '--manager', 'apm', '--latest', status=1)
        self.assertEqual(declarations(),
                         ['Owner/Repo/Skills/Case', 'Owner/Repo/skills/case'])
        self.cli('pin', 'apm:OWNER/REPO/Skills/Case', '--version', 'v3', status=1)
        expected = ['Owner/Repo/Skills/Case#v3', 'Owner/Repo/skills/case']
        self.assertEqual(declarations(), expected)
        rejected = self.cli('pin', 'apm:other/transitive', '--version', 'v4', status=1)
        self.assertIn('no direct declaration', rejected['results'][0]['error'])
        self.assertEqual(declarations(), expected)

    def test_mas_inventory_and_setapp_manual_update_are_explicit(self):
        self.binary('mas', '''if sys.argv[1] == 'list': print('123 Example App (1.0)\\n456 Current App (3.0)')
elif sys.argv[1] == 'outdated': print('123 Example App (1.0 -> 2.0)')
''')
        row = self.cli('status', '--manager', 'mas')['results'][0]['packages'][0]
        self.assertEqual((row['name'],row['latest'],row['status']), ('123','2.0','update_available'))
        plan = self.cli('update', '--all', '--manager', 'mas', '--dry-run')['results'][0]['plan']
        self.assertEqual([step['argv'] for step in plan['steps']], [['mas', 'upgrade', '123']])
        self.cli('pin', 'mas:123', '--version', '1.0', '--dry-run', status=1)
        self.binary('open', '')
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\nsetapp_apps = [{name="Dotpkgs Fixture App"}]\n')
        plan = self.cli('update', 'setapp:Dotpkgs Fixture App', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'][0]['type'], 'manual')
        self.assertNotIn('command', [s['type'] for s in plan['steps']])

    def test_swift_build_receipt_detects_source_changes_and_remove_disables_reinstall(self):
        assets = self.source / '.chezmoiassets'
        assets.mkdir()
        for name in ('mic','keymap-overlay'):
            (assets / (name + '.swift')).write_text('print("fixture")\n')
        self.binary('swiftc', "pathlib.Path(sys.argv[-1]).write_bytes(b'compiled fixture')\n")
        self.cli('install', 'swift:mic', '--dry-run')
        self.assertFalse((self.home / '.local/bin').exists())
        self.cli('install', 'swift:mic')
        row = self.cli('status', 'swift:mic')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'current')
        plan = self.cli('update', 'swift:mic', '--latest', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'], [])
        self.assertEqual(plan['notes'], ['mic: binary matches its source receipt'])
        (assets / 'mic.swift').write_text('print("changed")\n')
        row = self.cli('status', 'swift:mic')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'update_available')
        plan = self.cli('update', 'swift:mic', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'][1]['argv'][0], 'swiftc')
        self.cli('remove', 'swift:mic')
        self.assertFalse((self.home / '.local/bin/mic').exists())
        policy = tomllib.loads((self.source / '.chezmoidata/package_policy.toml').read_text())
        self.assertFalse(policy['package_policy']['swift']['mic'])
        self.assertEqual(len(list((Path(self.env['XDG_STATE_HOME']) / 'dotfiles/dotpkgs/removed').iterdir())), 1)

    def test_raycast_reports_dependency_updates_and_previews_manifest_bumps(self):
        path = Path(self.env['XDG_DATA_HOME']) / 'raycast-extensions/demo'
        source = self.source / 'dot_local/share/raycast-extensions/demo'
        for directory in (path, source):
            directory.mkdir(parents=True)
            (directory / 'package.json').write_text('{"name":"demo","dependencies":{"example":"^1.0.0"}}\n')
            (directory / 'package-lock.json').write_text('{}\n')
        self.binary('npm', '''if sys.argv[1] == 'outdated':
 print(json.dumps({'example':{'current':'1.0.0','wanted':'1.1.0','latest':'2.0.0'}}))
 raise SystemExit(1)
if sys.argv[1] == 'view' and not any(arg.startswith('peerDependencies') for arg in sys.argv): print(json.dumps('2.0.0'))
''')
        row = self.cli('status', '--manager', 'raycast')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'pinned_outdated')
        self.assertEqual(row['dependencies'][0]['latest'], '2.0.0')
        plan = self.cli('update', 'raycast:demo', '--latest', '--dry-run')['results'][0]['plan']
        self.assertIn('+    "example": "2.0.0"', plan['edits'][0]['diff'])
        self.assertIn('^1.0.0', (source / 'package.json').read_text())

    def test_raycast_latest_holds_dependencies_inside_sibling_peer_ranges(self):
        source = self.source / 'dot_local/share/raycast-extensions/demo'
        source.mkdir(parents=True)
        (source / 'package.json').write_text(json.dumps({'name': 'demo', 'dependencies': {'@raycast/api': '2.8.0'}, 'devDependencies': {
            '@raycast/eslint-config': '2.2.0', '@types/node': '26.6.5', 'eslint': '10.12.0', 'prettier': '3.0.0', 'typescript': '6.0.3'}}, indent=2) + '\n')
        (source / 'package-lock.json').write_text('{}\n')
        self.binary('npm', '''spec = sys.argv[2]
if 'peerDependenciesMeta' in sys.argv:
 if spec == '@raycast/api@2.8.0': print(json.dumps({'@types/node': {'optional': True}}))
elif 'peerDependencies' in sys.argv:
 if spec == '@raycast/eslint-config@2.2.0': print(json.dumps({'eslint': '^9.0.0', 'prettier': '>=2', 'typescript': '>=4.8.4 <6.1.0'}))
 if spec == '@raycast/api@2.8.0': print(json.dumps({'@types/node': '22.19.17'}))
elif spec == 'typescript@>=4.8.4 <6.1.0': print(json.dumps(['5.9.3', '6.0.2', '6.0.3']))
elif spec == 'prettier@>=2': print(json.dumps(['3.0.0', '3.9.10']))
elif spec == 'eslint@^9.0.0': print(json.dumps('9.39.0'))
else: print(json.dumps({'@raycast/api': '2.8.0', '@raycast/eslint-config': '2.2.0', '@types/node': '26.6.5',
                        'eslint': '10.12.0', 'prettier': '3.9.10', 'typescript': '7.0.2'}[spec]))
''')
        plan = self.cli('update', 'raycast:demo', '--latest', '--dry-run')['results'][0]['plan']
        diff = plan['edits'][0]['diff']
        self.assertIn('+    "prettier": "3.9.10"', diff)
        self.assertNotIn('7.0.2', diff)
        self.assertNotIn('22.19.17', diff)
        self.assertNotIn('9.39.0', diff)
        self.assertEqual(plan['notes'], [
            'eslint: kept at 10.12.0; peer ranges from @raycast/eslint-config permit at most 9.39.0',
            'typescript: held at 6.0.3 by peer ranges from @raycast/eslint-config',
        ])

    def test_raycast_installs_declared_sources_before_building_and_rejects_unknown_names(self):
        source = self.source / 'dot_local/share/raycast-extensions/demo'
        source.mkdir(parents=True)
        (source / 'package.json').write_text('{"name":"demo"}\n')
        (source / 'package-lock.json').write_text('{}\n')
        target = Path(self.env['XDG_DATA_HOME']) / 'raycast-extensions/demo'
        self.binary('chezmoi', '''import shutil
if 'apply' in sys.argv:
 assert '--parent-dirs' in sys.argv and '--recursive' in sys.argv
 source = pathlib.Path(os.environ['DOTPKGS_SOURCE']) / 'dot_local/share/raycast-extensions/demo'
 shutil.copytree(source, pathlib.Path(sys.argv[-1]), dirs_exist_ok=True)
''')
        self.binary('npm', '''assert pathlib.Path('package.json').is_file()
if sys.argv[1] == 'outdated': print('{}')
''')
        missing = self.cli('list', 'raycast:demo')['results'][0]['packages'][0]
        self.assertEqual(missing['status'], 'missing')
        self.cli('install', 'raycast:demo', '--dry-run')
        self.assertFalse(target.exists())
        self.cli('install', 'raycast:demo')
        self.assertTrue((target / 'package.json').is_file())
        current = self.cli('status', 'raycast:demo')['results'][0]['packages'][0]
        self.assertEqual(current['status'], 'current')
        plan = self.cli('update', 'raycast:demo', '--dry-run')['results'][0]['plan']
        self.assertEqual(plan['steps'], [])
        rejected = self.cli('install', 'raycast:unknown', '--dry-run', status=1)
        self.assertIn('unknown Raycast extension', rejected['results'][0]['error'])

    def test_raycast_remove_refuses_before_source_or_other_manager_writes(self):
        source = self.source / 'dot_local/share/raycast-extensions/demo/package.json'
        target = Path(self.env['XDG_DATA_HOME']) / 'raycast-extensions/demo/package.json'
        for path in (source, target):
            path.parent.mkdir(parents=True)
            path.write_text('{"name":"demo"}\n')
        packages = self.source / '.chezmoidata/packages.toml'
        before = packages.read_bytes()
        self.binary('npm', '')
        for flags in [('--dry-run',), ()]:
            with self.subTest(flags=flags):
                result = self.cli('remove', 'brew:one', 'raycast:demo', *flags, status=1)
                self.assertIn('owning source', result['results'][1]['error'])
                self.assertEqual(packages.read_bytes(), before)
                self.assertTrue(source.is_file())
                self.assertTrue(target.is_file())
        self.assertFalse(any(call[1][0] == 'uninstall' for call in self.calls()))

    def test_xcode_pin_mismatch_and_latest_plan_do_not_rewrite_runtime_policy(self):
        path = self.source / 'dot_agents/state/ios-triple.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"xcode_version":"26.6","ios_runtime_primary":"iOS 26.5"}\n')
        self.binary('xcodes', "print('26.6 (build) (Installed)\\n27.0 (build)')\n")
        self.binary('xcodebuild', "print('Xcode 26.6\\nBuild version fixture')\n")
        row = self.cli('status', '--manager', 'xcode')['results'][0]['packages'][0]
        self.assertEqual((row['status'],row['latest']), ('pinned_outdated','27.0'))
        regular = self.cli('update', '--manager', 'xcode', '--all', '--dry-run')['results'][0]['plan']
        self.assertEqual(regular['steps'], [])
        self.assertEqual(regular['edits'], [])
        plan = self.cli('update', '--manager', 'xcode', '--all', '--latest', '--dry-run')['results'][0]['plan']
        self.assertIn('+  "xcode_version": "27.0"', plan['edits'][0]['diff'])
        self.assertEqual(json.loads(path.read_text())['xcode_version'], '26.6')
        self.assertIn('iOS 26.5', plan['edits'][0]['diff'])

    def test_xcode_install_can_start_from_command_line_tools_only(self):
        path = self.source / 'dot_agents/state/ios-triple.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"xcode_version":"26.6"}\n')
        self.binary('xcodes', "if sys.argv[1] == 'installed': print('')\n")
        self.binary('xcodebuild', "print('active developer directory is CommandLineTools', file=sys.stderr)\nraise SystemExit(1)\n")
        result = self.cli('install', 'xcode:Xcode', '--dry-run')['results'][0]
        self.assertEqual(result['status'], 'planned')
        self.assertIn(['xcodes', 'install', '26.6', '--experimental-unxip'], [s['argv'] for s in result['plan']['steps']])

    def test_xcode_repair_remains_available_when_installed_bundles_are_not_selected(self):
        path = self.source / 'dot_agents/state/ios-triple.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"xcode_version":"26.6"}\n')
        self.binary('xcodes', "if sys.argv[1] == 'installed': print('26.6 (build)')\n")
        self.binary('xcodebuild', "print('active developer directory is CommandLineTools', file=sys.stderr)\nraise SystemExit(1)\n")
        row = self.cli('list', 'xcode:Xcode')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'unknown')
        self.assertIsNone(row['installed'])
        self.assertIn('selection', row['note'])
        result = self.cli('install', 'xcode:Xcode', '--dry-run')['results'][0]
        self.assertEqual(result['status'], 'planned')
        self.assertIn(['xcodes', 'select', '26.6'], [s['argv'] for s in result['plan']['steps']])

    def test_git_status_uses_remote_refs_without_fetching_and_protects_tracked_edits(self):
        root = Path(self.env['XDG_DATA_HOME']) / 'zinit/plugins/owner---plugin'
        (root / '.git').mkdir(parents=True)
        source = self.source / 'dot_config/zsh/zinit-init.zsh'
        source.parent.mkdir(parents=True)
        source.write_text('zinit ice lucid\nzinit light owner/plugin\n')
        self.binary('zsh', '')
        self.binary('git', '''args = sys.argv[1:]
if 'ls-remote' in args: print('new-commit\\trefs/heads/main')
elif '--abbrev-ref' in args: print('main')
elif 'rev-parse' in args: print('old-commit')
elif 'status' in args:
 if os.environ.get('DIRTY'): print(' M plugin.zsh')
else: raise SystemExit(99)
''')
        row = self.cli('status', '--manager', 'zinit')['results'][0]['packages'][0]
        self.assertEqual((row['installed'],row['latest'],row['status']), ('old-commit','new-commit','update_available'))
        self.cli('update', 'zinit:owner/plugin', '--dry-run', env={'DIRTY':'1'}, status=1)
        plan = self.cli('pin', 'zinit:owner/plugin', '--version', 'v1', '--dry-run')['results'][0]['plan']
        self.assertIn('+zinit ice lucid verv1', plan['edits'][0]['diff'])
        self.assertEqual(source.read_text(), 'zinit ice lucid\nzinit light owner/plugin\n')

    def test_privilege_guidance_is_available_offline_and_on_each_planned_step(self):
        managers = {row['name']: row for row in self.cli('managers')['managers']}
        self.assertEqual(managers['mas']['privilege']['sudo'], 'required')
        self.assertEqual(managers['mise']['privilege']['sudo'], 'not_needed')
        self.assertEqual(managers['brew']['privilege']['sudo'], 'may_prompt')
        plan = self.cli('update', 'mise:node', '--latest', '--dry-run')['results'][0]['plan']
        self.assertTrue(plan['steps'])
        self.assertTrue(all(step['privilege']['sudo'] == 'not_needed' for step in plan['steps']))
        escaped = self.cli('exec', '--dry-run', 'brew', '--', 'services', 'start', 'example')
        self.assertEqual(escaped['privilege']['sudo'], 'delegated')
        self.assertFalse(self.manifest.read_text().count('22.0.0'))

    def test_exec_separates_helper_options_from_literal_native_arguments(self):
        for args in [('exec', '--dry-run', 'brew', '--', 'services', 'stop', 'example'),
                     ('exec', 'brew', '--dry-run', '--', 'services', 'stop', 'example')]:
            with self.subTest(args=args):
                plan = self.cli(*args)
                self.assertEqual(plan['command'], ['brew', 'services', 'stop', 'example'])
                self.assertEqual(self.calls(), [])
        self.cli('exec', 'brew', 'services', 'stop', 'example', status=2)
        self.assertEqual(self.calls(), [])
        self.cli('exec', 'brew', '--', 'services', '--dry-run', '--json')
        self.assertEqual(self.calls()[0][1], ['services', '--dry-run', '--json'])

    def test_explicit_unavailable_inventory_fails_in_every_format(self):
        env = {'DOTPKGS_MISE_BIN': str(self.work / 'absent')}
        data = self.cli('status', 'mise:node', status=1, env=env)
        self.assertFalse(data['ok'])
        self.assertEqual(data['results'][0]['status'], 'unavailable')
        result = self.command([str(PYTHON), str(ENTRY), 'list', '--manager', 'mise', '--format', 'tsv'], expected_status=1, env=env)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'not installed', result.stderr)
        data = self.cli('summary', '--manager', 'mise', status=3, env=env)
        self.assertFalse(data['ok'])

    def test_outdated_preserves_unresolved_coverage(self):
        self.inventory['rust'] = [{'version':'stable', 'requested_version':'latest', 'installed':True}]
        self.inventory['ruby'][0]['installed'] = False
        self.save('mise-ls', self.inventory)
        result = self.cli('outdated', '--manager', 'mise')['results'][0]
        self.assertEqual(result['summary']['unknown'], 1)
        self.assertEqual(result['summary']['missing'], 1)
        self.assertEqual({r['name'] for r in result['unresolved']}, {'rust', 'ruby'})

    def test_inventory_tracks_desired_absence_and_disabled_native_agents(self):
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\nbrews = [{name="one"}, {name="absent"}]\n')
        rows = self.cli('list', '--manager', 'brew')['results'][0]['packages']
        self.assertEqual({r['name']:r['status'] for r in rows}, {'one':'unknown', 'absent':'missing'})
        row = self.cli('list', 'cursor:cursor-agent')['results'][0]['packages'][0]
        self.assertEqual(row['status'], 'disabled')

    def test_selected_update_ignores_unrelated_multiple_versions(self):
        self.inventory['ruby'].append(self.inventory['ruby'][0] | {'version':'2.0.0'})
        self.save('mise-ls', self.inventory)
        plan = self.cli('update', 'mise:node', '--dry-run')['results'][0]['plan']
        self.assertEqual([s['argv'] for s in plan['steps']], [['mise','upgrade','--no-prune','node']])

    def test_text_inventory_and_status_have_distinct_presentations(self):
        result = self.command([str(PYTHON), str(ENTRY), 'list', '--manager', 'mise'])
        self.assertIn(b'mise:node', result.stdout)
        self.assertNotIn(b'unknown', result.stdout)
        self.assertNotIn(b'latest=?', result.stdout)
        result = self.command([str(PYTHON), str(ENTRY), 'status', '--manager', 'mise'])
        self.assertIn(b'2 packages', result.stdout)
        self.assertNotIn(b'cached check:', result.stdout)
        cached = self.command([str(PYTHON), str(ENTRY), 'status', '--manager', 'mise', '--cached'])
        self.assertIn(b'Cached', cached.stdout)

    def test_wrong_shape_is_a_provider_error_and_keeps_other_results(self):
        self.save('mise-ls', [])
        data = self.cli('status', '--manager', 'brew', '--manager', 'mise', status=1)
        self.assertEqual([r['status'] for r in data['results']], ['ok','error'])
        self.assertIn('shape', data['results'][1]['error'])

    def test_doctor_validates_source_configuration(self):
        (self.source / '.chezmoidata/packages.toml').write_text('invalid toml')
        data = self.cli('doctor', status=1)
        self.assertFalse(data['ok'])
        self.assertIn('configuration', data['error'])

    def test_partial_failure_reports_applied_sources_and_unstarted_operations(self):
        binary = self.bin / 'brew'
        binary.write_text(binary.read_text().replace("if name == 'mise':", "if name == 'brew' and args[0] == 'uninstall': raise SystemExit(7)\nif name == 'mise':"))
        data = self.cli('remove', 'brew:one', 'mise:node', status=1)
        self.assertNotIn('node', tomllib.loads(self.manifest.read_text())['tools'])
        first, later = data['results']
        self.assertEqual(later['status'], 'not_started')
        self.assertEqual(later['source_status'], 'applied')
        self.assertEqual(first['execution'][0]['status'], 'failed')
        self.assertEqual(later['execution'][0]['status'], 'not_started')

    def test_irrelevant_options_are_rejected_before_probing(self):
        for args in [('pin','--all'), ('update','mise:node','--version','22.0.0'),
                     ('unpin','mise:node','--kind','cask'), ('install','mise:new','--group','core')]:
            with self.subTest(args=args):
                self.cli(*args, '--dry-run', status=2)
        self.assertEqual(self.calls(), [])

    def test_xcode_validates_ids_and_rejects_unpin(self):
        self.cli('install', 'xcode:typo', '--dry-run', status=1)
        result = self.cli('unpin', 'xcode:Xcode', '--dry-run', status=1)
        self.assertIn('unpin', result['results'][0]['error'])
        self.assertEqual(self.calls(), [])

    def test_exec_preserves_native_streams_and_exit_status(self):
        self.binary('mise', "print('native stdout')\nprint('native stderr', file=sys.stderr)\nraise SystemExit(7)\n")
        result = self.command([str(PYTHON), str(ENTRY), 'exec', 'mise', '--', 'ls'], expected_status=7)
        self.assertEqual(result.stdout, b'native stdout\n')
        self.assertEqual(result.stderr, b'native stderr\n')
        data = self.cli('exec', 'mise', '--', 'ls', status=7)
        self.assertEqual(data['stdout'], 'native stdout\n')
        self.assertEqual(data['exit_code'], 7)

    def test_scoped_git_check_skips_broken_unselected_plugin(self):
        root = Path(self.env['XDG_DATA_HOME']) / 'zinit/plugins'
        for name in ('good', 'bad'):
            (root / ('owner---' + name) / '.git').mkdir(parents=True)
        self.binary('zsh', '')
        self.binary('git', """args = sys.argv[1:]
if 'owner---bad' in args[1]: raise SystemExit(7)
if 'ls-remote' in args: print('new-commit\\trefs/heads/main')
elif '--abbrev-ref' in args: print('main')
elif 'rev-parse' in args: print('old-commit')
elif 'status' in args: print('')
""")
        rows = self.cli('status', 'zinit:owner/good')['results'][0]['packages']
        self.assertEqual([(r['id'], r['status']) for r in rows], [('zinit:owner/good', 'update_available')])

    def test_selected_check_and_banner_do_not_replace_complete_cached_inventory(self):
        complete = self.cli('status', '--manager', 'mise')['results'][0]['packages']
        self.cli('status', 'mise:node')
        self.cli('summary', '--manager', 'mise')
        self.assertEqual(self.cli('status', '--manager', 'mise', '--cached')['results'][0]['packages'], complete)

    def test_disabled_swift_and_text_recovery_destination(self):
        assets = self.source / '.chezmoiassets'
        assets.mkdir()
        for name in ('mic', 'keymap-overlay'):
            (assets / (name + '.swift')).write_text('print("fixture")')
        self.binary('swiftc', "pathlib.Path(sys.argv[-1]).write_bytes(b'compiled fixture')\n")
        self.cli('install', 'swift:mic')
        removed = self.cli('remove', 'swift:mic')['results'][0]
        destination = Path(removed['execution'][0]['destination'])
        self.assertEqual(destination.read_bytes(), b'compiled fixture')
        self.assertEqual(self.cli('list', 'swift:mic')['results'][0]['packages'][0]['status'], 'disabled')

    def test_tsv_keeps_installed_projection_while_text_omits_dependencies(self):
        self.save('brew-info', {'formulae': [
            dict(name='one', installed=[{'version':'1', 'installed_on_request':True}], versions={'stable':'1'}),
            dict(name='dependency', installed=[{'version':'1', 'installed_on_request':False}], versions={'stable':'1'}),
        ], 'casks': []})
        result = self.command([str(PYTHON), str(ENTRY), 'list', '--manager', 'brew'])
        self.assertIn(b'brew:one', result.stdout)
        self.assertNotIn(b'brew:dependency', result.stdout)
        all_rows = self.command([str(PYTHON), str(ENTRY), 'list', '--manager', 'brew', '--all'])
        self.assertIn(b'brew:dependency', all_rows.stdout)
        tsv = self.command([str(PYTHON), str(ENTRY), 'list', '--manager', 'brew', '--format', 'tsv'])
        self.assertEqual(tsv.stdout, b'one\t1\t\tformula\ttrue\ndependency\t1\t\tformula\tfalse\n')

    def test_partial_source_write_failure_preserves_applied_file_receipt(self):
        parent = self.manifest.parent
        parent.chmod(0o555)
        try:
            data = self.cli('remove', 'brew:one', 'mise:node', status=1)
        finally:
            parent.chmod(0o755)
        brew, mise = data['results']
        self.assertEqual((brew['status'], brew['source_status']), ('not_started', 'applied'))
        self.assertEqual((mise['status'], mise['source_status']), ('not_started', 'unchanged'))
        self.assertEqual(tomllib.loads((self.source / '.chezmoidata/packages.toml').read_text())['packages']['groups']['core']['brews'], [])
        self.assertIn('node', tomllib.loads(self.manifest.read_text())['tools'])
        self.assertFalse(any(call[1][0] == 'uninstall' for call in self.calls()))

    def test_tsv_requires_one_provider_and_json_remains_unambiguous(self):
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\nbrews = [{name="missing"}]\n')
        data = self.cli('list', '--manager', 'mise', '--manager', 'brew', '--format', 'tsv')
        self.assertEqual({row['name'] for row in data['results'][1]['packages']}, {'one', 'missing'})
        result = self.command([str(PYTHON), str(ENTRY), 'list', '--format', 'tsv'], expected_status=2)
        self.assertIn(b'one selected provider', result.stderr)

    def test_doctor_does_not_call_an_executable_an_installed_provider(self):
        self.binary('open', '')
        result = self.cli('doctor')
        rows = {row['manager']:row for row in result['results']}
        self.assertEqual(rows['zinit']['status'], 'not_configured')
        self.assertFalse(rows['zinit']['configured'])
        self.assertEqual(rows['zinit']['network'], 'not probed')

    def test_observation_reloads_declarations_after_successful_removal(self):
        binary = self.bin / 'brew'
        binary.write_text(binary.read_text().replace("if name == 'mise':", "if name == 'brew' and args[0] == 'uninstall':\n    (root / 'brew-info.json').write_text(json.dumps({'formulae':[], 'casks':[]}))\nif name == 'mise':"))
        result = self.cli('remove', 'brew:one')['results'][0]
        self.assertEqual(result['status'], 'completed')
        self.assertEqual(result['observed'], [])

    def test_desired_brew_and_mas_inventory_uses_rendered_policy(self):
        (self.source / '.chezmoidata/packages.toml').write_text('[packages.groups.core]\nbrews = [{name="excluded-by-policy"}]\n')
        self.binary('chezmoi', "print('brew \"adapter\"\\ncask \"fork\"\\nmas \"Example App\", id: 123')\n")
        self.binary('mas', '')
        results = self.cli('list', '--manager', 'brew', '--manager', 'mas')['results']
        brew = {r['name']: r['status'] for r in results[0]['packages']}
        self.assertEqual(brew, {'one':'unknown', 'adapter':'missing', 'fork':'missing'})
        app = results[1]['packages'][0]
        self.assertEqual((app['id'], app['title'], app['status']), ('mas:123', 'Example App', 'missing'))
