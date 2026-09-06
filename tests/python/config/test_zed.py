import json
import re

from tests.support.python import RepoTestCase


class ZedRenderTests(RepoTestCase):
    def test_settings_render_as_a_jsonc_object(self):
        text = self.render("home/dot_config/zed/private_settings.json.tmpl").decode()
        text = re.sub(r"(?m)^\s*//.*\n", "", text)
        text = re.sub(r",\s*([}\]])", r"\1", text)
        self.assertIsInstance(json.loads(text), dict)
