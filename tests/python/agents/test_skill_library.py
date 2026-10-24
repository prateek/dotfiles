import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.support.python import ROOT

GENERATOR = ROOT / ".agents/skills/agent-skill-management/scripts/generate-skill-library"
READER = ROOT / "agent-marketplace/src/utils-agent/skills/skill-library/scripts/skill-library"


class SkillLibraryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifact = self.root / "artifact"
        self.policy = self.root / "policy.toml"
        self.upstream = self.root / "upstream.toml"
        self.registry = self.root / "installed.json"
        self.catalog = self.root / "catalog.json"
        self.policy.write_text('[agent_plugins.on]\ndefault_loaded = true\n[agent_plugins.off]\ndefault_loaded = false\n')
        self.upstream.write_text('')
        self.registry.write_text('{"plugins": {}}')
        for plugin in ("on", "off"):
            base = self.artifact / "plugins" / plugin
            (base / ".codex-plugin").mkdir(parents=True)
            (base / ".codex-plugin/plugin.json").write_text('{"version":"1.0.0"}')
            self.skill(base / "skills" / "plain")
        for directory in (".agents/plugins", ".claude-plugin"):
            path = self.artifact / directory / "marketplace.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps({"name": "prateek-local", "plugins": [{"name": n, "source": f"plugins/{n}"} for n in ("on", "off")]}))

    def skill(self, root, controls="", body="See references/example.md."):
        root.mkdir(parents=True, exist_ok=True)
        (root / "SKILL.md").write_text(f'---\nname: sample\ndescription: >-\n  Sample specialist\n  guidance.\n{controls}---\n{body}\n')
        (root / "references").mkdir(exist_ok=True)
        (root / "references/example.md").write_text("resource nonce")

    def receipt(self):
        files = {}
        for path in self.artifact.rglob('*'):
            if path.is_file() and path.name != "release.json":
                files[str(path.relative_to(self.artifact))] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "mode": path.stat().st_mode & 0o777}
        (self.artifact / "release.json").write_text(json.dumps({"schema": 1, "files": files}))

    def run_cli(self, script, *args, success=True):
        result = subprocess.run([sys.executable, str(script), *map(str, args)], capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def generate(self):
        self.receipt()
        self.run_cli(GENERATOR, "--plugins-root", self.artifact, "--policy", self.policy,
                     "--upstream-policy", self.upstream, "--claude-registry", self.registry, "--output", self.catalog)
        return json.loads(self.catalog.read_text())

    def read(self, name, *args, success=True):
        return self.run_cli(READER, "--catalog", self.catalog, "read", name, *args, success=success)

    def test_all_disabled_skills_listed_but_invocation_controls_preserved(self):
        base = self.artifact / "plugins/off/skills"
        self.skill(base / "manual", "disable-model-invocation: true\n")
        self.skill(base / "fork", "context: fork\n")
        self.skill(base / "codex-manual")
        (base / "codex-manual/agents").mkdir()
        (base / "codex-manual/agents/openai.yaml").write_text('policy:\n  allow_implicit_invocation: false\n')
        catalog = self.generate()
        self.assertEqual({e['id']: e['mode'] for e in catalog['skills']}, {
            'prateek-local/off/plain': 'read', 'prateek-local/off/manual': 'explicit',
            'prateek-local/off/codex-manual': 'explicit', 'prateek-local/off/fork': 'native'})
        self.assertIn('explicit user request', self.read('prateek-local/off/manual', success=False).stderr)
        self.assertIn('Sample specialist', self.read('prateek-local/off/manual', '--explicit').stdout)
        self.assertIn('native plugin invocation', self.read('prateek-local/off/fork', success=False).stderr)
        output = self.read('prateek-local/off/plain').stdout
        self.assertIn(str(base / 'plain'), output)
        self.assertTrue((base / 'plain/references/example.md').is_file())
        self.assertIn('exact qualified', self.read('unknown', success=False).stderr)

    def test_stale_policy_and_changed_skill_refused(self):
        self.generate()
        path = self.artifact / 'plugins/off/skills/plain/SKILL.md'
        path.write_text(path.read_text() + 'changed')
        self.assertIn('stale', self.read('prateek-local/off/plain', success=False).stderr)
        self.generate()
        self.policy.write_text(self.policy.read_text().replace('false', 'true'))
        self.assertIn('stale', self.read('prateek-local/off/plain', success=False).stderr)

    def test_upstream_manifest_paths_and_missing_install_coverage(self):
        self.upstream.write_text('''[[agent_upstream_plugins]]
marketplace = "up"
plugin = "tools"
default_loaded = false
[[agent_upstream_plugins]]
marketplace = "up"
plugin = "missing"
default_loaded = false
''')
        plugin = self.root / 'upstream'
        self.skill(plugin / 'custom/location')
        self.skill(plugin / 'skills/unselected')
        (plugin / '.claude-plugin').mkdir()
        (plugin / '.claude-plugin/plugin.json').write_text('{"name":"tools", "skills":["./custom/location"]}')
        self.registry.write_text(json.dumps({'plugins': {'tools@up': [{'scope': 'user', 'installPath': str(plugin), 'version': '2'}]}}))
        catalog = self.generate()
        self.assertIn('up/tools/location', [e['id'] for e in catalog['skills']])
        self.assertNotIn('up/tools/unselected', [e['id'] for e in catalog['skills']])
        self.assertEqual(next(c['status'] for c in catalog['coverage'] if c['plugin'] == 'up/missing'), 'unavailable')
        (plugin / '.claude-plugin/plugin.json').write_text('{"name":"tools", "skills":["../artifact/plugins/on/skills/plain"]}')
        catalog = self.generate()
        self.assertNotIn('up/tools/plain', [e['id'] for e in catalog['skills']])
        self.assertIn('escapes', next(c['reason'] for c in catalog['coverage'] if c['plugin'] == 'up/tools'))

    def test_invalid_artifact_does_not_replace_catalog(self):
        self.generate()
        previous = self.catalog.read_bytes()
        (self.artifact / 'plugins/off/skills/plain/SKILL.md').unlink()
        result = self.run_cli(GENERATOR, '--plugins-root', self.artifact, '--policy', self.policy,
                             '--upstream-policy', self.upstream, '--claude-registry', self.registry,
                             '--output', self.catalog, success=False)
        self.assertIn('differ from release receipt', result.stderr)
        self.assertEqual(self.catalog.read_bytes(), previous)
        self.assertIn('No such file', self.read('prateek-local/off/plain', success=False).stderr)
