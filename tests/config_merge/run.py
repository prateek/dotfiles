import argparse
import unittest

from scenarios import SCENARIOS
from test_apps import AppPlistTests
from test_discovery import PlistDiscoveryTests
from test_plist_merge import PlistMergeTests

parser = argparse.ArgumentParser(
    description="Verify real plist merge commands and app modifiers."
)
parser.add_argument(
    "--app", nargs="+", choices=sorted(SCENARIOS), help="Run only these app scenarios."
)
args = parser.parse_args()
suite = unittest.TestSuite()
if args.app is None:
    suite.addTests(
        unittest.defaultTestLoader.loadTestsFromTestCase(PlistDiscoveryTests)
    )
    suite.addTests(unittest.defaultTestLoader.loadTestsFromTestCase(PlistMergeTests))
AppPlistTests.apps = args.app or SCENARIOS
suite.addTests(unittest.defaultTestLoader.loadTestsFromTestCase(AppPlistTests))
raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
