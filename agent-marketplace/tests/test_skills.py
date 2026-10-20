"""Run every authored skill's own tests as part of the marketplace check."""

import importlib.util
from pathlib import Path
import sys
import unittest

SRC = Path(__file__).resolve().parents[1] / "src"
# Suites unittest cannot run here: pytest fixtures, a zsh harness, and cases
# that expect a fastcp binary on the host.
SKIPPED = {"image-gen-nano-banana", "skills-searcher", "experiment-scaffold"}


def load_tests(loader, tests, pattern):
    suite = unittest.TestSuite()
    for directory in sorted(SRC.glob("*/skills/*/tests")):
        skill = directory.parent
        if skill.name in SKIPPED:
            continue
        sys.path.insert(0, str(directory))
        for path in sorted(directory.glob("test_*.py")):
            # Skill test files can share names, so each gets a skill-qualified module name.
            name = f"skill_tests.{skill.parents[1].name}.{skill.name}.{path.stem}"
            spec = importlib.util.spec_from_file_location(name, path)
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            spec.loader.exec_module(module)
            suite.addTests(loader.loadTestsFromModule(module))
    return suite
