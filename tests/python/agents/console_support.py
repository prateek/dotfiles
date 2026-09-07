import json
import os
import shutil
import sys
import subprocess
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
        self.env["UV_CACHE_DIR"] = subprocess.check_output(["uv", "cache", "dir"], text=True).strip()
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
        self.synth_skill = "lone-" + uuid.uuid4().hex
        package = self.repo / "agent-marketplace/packages/synth"
        self.command([str(ROOT / "agent-marketplace/.venv/bin/python"), "-c", SYNTH_PACKAGE,
                      str(package), self.synth_skill])
        (self.repo / "docs/synth-note.md").write_text(f"# Notes\n\nThe synth:{self.synth_skill} skill is mentioned here.\n")
        self.git("add", "-f", "agent-marketplace", "docs/synth-note.md")
        self.git("commit", "-q", "-m", "synthetic vendor")
        self.git("tag", "synth")


SYNTH_PACKAGE = r'''import json,sys
from pathlib import Path
import yaml
from apm_cli.utils.content_hash import compute_package_hash
package=Path(sys.argv[1]);lone=sys.argv[2];project=package.parents[1]
package.mkdir(parents=True)
lock=[];selections=[]
for dependency,names in ((lone,[lone]),("twins",["twin-a","twin-b"])):
    module=project/"apm_modules/example/repo/skills"/dependency
    for name in names:
        skill=module/"skills"/name;skill.mkdir(parents=True)
        (skill/"SKILL.md").write_text(f"---\nname: {name}\ndescription: Synthetic imported skill.\n---\n\nOriginal.\n")
        selections.append(f'[[skills]]\nname = "{name}"\ndependency = "example/repo/skills/{dependency}"\npath = "skills/{name}"\n')
    (module/"apm.yml").write_text(f"name: {dependency}\nversion: 1.0.0\n")
    sha="a"*40 if dependency==lone else "b"*40
    (module/".apm-pin").write_text(json.dumps({"schema_version":1,"resolved_commit":sha}))
    lock.append({"repo_url":"example/repo","host":"github.com","name":dependency,"resolved_commit":sha,
                 "virtual_path":f"skills/{dependency}","is_virtual":True,"package_type":"apm_package",
                 "content_hash":compute_package_hash(module),"is_dev":True})
root_lock=yaml.safe_load((project/"apm.lock.yaml").read_text())
root_lock["dependencies"].extend(lock)
(project/"apm.lock.yaml").write_text(yaml.safe_dump(root_lock))
manifest=yaml.safe_load((project/"apm.yml").read_text())
manifest["devDependencies"]["apm"].extend([f"example/repo/skills/{lone}","example/repo/skills/twins"])
manifest["marketplace"]["packages"].append({"name":"synth","source":"./plugins/synth","category":"Productivity"})
(project/"apm.yml").write_text(yaml.safe_dump(manifest,sort_keys=False))
(package/"publish.toml").write_text("\n".join(selections))
(package/".codex-plugin").mkdir()
(package/".codex-plugin/plugin.json").write_text(json.dumps({"name":"synth","version":"1.0.0","skills":"./skills/"}))
overlay=package/"overlays/skills"/lone
(overlay/"scripts").mkdir(parents=True)
(overlay/"scripts/tool.py").write_text('print("tool")\n')
(overlay/"extra.md").write_text("Local addition.\n")
'''


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
