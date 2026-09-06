import json

from tests.python.agents.console_support import ConsoleCase, ROOT, run_budget
from skill_console.budget import write_safe


class ConsoleBrowserTests(ConsoleCase):
    def browser(self, mode, cases):
        result = self.command([
            "node", str(ROOT / "tests/scenarios/agents/console-browser.cjs"),
            str(ROOT / ".agents/skills/agent-skill-management/templates/skill-console.html"), mode,
        ], raw=json.dumps(cases).encode())
        self.assertEqual(result.stderr, b"")
        return json.loads(result.stdout)

    def test_browser_admits_from_integer_costs_with_the_same_membership_and_headroom(self):
        names = ("at-budget", "one-over", "separator-once", "greedy-non-stop", "ties-forward", "ties-reversed",
                 "all-pinned", "empty", "duplicates", "forced-fits", "forced-priority", "when-to-use")
        cases, expected = [], []
        for name in names:
            admission, entries, _ = run_budget(self.fixtures / f"{name}.json")
            cases.append({"budget": admission.budget, "entries": [
                {"name": entry.name, "protected": entry.protected, "forced_name_only": entry.forced_name_only,
                 "rank": entry.rank, "name_only_cost": cost.name_only_cost, "full_cost": cost.full_cost,
                 "upgrade_cost": cost.upgrade_cost}
                for entry, cost in zip(entries, admission.costs, strict=True)
            ]})
            expected.append({
                "mode": admission.mode, "demand_chars": admission.demand_chars,
                "rendered_chars": admission.rendered_chars, "headroom_chars": admission.headroom_chars,
                "all_pinned": admission.all_pinned, "full": list(admission.full), "name_only": list(admission.name_only),
            })
        for name, actual, wanted in zip(names, self.browser("admit", cases), expected, strict=True):
            with self.subTest(example=name):
                self.assertEqual(actual, wanted)

    def test_browser_safe_write_matches_python_for_every_non_surrogate_bmp_character(self):
        points = [None if 0xD800 <= cp <= 0xDFFF else cp for cp in range(0x10000)]
        expected = [None if cp is None else write_safe("a" + chr(cp) + "b")[0] for cp in points]
        actual = self.browser("write-safe", points)
        self.assertEqual(len(actual), len(expected))
        self.assertEqual([cp for cp, got, wanted in zip(points, actual, expected, strict=True) if got != wanted], [])
