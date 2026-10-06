import contextlib
import io
import json
import sys
import tempfile
from argparse import Namespace
from importlib.machinery import SourceFileLoader
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tests.support.python import ROOT, RepoTestCase

SCRIPT = ROOT / "scripts/keyboard/nocfree-keymap"
KEYMAP = ROOT / "scripts/keyboard/nocfree-lite.vil"
tool = SourceFileLoader("nocfree_keymap", str(SCRIPT)).load_module()


class FakeVial:
    def __init__(self, keymap):
        self.keymap = [[row[:] for row in layer] for layer in keymap]
        self.writes = 0
        self.reply = b""

    def open_path(self, path):
        pass

    def write(self, report):
        cmd, l, r, c, hi, lo = report[1:7]
        if cmd == 0x05:
            self.keymap[l][r][c] = hi << 8 | lo
            self.writes += 1
        code = self.keymap[l][r][c]
        self.reply = bytes([cmd, l, r, c, code >> 8, code & 0xFF]).ljust(32, b"\0")

    def read(self, size, timeout):
        return list(self.reply)


def fake_hid(connections):
    infos = [{"product_id": tool.CONNECTIONS[label], "usage_page": 0xFF60, "usage": 0x61, "path": label.encode()}
             for label in connections]
    devices = iter(connections.values())
    return SimpleNamespace(enumerate=lambda vendor: infos, device=lambda: next(devices))


class NocFreeKeymapTests(RepoTestCase):
    def run_tool(self, connections, **args):
        out = io.StringIO()
        with mock.patch.dict(sys.modules, {"hid": fake_hid(connections)}), contextlib.redirect_stdout(out):
            status = tool.apply(Namespace(keymap=KEYMAP, **args))
        return status, out.getvalue()

    def test_stored_keymap_carries_the_keys_the_nav_layer_depends_on(self):
        keymap = tool.load(KEYMAP)
        # Caps: hold ⌃, tap Esc (QMK LCTL_T(KC_ESCAPE)); top-left is a plain ` so the cheatsheet key
        # does not send Esc; firmware layer 1's left ⇧ taps F20 (0x6F) for Karabiner's select mode.
        self.assertEqual(keymap[0][2][0], 0x2129)
        self.assertEqual(keymap[0][0][0], 0x35)
        self.assertEqual(keymap[1][3][0], 0x226F)
        self.assertEqual((keymap[0][4][8], keymap[0][4][9]), (0xE7, 0x5221))  # right ⌘, then MO(1) holds layer 1

    def test_stored_keymap_is_written_in_the_names_the_tool_dumps(self):
        self.assertEqual(tool.dumps(tool.load(KEYMAP)), KEYMAP.read_text())

    def test_unknown_keycode_names_the_bad_key(self):
        layout = json.loads(KEYMAP.read_text())
        layout["layout"][2][1][1] = "KC_NOT_A_KEY"
        with tempfile.NamedTemporaryFile("w", suffix=".vil") as bad:
            bad.write(json.dumps(layout))
            bad.flush()
            with self.assertRaisesRegex(SystemExit, "KC_NOT_A_KEY"):
                tool.load(bad.name)

    def test_apply_fails_when_no_nocfree_is_attached(self):
        with self.assertRaisesRegex(SystemExit, "NocFree .* is not attached"):
            self.run_tool({}, dry_run=True)

    def test_dry_run_reports_each_changed_key_and_writes_nothing(self):
        stale = tool.load(KEYMAP)
        stale[1][3][0] = 0x01
        stale[0][0][0] = 0x7C16
        board = FakeVial(stale)
        status, out = self.run_tool({"2.4G": board}, dry_run=True)
        self.assertEqual(status, 0)
        self.assertIn("2.4G: layer 0 r0c0: KC_GESC -> KC_GRAVE", out)
        self.assertIn("2.4G: layer 1 r3c0: KC_TRNS -> LSFT_T(KC_F20)", out)
        self.assertIn("2.4G: 2 keys would change", out)
        self.assertEqual(board.writes, 0)

    def test_apply_writes_only_the_differing_keys_on_every_attached_connection(self):
        stale = tool.load(KEYMAP)
        stale[0][2][0] = 0x39
        wired, dongle = FakeVial(tool.load(KEYMAP)), FakeVial(stale)
        status, out = self.run_tool({"wired": wired, "2.4G": dongle}, dry_run=False)
        self.assertEqual(status, 0)
        self.assertEqual((wired.writes, dongle.writes), (0, 1))
        self.assertEqual(dongle.keymap, tool.load(KEYMAP))
        self.assertIn("2.4G: 1 of 1 keys written", out)
