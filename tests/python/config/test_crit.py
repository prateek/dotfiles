import json

from tests.support.python import RepoTestCase


class CritConfigTests(RepoTestCase):
    template = "home/modify_private_dot_crit.config.json.tmpl"

    def test_owned_commands_replace_stale_values_and_preserve_user_state(self):
        modify = self.modifier(self.template)
        current = {"auth_token": "secret-abc", "share_consented": True, "auth_user_name": "Prätéek",
                   "port": 3456, "custom_key": "keep-me", "agent_cmd": "crit-agent {prompt}"}
        result = self.command(modify, json.dumps(current).encode())
        self.assertEqual(json.loads(result.stdout), current | {
            "agent_cmd": "claude --dangerously-skip-permissions -p",
            "open_cmd": str(self.home / ".local/bin/crit-open"), "notify_on_round_ready": True,
        })
        self.assertIs(json.loads(result.stdout)["share_consented"], True)
        self.assertIs(json.loads(result.stdout)["notify_on_round_ready"], True)
        self.assertIn("Prätéek".encode(), result.stdout)
        self.assertEqual(self.command(modify, result.stdout).stdout, result.stdout)
        compact = json.dumps(json.loads(result.stdout), separators=(",", ":")).encode()
        self.assertEqual(self.command(modify, compact).stdout, compact)

    def test_empty_config_acquires_only_owned_launch_keys(self):
        result = self.command(self.modifier(self.template))
        self.assertEqual(json.loads(result.stdout), {
            "agent_cmd": "claude --dangerously-skip-permissions -p",
            "open_cmd": str(self.home / ".local/bin/crit-open"), "notify_on_round_ready": True,
        })

    def test_absent_apps_remove_owned_keys_and_leave_missing_config_empty(self):
        modify = self.modifier(self.template, "ci")
        current = {"auth_token": "x", "agent_cmd": "crit-agent {prompt}", "open_cmd": "/stale",
                   "notify_on_round_ready": True}
        self.assertEqual(json.loads(self.command(modify, json.dumps(current).encode()).stdout), {"auth_token": "x"})
        self.assertEqual(self.command(modify).stdout, b"")


class AcpxConfigTests(RepoTestCase):
    def agents(self, machine_type):
        return json.loads(self.render("home/dot_acpx/config.json.tmpl", machine_type))["agents"]

    def test_work_shortcuts_select_models_before_acp_and_reach_plugins(self):
        agents = self.agents("work")
        self.assertEqual(set(agents), {"agpt", "agptw", "agptx", "aopus", "aopusx", "agemini", "afable", "afablex"})
        self.assertEqual(agents["agpt"]["command"], "cursor-agent")
        for name in ("agpt", "agptx", "agptw", "aopus", "aopusx", "agemini"):
            with self.subTest(shortcut=name):
                args = agents[name]["args"]
                self.assertEqual(args[0], "--model")
                self.assertTrue(args[1])
                self.assertEqual(args[args.index("--add-dir") + 1], str(self.home / ".agents/plugins"))
                self.assertEqual(args[-1], "acp")

    def test_claude_marketplace_path_is_added_only_when_present(self):
        args = self.agents("work")["agptw"]["args"]
        self.assertEqual(args.count("--add-dir"), 1)
        marketplace = self.home / ".claude/plugins/marketplaces"
        marketplace.mkdir(parents=True)
        args = self.agents("work")["agptw"]["args"]
        directories = [args[index + 1] for index, value in enumerate(args) if value == "--add-dir"]
        self.assertEqual(directories, [str(self.home / ".agents/plugins"), str(marketplace)])
        self.assertEqual(args[-1], "acp")

    def test_codex_profiles_and_empty_ci_select_only_available_adapters(self):
        for machine_type in ("personal", "homelab"):
            with self.subTest(machine_type=machine_type):
                agents = self.agents(machine_type)
                self.assertEqual(set(agents), {"agpt", "agptx", "afable", "afablex"})
                self.assertEqual(agents["agpt"]["command"], "codex-acp")
        self.assertEqual(self.agents("ci"), {})
