import json
import re
import tomllib

from tests.support.python import ROOT, RepoTestCase


class MachineFeaturesTests(RepoTestCase):
    template = "home/.chezmoitemplates/features.tmpl"

    def resolve(self, machine_type="personal", **data):
        return json.loads(self.render(self.template, machine_type, data=data))

    def test_machine_compositions_and_absent_identity_default(self):
        expected = {
            "ci": {
                "groups": ["core"], "run_install_scripts": True,
                "apply_macos_defaults": True, "secrets_enabled": False,
                "private_overlay": False, "elevation": "none", "granola_mcp": False,
                "tls_inspection": False,
            },
            "personal": {
                "groups": ["core", "mac-desktop", "ai-agent-apps", "codex", "developer-tools", "personal-apps", "forks"],
                "run_install_scripts": True, "apply_macos_defaults": True,
                "secrets_enabled": False, "elevation": "none",
                "private_overlay": False, "granola_mcp": True, "tls_inspection": False,
            },
            "homelab": {
                "groups": ["core", "ai-agent-apps", "codex", "developer-tools", "apple-development", "homelab-overlay"],
                "runner_vm_name": "tartelet-runner", "runner_vm_count": 1,
                "runner_scope": "repo", "runner_start_on_launch": True, "granola_mcp": True,
                "tls_inspection": False,
            },
            "work": {
                "groups": ["core", "mac-desktop", "ai-agent-apps", "developer-tools", "work-apps", "forks"],
                "private_overlay": True, "elevation": "jamf-self-service", "granola_mcp": False,
                "tls_inspection": True,
            },
        }
        for machine, fields in expected.items():
            with self.subTest(machine=machine):
                actual = self.resolve(machine)
                self.assertEqual(actual["machine_type"], machine)
                for key, value in fields.items():
                    self.assertIs(type(actual[key]), type(value), key)
                    self.assertEqual(actual[key], value, key)
        self.assertEqual(self.resolve(None)["machine_type"], "personal")

    def test_session_archive_ownership_aliases_and_ingest_constraints(self):
        machines = tomllib.loads((ROOT / "home/.chezmoidata/machines.toml").read_text())["machines"]
        defaults, types = machines["defaults"], machines["type"]
        for key in ("agent_session_wiki", "agent_session_wiki_ingest", "agent_session_wiki_sparse"):
            self.assertIs(defaults[key], False, key)
        self.assertNotIn("agent_session_wiki", types["ci"])
        for machine in ("personal", "homelab", "work"):
            self.assertIs(types[machine].get("agent_session_wiki"), True)
            self.assertNotIn("agent_session_wiki_ingest", types[machine])
        self.assertIs(types["work"].get("agent_session_wiki_sparse"), True)
        for machine in ("personal", "homelab"):
            self.assertFalse(types[machine].get("agent_session_wiki_sparse"))
        hosts = machines.get("host", {})
        aliases = {host: cfg["wiki_host_alias"] for host, cfg in hosts.items() if "wiki_host_alias" in cfg}
        for host, alias in aliases.items():
            self.assertIsNotNone(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", alias), host)
        self.assertEqual(len(aliases), len(set(aliases.values())), "host aliases must be unique")
        ingest = [host for host, cfg in hosts.items() if cfg.get("agent_session_wiki_ingest")]
        self.assertLessEqual(len(ingest), 1, "only one host may ingest")
        for host in ingest:
            self.assertIn(host, aliases)
            self.assertFalse(hosts[host].get("agent_session_wiki_sparse"), host)

    def test_work_uses_sparse_archive_and_m4mini_owns_ingest_with_a_full_clone(self):
        personal = self.resolve("personal", chezmoi={"hostname": "prateek-personal-mbp"})
        self.assertEqual(personal["wiki_host_alias"], "personal-mbp")
        work = self.resolve("work")
        self.assertIs(work["agent_session_wiki_sparse"], True)
        self.assertIs(work["agent_session_wiki_ingest"], False)
        mini = self.resolve("homelab", chezmoi={"hostname": "m4mini"})
        self.assertIs(mini["agent_session_wiki"], True)
        self.assertIs(mini["agent_session_wiki_ingest"], True)
        self.assertIs(mini["agent_session_wiki_sparse"], False)
        self.assertEqual(mini["wiki_host_alias"], "m4mini")

    def test_layer_precedence_and_whole_list_replacement(self):
        self.assertIs(self.resolve(machines_local={"secrets_enabled": True})["secrets_enabled"], True)
        self.assertEqual(self.resolve("work", machines_local={"elevation": "none"})["elevation"], "none")
        self.assertEqual(self.resolve("work", machines_local={"groups": ["core"]})["groups"], ["core"])
        os_layer = self.resolve(machines={"os": {"darwin": {"apply_macos_defaults": False}}})
        self.assertIs(os_layer["apply_macos_defaults"], False)
        self.assertIs(os_layer["run_install_scripts"], True)

    def test_unknown_type_fails_with_a_typo_diagnostic(self):
        result = self.command([
            "chezmoi", "--source", str(ROOT), "--config", str(self.config),
            "--destination", str(self.home), "--override-data", '{"machine_type":"nope"}',
            "execute-template", "--file", str(ROOT / self.template),
        ], expected_status=1)
        self.assertIn(b"unknown machine type", result.stderr)
