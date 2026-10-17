import shutil
import tomllib

from tests.support.python import RepoTestCase


class AgentsviewConfigTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.modify = self.modifier("home/private_dot_agentsview/modify_private_config.toml.tmpl",
                                    data={"machines_local": {"wiki_host_alias": "selfhost"}})
        self.clone = self.work / "clone"
        self.env.update(WIKI_SESSIONS_CLONE=str(self.clone), WIKI_SESSIONS_HOST="selfhost")
        for root in ("alpha/claude/projects", "alpha/cursor/projects", "beta/claude/projects",
                     "beta/codex/sessions", "selfhost/claude/projects"):
            (self.clone / "sessions" / root).mkdir(parents=True)
        self.support = self.home / "Library/Application Support"
        self.orca_homes = [self.support / suffix for suffix in (
            "orca/codex-runtime-home/home",
            "orca/codex-accounts/acct-b/home",
            "orca-dev/codex-accounts/acct-d/home",
        )]
        for home in self.orca_homes:
            home.mkdir(parents=True)
        (self.support / "orca/codex-accounts/.staging/home").mkdir(parents=True)
        self.orca_homes = [str(home) for home in self.orca_homes]
        self.stock_dirs = [str(self.home / ".codex/sessions"), str(self.home / ".codex/archived_sessions")]
        self.codex = {"dirs": self.stock_dirs, "homes": self.orca_homes}

    def test_archive_sources_reconcile_while_preserving_auth_custom_entries_and_comments(self):
        current = b'''auth_token = "secret-token"
cursor_secret = "secret-cursor"
custom_key = "keep-me"

# hand-written entry: buildbox copilot
[[session_sources]]
agent = "copilot"
dir = "/srv/handwritten/copilot"
machine = "buildbox"
'''
        result = self.command(self.modify, current)
        expected = tomllib.loads(current.decode()) | {"agents": {"codex": self.codex}}
        sources = expected["session_sources"]
        sources.extend({"agent": agent, "dir": str(self.clone / "sessions" / host / suffix), "machine": host}
                       for host, agent, suffix in (
                           ("alpha", "claude", "claude/projects"), ("alpha", "cursor", "cursor/projects"),
                           ("beta", "claude", "claude/projects"), ("beta", "codex", "codex/sessions"),
                       ))
        self.assertEqual(tomllib.loads(result.stdout.decode()), expected)
        self.assertIn(b"# hand-written entry: buildbox copilot", result.stdout)
        self.assertEqual(result.stderr, b"")
        self.assertEqual(self.command(self.modify, result.stdout).stdout, result.stdout)
        shutil.rmtree(self.clone / "sessions/beta")
        pruned = self.command(self.modify, result.stdout)
        expected["session_sources"] = [row for row in sources if row["machine"] != "beta"]
        self.assertEqual(tomllib.loads(pruned.stdout.decode()), expected)

    def test_unregistered_host_without_archive_gets_only_orca_codex_homes(self):
        modify = self.modifier("home/private_dot_agentsview/modify_private_config.toml.tmpl")
        result = self.command(modify, env={"WIKI_SESSIONS_CLONE": str(self.work / "no-clone")})
        self.assertEqual(tomllib.loads(result.stdout.decode()), {"agents": {"codex": self.codex}})

    def test_legacy_codex_keys_migrate_to_orca_homes_keeping_hand_written_homes(self):
        stale = self.support / "orca/codex-accounts/signed-out/home"
        current = f'''auth_token = "secret-token"
codex_sessions_dirs = ["/stale/codex"]

[agents.claude]
dirs = ["/srv/claude"]

[agents.codex]
dirs = ["{self.home}/.codex/sessions", "{self.orca_homes[0]}/sessions"]
homes = ["/srv/codex-home", "{stale}"]
'''.encode()
        result = self.command(self.modify, current)
        migrated = tomllib.loads(result.stdout.decode())
        self.assertNotIn("codex_sessions_dirs", migrated)
        self.assertEqual(migrated["auth_token"], "secret-token")
        self.assertEqual(migrated["agents"], {
            "claude": {"dirs": ["/srv/claude"]},
            "codex": {"dirs": self.stock_dirs, "homes": ["/srv/codex-home", *self.orca_homes]},
        })

    def test_orca_codex_account_added_after_apply_lands_on_next_run(self):
        first = self.command(self.modify)
        added = self.support / "orca/codex-accounts/acct-a/home"
        added.mkdir(parents=True)
        second = self.command(self.modify, first.stdout)
        runtime, account_b, dev_account = self.orca_homes
        self.assertEqual(tomllib.loads(second.stdout.decode())["agents"]["codex"]["homes"],
                         [runtime, str(added), account_b, dev_account])
        self.assertEqual(self.command(self.modify, second.stdout).stdout, second.stdout)

    def test_host_without_orca_pins_only_stock_codex_dirs(self):
        shutil.rmtree(self.support)
        result = self.command(self.modify, env={"WIKI_SESSIONS_CLONE": str(self.work / "no-clone")})
        self.assertEqual(tomllib.loads(result.stdout.decode()), {"agents": {"codex": {"dirs": self.stock_dirs}}})
