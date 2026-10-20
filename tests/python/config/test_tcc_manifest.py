import json
import os
import subprocess
import tomllib
import unittest
from tests.support.python import ROOT, RepoTestCase


class TCCManifestTests(RepoTestCase):
    def test_render_preserves_audited_declarations_and_reasons(self):
        rendered = json.loads(self.render('home/dot_config/dotfiles/tcc.json.tmpl'))
        source = tomllib.loads((ROOT / 'home/.chezmoidata/tcc.toml').read_text())['tcc']
        self.assertEqual(rendered, source)
        self.assertEqual(rendered['version'], 1)
        ghost = rendered['apps']['ghostpepper']
        self.assertEqual(ghost['bundle_id'], 'com.github.matthartman.ghostpepper')
        self.assertIn('microphone', {entry['service'] for entry in ghost['permissions']})
        self.assertTrue(all(entry['reason'].strip() for app in rendered['apps'].values() for entry in app['permissions']))

    def test_permission_files_are_ignored_unless_enabled_on_macos(self):
        for machine, enabled, expected in [('personal', False, True), ('personal', True, False), ('devbox', True, True)]:
            with self.subTest(machine=machine, enabled=enabled):
                ignored = self.render('home/.chezmoiignore', machine, data={'machines_local': {'tcc_onboarding': enabled}}).decode().splitlines()
                self.assertEqual('.config/dotfiles/tcc.json' in ignored, expected)
                self.assertEqual('.chezmoiscripts/99-tcc-onboarding.sh' in ignored, expected)
                self.assertEqual('.local/bin/dotfiles-permissions' in ignored, expected)

    def test_cli_symlink_targets_the_installed_helper_binary(self):
        rendered = self.render('home/dot_local/bin/symlink_dotfiles-permissions.tmpl').decode().strip()
        self.assertTrue(rendered.endswith('/Applications/Dotfiles Permissions.app/Contents/MacOS/DotfilesPermissions'))

    @unittest.skipUnless(os.environ.get('DOTFILES_TCC_CLI'), 'run through just test-tcc-onboarding, which builds the CLI')
    def test_rendered_manifest_passes_the_helper_validator(self):
        manifest = self.work / 'tcc.json'
        manifest.write_bytes(self.render('home/dot_config/dotfiles/tcc.json.tmpl'))
        result = subprocess.run([os.environ['DOTFILES_TCC_CLI'], 'manifest', 'validate', '--manifest', str(manifest)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
