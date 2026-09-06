import json
import plistlib

from tests.support.python import ROOT, RepoTestCase


class NvaltColorsTests(RepoTestCase):
    def test_color_archive_contains_named_rgb_entries_and_preserves_equivalent_bytes(self):
        json.loads((ROOT / "home/.chezmoiassets/Library/Colors/nvALT.clr.json").read_text())
        modifier = self.modifier("home/Library/private_Colors/modify_nvALT.clr.tmpl")
        result = self.command(modifier)
        self.assertEqual(result.stderr, b"")
        payload = plistlib.loads(result.stdout)
        objects = payload["$objects"]
        keys = [objects[uid.data] for uid in objects[payload["$top"]["NSKeys"].data]["NS.objects"]]
        colors = [objects[uid.data]["NSRGB"].decode("ascii").rstrip("\0")
                  for uid in objects[payload["$top"]["NSColors"].data]["NS.objects"]]
        self.assertEqual(payload["$archiver"], "NSKeyedArchiver")
        self.assertEqual(keys, ["Search Highlight", "Foreground Text (AndaleMono 13)", "Background"])
        self.assertEqual(colors, [
            "0.003921568859 0.3215686381 0.6627451181",
            "0.9215686917 0.9058824182 0.8901961446",
            "0.2235294282 0.2235294282 0.2235294282",
        ])
        reordered = plistlib.dumps(payload, fmt=plistlib.FMT_BINARY, sort_keys=True)
        self.assertEqual(self.command(modifier, reordered).stdout, reordered)
