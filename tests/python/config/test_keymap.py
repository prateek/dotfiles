import json
import subprocess
import tempfile
from pathlib import Path

from tests.support.python import ROOT, RepoTestCase

RENDER = ROOT / "scripts/macos/render-keymap"


def manipulator(key, to, *, mandatory=(), gated=True):
    item = {"type": "basic", "from": {"key_code": key}, "to": to}
    if mandatory:
        item["from"]["modifiers"] = {"mandatory": list(mandatory)}
    if gated:
        item["conditions"] = [{"type": "variable_if", "name": "nav_mode", "value": 1}]
    return item


def profile(manipulators):
    return {"profiles": [{"name": "Default", "complex_modifications": {"rules": [{"manipulators": manipulators}]}}]}


class KeymapCheatsheetTests(RepoTestCase):
    def sheet(self, config):
        with tempfile.TemporaryDirectory() as tmp:
            source, target = Path(tmp, "karabiner.json"), Path(tmp, "out/nav.svg")
            source.write_text(json.dumps(config))
            result = subprocess.run([RENDER, source, target], capture_output=True, text=True, timeout=120)
            return result, target.read_text() if target.exists() else None

    def test_sheet_labels_layer_keys_from_the_compiled_rules_and_ignores_ungated_ones(self):
        leave = {"set_variable": {"name": "nav_mode", "value": 0}}
        result, svg = self.sheet(profile([
            manipulator("spacebar", [{"set_variable": {"name": "nav_mode", "value": 1}}],
                        mandatory=["left_control"], gated=False),
            manipulator("escape", [leave, {"shell_command": "pkill -x keymap-overlay"}]),
            manipulator("grave_accent_and_tilde", [{"shell_command": "keymap-overlay sheet.svg"}]),
            manipulator("w", [{"key_code": "up_arrow"}]),
            manipulator("q", [{"key_code": "left_arrow", "modifiers": ["left_option"]}]),
            manipulator("c", [{"key_code": "c", "modifiers": ["left_command"]}, leave]),
            manipulator("h", [{"key_code": "k", "modifiers": ["left_control", "left_shift"]}]),
            manipulator("j", [{"key_code": "down_arrow"}], gated=False),
        ]))
        self.assertEqual((result.returncode, result.stderr), (0, ""))
        for label in (">↑<", ">this sheet<", ">word ←<", ">copy<", ">then leave<", ">⌃⇧K<", "⌃Space to enter", "Leave: ⌃Space, Esc"):
            self.assertIn(label, svg)
        self.assertNotIn(">↓<", svg)

    def test_profile_without_the_layer_fails_instead_of_writing_an_empty_sheet(self):
        result, svg = self.sheet(profile([manipulator("j", [{"key_code": "down_arrow"}], gated=False)]))
        self.assertEqual(result.returncode, 1)
        self.assertIn("no nav layer", result.stderr)
        self.assertIsNone(svg)
