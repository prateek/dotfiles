import tomllib

from tests.support.python import ROOT


def package_policy(agent):
    result = {}
    for manifest in sorted((ROOT / "home/dot_agents/packages").glob("*/package.toml")):
        package = tomllib.loads(manifest.read_text())
        if package.get("render", {}).get(agent) == "plugin":
            result[f"{manifest.parent.name}@prateek-local"] = package.get("default_loaded", True)
    return result
