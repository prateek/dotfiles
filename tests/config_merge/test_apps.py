import plistlib

from scenarios import SCENARIOS
from tests.config_merge.support import PlistTestCase


def _scenario_test(app):
    def test(self):
        self.check_scenario(SCENARIOS[app])

    test.__name__ = f"test_{app}"
    return test


class AppPlistMeta(type):
    """Give every app its own test id so `-k <app>` and failure names name the app."""

    def __new__(metaclass, name, bases, namespace):
        for app in SCENARIOS:
            test = _scenario_test(app)
            namespace[test.__name__] = test
        return super().__new__(metaclass, name, bases, namespace)


class AppPlistTests(PlistTestCase, metaclass=AppPlistMeta):
    def check_scenario(self, scenario):
        modifier = self.modifier(scenario.bundle_id)
        desired_xml = self.render(
            f"home/.chezmoitemplates/{scenario.bundle_id}.plist.tmpl"
        )
        self.plist_command(["/usr/bin/plutil", "-lint", "-s", "-"], desired_xml)
        desired = plistlib.loads(desired_xml)
        self.assertIsInstance(desired, dict)

        def check(raw, local):
            self.assertTrue(
                raw.startswith(b"bplist00"), "modifier must emit binary plist"
            )
            merged = plistlib.loads(raw)
            self.assertEqual(set(merged), desired.keys() | local.keys())
            if not local:
                for key in scenario.local:
                    self.assertNotIn(
                        key, merged.keys(), "empty input acquired an app-owned key"
                    )
            for kind, values in (
                ("desired", desired),
                ("local", local),
                ("known", scenario.expected),
            ):
                for key, value in values.items():
                    with self.subTest(assertion=kind, key=key):
                        self.assert_typed_equal(merged.get(key), value, key)
            if scenario.check is not None:
                scenario.check(self, merged)
            self.assertEqual(
                self.plist_command(modifier, raw), raw, "second merge changed bytes"
            )
            reordered = plistlib.dumps(merged, fmt=plistlib.FMT_BINARY, sort_keys=True)
            self.assertEqual(
                self.plist_command(modifier, reordered),
                reordered,
                "equivalent input changed bytes",
            )

        with self.subTest(input="empty"):
            check(self.plist_command(modifier), {})
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(input=fmt):
                current = scenario.overrides | scenario.local
                raw = plistlib.dumps(current, fmt=fmt, sort_keys=False)
                check(self.plist_command(modifier, raw), scenario.local)
