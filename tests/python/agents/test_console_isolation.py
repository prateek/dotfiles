import os
from unittest.mock import patch

from tests.python.agents.console_support import ConsoleCase, ConsoleRepoCase
from tests.python.agents.console_documents import git


class ConsoleIsolationTests(ConsoleCase):
    def test_fixture_git_writes_do_not_follow_inherited_repository_routing(self):
        external = self.work / "external"
        external.mkdir()
        self.command(["git", "init", "-q", str(external)])
        (external / "outside.txt").write_text("keep unstaged\n")

        with patch.dict(os.environ, {
            "GIT_DIR": str(external / ".git"), "GIT_WORK_TREE": str(external),
        }):
            fixture = ConsoleRepoCase()
            try:
                fixture.setUp()
                (fixture.repo / "inside.txt").write_text("stage in the fixture\n")
                git(fixture.repo, "add", "--all")
                outside = self.command(["git", "diff", "--cached", "--name-only"], cwd=external)
                self.assertEqual(outside.stdout, b"")
                inside = self.command(["git", "diff", "--cached", "--name-only"], cwd=fixture.repo)
                self.assertEqual(inside.stdout, b"inside.txt\n")
            finally:
                fixture.doCleanups()
