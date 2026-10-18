"""Include the portable search contract suite in marketplace checks."""

import importlib.util
from pathlib import Path


def load_tests(loader, tests, pattern):
    path = (
        Path(__file__).resolve().parents[1]
        / "packages/utils-agent/skills/search/tests/test_engine.py"
    )
    spec = importlib.util.spec_from_file_location("portable_search_contracts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return loader.loadTestsFromModule(module)
