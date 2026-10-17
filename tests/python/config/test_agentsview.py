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
        self.accounts = self.home / "Library/Application Support/orca/codex-accounts"
        (self.accounts / "acct-b/home/sessions").mkdir(parents=True)
        (self.accounts / "signed-out/home").mkdir(parents=True)
        self.local_dirs = [str(self.home / suffix) for suffix in (
            ".codex/sessions", ".codex/archived_sessions",
            "Library/Application Support/orca/codex-runtime-home/home/sessions",
            "Library/Application Support/orca-dev/codex-runtime-home/home/sessions",
            "Library/Application Support/orca/codex-accounts/acct-b/home/sessions",
        )]

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
        expected = tomllib.loads(current.decode()) | {"agents": {"codex": {"dirs": self.local_dirs}}}
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

    def test_unregistered_host_without_archive_gets_only_local_codex_roots(self):
        modify = self.modifier("home/private_dot_agentsview/modify_private_config.toml.tmpl")
        result = self.command(modify, env={"WIKI_SESSIONS_CLONE": str(self.work / "no-clone")})
        self.assertEqual(tomllib.loads(result.stdout.decode()), {"agents": {"codex": {"dirs": self.local_dirs}}})

    def test_legacy_codex_sessions_dirs_moves_under_agents_table(self):
        current = b'''auth_token = "secret-token"
codex_sessions_dirs = ["/stale/codex"]

[agents.claude]
dirs = ["/srv/claude"]

[agents.codex]
homes = ["/srv/codex-home"]
'''
        result = self.command(self.modify, current)
        migrated = tomllib.loads(result.stdout.decode())
        self.assertNotIn("codex_sessions_dirs", migrated)
        self.assertEqual(migrated["auth_token"], "secret-token")
        self.assertEqual(migrated["agents"], {
            "claude": {"dirs": ["/srv/claude"]},
            "codex": {"homes": ["/srv/codex-home"], "dirs": self.local_dirs},
        })

    def test_orca_codex_account_added_after_apply_lands_on_next_run(self):
        first = self.command(self.modify)
        (self.accounts / "acct-a/home/sessions").mkdir(parents=True)
        second = self.command(self.modify, first.stdout)
        self.assertEqual(tomllib.loads(second.stdout.decode())["agents"]["codex"]["dirs"], [
            *self.local_dirs[:4],
            str(self.accounts / "acct-a/home/sessions"),
            str(self.accounts / "acct-b/home/sessions"),
        ])
        self.assertEqual(self.command(self.modify, second.stdout).stdout, second.stdout)
