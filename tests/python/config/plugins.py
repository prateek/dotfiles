import tomllib

from tests.support.python import ROOT


def package_policy(agent):
    result = {}
    policy = tomllib.loads((ROOT / "home/.chezmoidata/agent_plugins.toml").read_text())["agent_plugins"]
    for name, package in policy.items():
        if package[agent]:
            result[f"{name}@prateek-local"] = package["default_loaded"]
    return result
