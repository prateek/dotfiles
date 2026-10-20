import tomllib

from tests.support.python import ROOT


def package_policy(*, retired=True):
    """A client's expected enabled state: every plugin goes to every selected harness.

    Retired official installs are pinned disabled only where a client once had
    them (Claude and Pi); Codex never installed them, so its config omits them.
    """
    result = {}
    policy = tomllib.loads((ROOT / "home/.chezmoidata/agent_plugins.toml").read_text())["agent_plugins"]
    for name, package in policy.items():
        result[f"{name}@prateek-local"] = package["default_loaded"]
    upstream = tomllib.loads((ROOT / "home/.chezmoidata/agent_upstream_plugins.toml").read_text())
    for entry in upstream["agent_upstream_plugins"]:
        result[f"{entry['plugin']}@{entry['marketplace']}"] = entry["default_loaded"]
    for entry in upstream.get("retired_agent_upstream_plugins", []) if retired else ():
        result[f"{entry['plugin']}@{entry['marketplace']}"] = False
    return result
