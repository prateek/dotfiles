from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest
from PIL import Image as PILImage


TESTS_DIR = Path(__file__).resolve().parent
SKILL_ROOT = TESTS_DIR.parent
SCRIPT_PATH = SKILL_ROOT / "scripts" / "nano_banana_skill.py"


@pytest.fixture(scope="session")
def skill_module():
    module_name = "image_gen_nano_banana_script"
    if module_name in sys.modules:
        return sys.modules[module_name]

    spec = importlib.util.spec_from_file_location(module_name, SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def script_path() -> Path:
    return SCRIPT_PATH


def make_test_image(width: int, height: int, mode: str = "RGB") -> PILImage.Image:
    if mode == "RGBA":
        return PILImage.new("RGBA", (width, height), (255, 0, 0, 128))
    return PILImage.new(mode, (width, height), (0, 128, 255))
