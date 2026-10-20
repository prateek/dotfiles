import json
import os
from pathlib import Path
import re
import shutil
import sys

cli, args = os.environ["FAKE_PLUGIN_CLI"], sys.argv[1:]
state_path = Path(os.environ["FAKE_PLUGIN_STATE"])
state = json.loads(state_path.read_text())
with open(os.environ["FAKE_PLUGIN_LOG"], "a") as log:
    log.write(cli + " " + " ".join(args) + "\n")


def save():
    state_path.write_text(json.dumps(state))


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


marketplaces = state["codex_marketplaces"] if cli == "codex" else state["marketplaces"]


def catalog_name(root):
    # Codex prefers its own catalog and falls back to Claude's, as the real CLI does.
    catalogs = [".agents/plugins/marketplace.json"] if cli == "codex" else []
    catalog = next(Path(root) / c for c in [*catalogs, ".claude-plugin/marketplace.json"] if (Path(root) / c).is_file())
    return json.loads(catalog.read_text())["name"]


def manifest_path(key, kind):
    name, marketplace = key.split("@")
    root = marketplaces[marketplace]
    return Path(root) / "plugins" / name / kind / "plugin.json"
omp_installed = state.setdefault("omp", {})
if args[0] == "app-server":
    for line in sys.stdin:
        request = json.loads(line)
        if request["method"] == "config/value/write":
            key = re.fullmatch(r'plugins\."(.+)"\.enabled', request["params"]["keyPath"])[1]
            state["codex"][key]["enabled"] = request["params"]["value"]
            save()
        print(json.dumps({"id": request["id"], "result": {}}), flush=True)
elif args[:3] == ["plugin", "marketplace", "list"] and cli == "omp":
    if marketplaces:
        print("Configured Marketplaces:\n")
        for name, root in marketplaces.items():
            print(f"  {name}  {root}")
    else:
        print("No marketplaces configured\n")
        print("Add one with: omp plugin marketplace add <source>")
elif args[:3] == ["plugin", "list", "--json"] and cli == "omp":
    plugins = [{"id": key, "scope": "user",
                "entries": [{"scope": "user", **value,
                             **({} if value["enabled"] else {"enabled": False})}]}
               for key, value in omp_installed.items()]
    print(json.dumps({"npm": [], "marketplace": plugins}))
elif args[:2] == ["plugin", "install"] and cli == "omp" and "--force" in args:
    key = args[2]
    if os.environ.get("FAKE_PLUGIN_FAIL") in ("install", key):
        fail("simulated install failure")
    name, marketplace = key.split("@")
    if any(other != key and other.split("@", 1)[0] == name for other in omp_installed):
        fail(f'Runtime package name "{name}" conflicts with an installed plugin')
    if "omp_catalog" in state and name not in state["omp_catalog"]:
        fail(f'Plugin "{name}" not found in marketplace "{marketplace}"')
    manifest = manifest_path(key, ".claude-plugin")
    prior = omp_installed.get(key)
    omp_installed[key] = {"enabled": bool(prior["enabled"]) if prior else True, "version": json.loads(manifest.read_text())["version"]}
    save()
elif args[:2] == ["plugin", "install"] and cli == "omp":
    fail("unexpected omp install without --force: " + " ".join(args))
elif args[:2] in (["plugin", "enable"], ["plugin", "disable"]) and cli == "omp":
    target = args[1] == "enable"
    if omp_installed[args[2]]["enabled"] is target:
        fail("plugin already has that enabled state")
    omp_installed[args[2]]["enabled"] = target
    save()
elif args[:2] == ["plugin", "uninstall"] and cli == "omp":
    del omp_installed[args[2]]
    save()
elif args[:3] == ["plugin", "marketplace", "list"]:
    entries = [{"name": name, "root": root, "installLocation": root} for name, root in marketplaces.items()]
    for entry in entries:
        source = state.get(cli + "_marketplace_sources", {}).get(entry["name"])
        if source:
            entry.update(source="git", url=source, ref="main", marketplaceSource={"sourceType": "git", "source": source})
    print(json.dumps(entries if cli == "claude" else {"marketplaces": entries}))
elif args[:3] == ["plugin", "marketplace", "add"]:
    source = args[3].split("#", 1)[0]
    root = state.get("upstream_sources", {}).get(source, args[3])
    name = catalog_name(root)
    if cli == "codex" and root != args[3]:
        cache = Path(os.environ["CODEX_HOME"]) / ".tmp/marketplaces" / name
        if cache.exists():
            shutil.rmtree(cache)
        shutil.copytree(root, cache)
        root = str(cache)
    marketplaces[name] = root
    if root != args[3]:
        state.setdefault(cli + "_marketplace_sources", {})[name] = source
    if cli == "omp":
        registry = Path(os.environ["HOME"]) / ".omp/marketplaces.json"
        registry.parent.mkdir(parents=True, exist_ok=True)
        sources = state.get("omp_marketplace_sources", {})
        registry.write_text(json.dumps({"marketplaces": [
            {"name": name, "sourceUri": sources.get(name, root)} for name, root in marketplaces.items()
        ]}))
    save()
elif args[:3] == ["plugin", "marketplace", "remove"]:
    del marketplaces[args[3]]
    save()
elif args[:3] in (["plugin", "marketplace", "update"], ["plugin", "marketplace", "upgrade"]):
    if cli == "omp":
        catalog = Path(marketplaces[args[3]]) / ".claude-plugin/marketplace.json"
        state["omp_catalog"] = [entry["name"] for entry in json.loads(catalog.read_text())["plugins"]]
        save()
    elif cli == "codex" and (source := state.get("codex_marketplace_sources", {}).get(args[3])):
        root = Path(marketplaces[args[3]])
        shutil.rmtree(root)
        shutil.copytree(state["upstream_sources"][source], root)
elif args[:2] == ["plugin", "list"]:
    entries = [{("id" if cli == "claude" else "pluginId"): key, "scope": "user", **value}
               for key, value in state[cli].items()]
    print(json.dumps(entries if cli == "claude" else {"installed": entries, "available": []}))
elif args[:2] in (["plugin", "install"], ["plugin", "add"], ["plugin", "update"]):
    if os.environ.get("FAKE_PLUGIN_FAIL") in ("install", args[2]) and os.environ.get("FAKE_PLUGIN_FAIL_CLI", cli) == cli:
        if os.environ.get("FAKE_PLUGIN_ENABLE_BEFORE_FAILURE"):
            state[cli][args[2]]["enabled"] = True
            save()
        fail("simulated install failure")
    manifest = manifest_path(args[2], f".{cli}-plugin")
    if cli == "codex" and not manifest.is_file():
        manifest = manifest_path(args[2], ".claude-plugin")
    prior = state[cli].get(args[2])
    enabled = prior["enabled"] if args[1] == "update" and prior else True
    state[cli][args[2]] = {"enabled": enabled, "version": json.loads(manifest.read_text())["version"]}
    save()
elif args[:2] in (["plugin", "enable"], ["plugin", "disable"]):
    target = args[1] == "enable"
    if state[cli][args[2]]["enabled"] is target:
        fail("plugin already has that enabled state")
    state[cli][args[2]]["enabled"] = target
    save()
elif args[:2] in (["plugin", "uninstall"], ["plugin", "remove"]):
    del state[cli][args[2]]
    save()
else:
    fail("unexpected fake invocation: " + " ".join(args))
