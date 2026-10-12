import tomllib

from tests.support.python import ROOT


def package_policy(agent):
    result = {}
    policy = tomllib.loads((ROOT / "home/.chezmoidata/agent_plugins.toml").read_text())["agent_plugins"]
    for name, package in policy.items():
        if package[agent]:
            result[f"{name}@prateek-local"] = package["default_loaded"]
    for entry in tomllib.loads((ROOT / "home/.chezmoidata/agent_upstream_plugins.toml").read_text())["agent_upstream_plugins"]:
        if entry[agent]:
            result[f"{entry['plugin']}@{entry['marketplace']}"] = entry["default_loaded"]
    return result
