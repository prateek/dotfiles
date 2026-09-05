import plistlib
import unittest

from support import PlistTestCase


class PlistMergeTests(PlistTestCase):
    def test_preserves_nan_values_and_unchanged_bytes(self):
        expected = {"managed": {"value": float("nan")}}
        desired = plistlib.dumps(expected)
        self.assert_plist(self.merge(desired, b""), expected)
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(format=fmt):
                raw = plistlib.dumps(expected, fmt=fmt)
                self.assertEqual(self.merge(desired, raw), raw)

    def test_equivalent_binary_container_references_preserve_original_bytes(self):
        shared = {"count": 1}
        current = {"managed": {"a": shared, "b": shared}, "local": "keep"}
        desired = plistlib.dumps({"managed": {"a": {"count": 1}, "b": {"count": 1}}})
        raw = plistlib.dumps(current, fmt=plistlib.FMT_BINARY)
        self.assertEqual(self.merge(desired, raw), raw)

    def test_replaces_top_level_values_with_different_numeric_types(self):
        for current, wanted in (
            (True, 1),
            (1, True),
            (False, 0),
            (0, False),
            (1.0, 1),
            (1, 1.0),
        ):
            with self.subTest(current=repr(current), desired=repr(wanted)):
                desired = plistlib.dumps({"managed": wanted})
                raw = plistlib.dumps({"managed": current, "local": "keep"})
                self.assert_plist(
                    self.merge(desired, raw), {"managed": wanted, "local": "keep"}
                )

    def test_replaces_nested_values_with_different_numeric_types(self):
        desired = plistlib.dumps({"managed": {"values": [True, 1, 1.0, False, 0]}})
        current = {
            "managed": {"values": [1, True, 1, 0, False]},
            "local": [1, True, 1.0],
        }
        expected = {
            "managed": {"values": [True, 1, 1.0, False, 0]},
            "local": [1, True, 1.0],
        }
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(format=fmt):
                self.assert_plist(
                    self.merge(desired, plistlib.dumps(current, fmt=fmt)), expected
                )

    def test_rejects_invalid_input_without_replacement_output(self):
        with self.subTest(input="malformed current"):
            self.merge(
                plistlib.dumps({"managed": True}), b"not a plist", error="Invalid file"
            )
        with self.subTest(input="malformed desired"):
            self.merge(b"not a plist", b"", error="Invalid file")
        with self.subTest(input="non-dictionary desired"):
            self.merge(
                plistlib.dumps(["invalid"]),
                b"",
                error="desired plist must be a dict at root",
            )

    def test_seeds_missing_or_non_dictionary_current_plist(self):
        desired = plistlib.dumps({"managed": ["new"]})
        for raw in (b"", b" \n\t", plistlib.dumps(["old"])):
            with self.subTest(input=raw):
                merged = self.merge(desired, raw)
                self.assertTrue(merged.startswith(b"bplist00"))
                self.assert_plist(merged, {"managed": ["new"]})

    def test_unchanged_input_preserves_original_bytes(self):
        desired = plistlib.dumps({"managed": {"a": 1, "z": 2}})
        current = {"z-local": b"data", "managed": {"z": 2, "a": 1}}
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(format=fmt):
                raw = plistlib.dumps(current, fmt=fmt, sort_keys=False)
                self.assertEqual(self.merge(desired, raw), raw)

    def test_replaces_whole_top_level_values_and_preserves_unmanaged_values(self):
        desired = plistlib.dumps({"managed": {"new": b"data"}, "list": [3, 2]})
        current = {"managed": {"old": True}, "list": [1], "local": {"keep": 42}}
        expected = {"managed": {"new": b"data"}, "list": [3, 2], "local": {"keep": 42}}
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(format=fmt):
                merged = self.merge(desired, plistlib.dumps(current, fmt=fmt))
                self.assertTrue(merged.startswith(b"bplist00"))
                self.assert_plist(merged, expected)

    def test_deletes_hyphenated_key_and_preserves_unrelated_key(self):
        desired = b"""<?xml version="1.0" encoding="UTF-8"?>
<!-- chezmoi-delete: obsolete-key -->
<plist version="1.0"><dict/></plist>
"""
        raw = plistlib.dumps({"obsolete-key": True, "unrelated": "keep"})
        self.assert_plist(self.merge(desired, raw), {"unrelated": "keep"})

    def test_deletes_mixed_keys_across_multiline_and_multiple_comments(self):
        desired = b"""<?xml version="1.0" encoding="UTF-8"?>
<!-- chezmoi-delete: obsolete,
     obsolete-key, absent, -->
<!-- ordinary comment -->
<!-- chezmoi-delete: another-key -->
<plist version="1.0"><dict/></plist>
"""
        raw = plistlib.dumps(
            {
                "obsolete": 1,
                "obsolete-key": 2,
                "another-key": 3,
                "unrelated": "keep",
            },
            fmt=plistlib.FMT_BINARY,
        )
        self.assert_plist(self.merge(desired, raw), {"unrelated": "keep"})


if __name__ == "__main__":
    unittest.main()
