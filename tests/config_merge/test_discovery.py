import unittest

from scenarios import SCENARIOS
from tests.support.python import ROOT

# Paths are relative to the repository root; each exception needs an ownership reason.
EXCEPTIONS: dict[str, str] = {}


class PlistDiscoveryTests(unittest.TestCase):
    def test_every_shipped_modifier_has_a_scenario_or_justified_exception(self):
        shipped = {
            path.relative_to(ROOT).as_posix()
            for path in (ROOT / "home").rglob("modify_*.plist*")
        }
        scenarios = {
            f"home/Library/private_Preferences/modify_private_{spec.bundle_id}.plist.tmpl"
            for spec in SCENARIOS.values()
        }
        self.assertEqual(
            len(scenarios), len(SCENARIOS), "duplicate bundle ID in scenarios"
        )
        for path, reason in EXCEPTIONS.items():
            self.assertTrue(reason.strip(), f"{path}: exception needs a reason")
        self.assertFalse(
            scenarios & EXCEPTIONS.keys(), "scenario also listed as an exception"
        )
        covered = scenarios | EXCEPTIONS.keys()
        self.assertEqual(
            shipped,
            covered,
            f"Missing scenarios: {sorted(shipped - covered)}\n"
            f"Stale scenarios/exceptions: {sorted(covered - shipped)}",
        )


if __name__ == "__main__":
    unittest.main()
