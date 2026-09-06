import re
import unittest

from tests.support.python import ROOT


class ConventionPointerTests(unittest.TestCase):
    def test_every_convention_has_a_valid_route_from_the_agent_kernel(self):
        docs = ROOT / "home/dot_agents/docs"
        generated = {"slack.md": ROOT / "home/.chezmoitemplates/agent-slack-base.md"}

        def source(name):
            return generated.get(name, docs / name)

        lines = (ROOT / "home/dot_agents/AGENTS.md").read_text().splitlines()
        self.assertEqual(lines.count("## Convention pointers"), 1)
        pointers = set()
        for line in lines[lines.index("## Convention pointers") + 1:]:
            if line.startswith("#"):
                break
            if not line.startswith("- "):
                continue
            match = re.fullmatch(r"- .+: `~/\.agents/docs/([a-z0-9-]+\.md)`", line)
            self.assertIsNotNone(match, line)
            name = match[1]
            self.assertNotIn(name, pointers, f"duplicate pointer: {name}")
            self.assertTrue(source(name).is_file(), f"missing convention source: {source(name)}")
            pointers.add(name)
        self.assertTrue(pointers, "Convention pointers is empty")
        named = set(re.findall(r"~/\.agents/docs/([a-z0-9-]+\.md)", "\n".join(lines)))
        self.assertLessEqual(named, pointers)

        reachable = set(pointers)
        queue = list(pointers)
        while queue:
            name = queue.pop()
            for target in re.findall(r"\]\((?:\./)?([a-z0-9-]+\.md)", source(name).read_text()):
                self.assertTrue(source(target).is_file(), f"{name} links to missing source: {target}")
                if target not in reachable:
                    reachable.add(target)
                    queue.append(target)
        self.assertTrue(docs.is_dir())
        self.assertLessEqual({path.name for path in docs.glob("*.md")}, reachable)
