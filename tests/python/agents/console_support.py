import json
import os
import shutil
import sys
import uuid
from pathlib import Path
from unittest.mock import patch

from tests.support.python import ROOT, RepoTestCase

SCRIPTS = ROOT / ".agents/skills/agent-skill-management/scripts"
sys.path.insert(0, str(SCRIPTS))

from skill_console import BudgetInputs, ListingEntry
from skill_console.budget import admit, display_width, listing_text


class ConsoleCase(RepoTestCase):
    def setUp(self):
        super().setUp()
        for name in list(self.env):
            if name.startswith(("CLAUDE_", "SLASH_COMMAND_TOOL_")) or name == "AGENT_SKILL_PACKAGES_ROOT":
                self.env.pop(name)
        self.fixtures = self.work / "fixtures"
        shutil.copytree(ROOT / "tests/fixtures/console", self.fixtures)


class ConsoleRepoCase(ConsoleCase):
    def setUp(self):
        super().setUp()
        self.env["DOTFILES_TEST_RUNTIME_READY"] = "1"
        self.enterContext(patch.dict(os.environ, self.env, clear=True))
        self.repo = self.work / "repo"
        self.repo.mkdir()
        paths = self.command(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]).stdout
        for relative in set(paths.decode().split("\0")) - {""}:
            source = ROOT / relative
            if not source.exists() and not source.is_symlink():
                continue
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target, follow_symlinks=False)
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "gc.auto", "0")
        self.git("config", "maintenance.auto", "false")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "console fixture")
        self.git("tag", "fixture")
        shutil.copytree(ROOT / "build/test-libraries", self.repo / "build/test-libraries")

    def git(self, *args):
        return self.command(["git", "-c", "user.name=console-test", "-c", "user.email=test@example.invalid", *args], cwd=self.repo)

    def add_synthetic_vendor(self):
        # The reference scanner must not find the fixture's name in tracked tests.
        self.synth_skill = "lone-" + uuid.uuid4().hex
        package = self.repo / "home/dot_agents/packages/synth"
        lone = self.synth_skill
        for name in (lone, "twin-a", "twin-b"):
            skill = package / "skills/vendor" / name
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Synthetic vendored skill.\n---\n\n# {name}\n")
            dependency = lone if name == lone else "twins"
            (skill / "SOURCE.md").write_text(f"# Source\n\n- APM dependency: `example/repo/skills/{dependency}`\n")
        scripts = package / "skills/vendor" / lone / "scripts"
        scripts.mkdir()
        (scripts / "tool.py").write_text('print("tool")\n')
        (package / "package.toml").write_text('display_name = "Synth"\n\n[render]\nclaude = "plugin"\ncodex = "plugin"\n')
        (package / "apm.yml").write_text(f"name: synth\nversion: 1.0.0\ntargets:\n  - agent-skills\n\ndependencies:\n  apm:\n    - example/repo/skills/{lone}\n    - example/repo/skills/twins\n")
        lock = "lockfile_version: '1'\ngenerated_at: '2026-09-02T00:00:00+00:00'\napm_version: 0.28.0\ndependencies:\n"
        for name, sha, deployed in ((lone, "0" * 39 + "1", [lone, lone + "/SKILL.md"]), ("twins", "0" * 39 + "2", ["twin-a", "twin-b"])):
            lock += f"- repo_url: example/repo\n  name: {name}\n  host: github.com\n  resolved_commit: {sha}\n  version: unknown\n  virtual_path: skills/{name}\n  is_virtual: true\n  package_type: claude_skill\n  deployed_files:\n"
            lock += "".join(f"  - .agents/skills/{path}\n" for path in deployed)
            lock += f"  deployed_file_hashes:\n    .agents/skills/{deployed[0]}/SKILL.md: sha256:aa\n  content_hash: sha256:bb\n"
        lock += "deployments:\n"
        for path, owner in ((lone, lone), (lone + "/SKILL.md", lone), ("twin-a", "twins")):
            lock += f"- kind: project-relative\n  target: agent-skills\n  value: .agents/skills/{path}\n  runtime: null\n  scope: project\n  owners:\n  - example/repo/skills/{owner}\n  active_owner: example/repo/skills/{owner}\n"
        (package / "apm.lock.yaml").write_text(lock)
        (self.repo / "docs/synth-note.md").write_text(f"# Notes\n\nThe synth:{lone} skill is mentioned here.\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "synthetic vendor")
        self.git("tag", "synth")


def fixture_entry(item):
    if "listing_text" in item:
        text = str(item["listing_text"])
    else:
        when_to_use = item.get("when_to_use")
        text = listing_text(str(item["description"]), None if when_to_use is None else str(when_to_use))
    return ListingEntry(
        name=str(item["name"]),
        listing_text=text,
        protected=bool(item.get("protected", False)),
        forced_name_only=bool(item.get("forced_name_only", False)),
        rank=float(item.get("rank", 0.0)),
    )


def load_fixture(path):
    fixture = json.loads(Path(path).read_text())
    inputs = BudgetInputs(**{"env_budget": None, **fixture["inputs"]})
    return inputs, [fixture_entry(item) for item in fixture["entries"]]


def run_budget(path, measure=display_width):
    inputs, entries = load_fixture(path)
    return admit(entries, inputs, measure=measure), entries, inputs


def write_fixture(path, inputs, entries):
    Path(path).write_text(json.dumps({"inputs": inputs, "entries": entries}, ensure_ascii=False, indent=1))
