import json
import tomllib

from tests.support.python import ROOT, RepoTestCase

CATALOGUE = tomllib.loads((ROOT / "home/.chezmoidata/agents.toml").read_text())["agents"]
MATRIX = {
    "personal": ["claude", "codex", "omp", "pi", "gemini"],
    "homelab": ["claude", "codex", "omp", "pi", "gemini"],
    "work": ["claude", "cursor-agent", "pi"],
    "devbox": ["claude", "cursor-agent", "omp", "pi"],
    "ci": [],
}


class AgentCatalogueTests(RepoTestCase):
    def selection(self, machine, **data):
        return json.loads(self.render("home/.chezmoitemplates/agents.tmpl", machine, data=data))

    def test_every_catalogue_entry_declares_how_it_installs_and_what_it_owns(self):
        for agent, entry in CATALOGUE.items():
            with self.subTest(agent=agent):
                self.assertTrue(entry["binary"])
                self.assertIn(entry["install"], ("native-hook", "mise"))
                self.assertEqual("mise" in entry, entry["install"] == "mise")
                for adapter in entry.get("adapters", []):
                    self.assertRegex(adapter, r"^(mise|brew):\S+")
                for path in entry.get("config_paths", []):
                    self.assertFalse(path.startswith(("/", "~")), path)
        # Native installs each have an apply hook that gates on the agent.
        for agent, hook in (("claude", "run_after_06-claude-native"), ("codex", "run_after_07-codex-standalone"),
                            ("cursor-agent", "run_after_07-cursor-agent")):
            with self.subTest(agent=agent):
                self.assertEqual(CATALOGUE[agent]["install"], "native-hook")
                source = (ROOT / f"home/.chezmoiscripts/{hook}.sh.tmpl").read_text()
                self.assertIn(f'has "{agent}" $f.agent_clis', source)

    def test_machine_types_select_the_agreed_agents_and_nothing_outside_the_catalogue(self):
        for machine, agents in MATRIX.items():
            with self.subTest(machine=machine):
                resolved = self.selection(machine)
                self.assertEqual(set(resolved["selected"]), set(agents))
                self.assertEqual(set(resolved["unselected"]), set(CATALOGUE) - set(agents))
                self.assertEqual(resolved["selected"].get("pi"), CATALOGUE["pi"] if "pi" in agents else None)
        host_local = self.selection("work", machines_local={"agent_clis": ["claude"]})
        self.assertEqual(set(host_local["selected"]), {"claude"})

    def test_agent_config_is_ignored_where_the_agent_is_not_selected(self):
        cases = (
            ("personal", {}, {".cursor/cli-config.json"}),
            ("work", {}, {".codex"}),
            ("ci", {}, {".codex", ".cursor/cli-config.json", ".pi"}),
            ("work", {"machines_local": {"agent_clis": ["claude", "cursor-agent"]}}, {".codex", ".pi"}),
        )
        gated = {path for entry in CATALOGUE.values() for path in entry.get("config_paths", [])}
        for machine, data, expected in cases:
            with self.subTest(machine=machine, data=data):
                lines = set(self.render("home/.chezmoiignore", machine, data=data).decode().splitlines())
                self.assertEqual(lines & gated, expected)

    def test_plugin_hooks_reconcile_only_plugin_capable_selected_agents(self):
        hook = "home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl"
        rendered = self.render(hook, "work", data={"machines_local": {"run_install_scripts": True}}).decode()
        self.assertIn('agents="$agents --agent claude"', rendered)
        self.assertNotIn("--agent cursor-agent", rendered)
        self.assertNotIn("--agent pi", rendered)
        rendered = self.render(hook, "personal", data={"machines_local": {"run_install_scripts": True}}).decode()
        for agent in ("claude", "codex", "omp"):
            self.assertIn(f'agents="$agents --agent {agent}"', rendered)
        self.assertNotIn("--agent gemini", rendered)
