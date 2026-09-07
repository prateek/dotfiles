import json
import os
from pathlib import Path
import re
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


marketplaces = state["marketplaces" if cli == "claude" else "codex_marketplaces"]
if args[0] == "app-server":
    for line in sys.stdin:
        request = json.loads(line)
        if request["method"] == "config/value/write":
            key = re.fullmatch(r'plugins\."(.+)"\.enabled', request["params"]["keyPath"])[1]
            state["codex"][key]["enabled"] = request["params"]["value"]
            save()
        print(json.dumps({"id": request["id"], "result": {}}), flush=True)
elif args[:3] == ["plugin", "marketplace", "list"]:
    entries = [{"name": name, "root": root, "installLocation": root} for name, root in marketplaces.items()]
    print(json.dumps(entries if cli == "claude" else {"marketplaces": entries}))
elif args[:3] == ["plugin", "marketplace", "add"]:
    marketplaces["prateek-local"] = args[3]
    save()
elif args[:3] == ["plugin", "marketplace", "remove"]:
    del marketplaces[args[3]]
    save()
elif args[:3] == ["plugin", "marketplace", "update"]:
    pass
elif args[:2] == ["plugin", "list"]:
    entries = [{("id" if cli == "claude" else "pluginId"): key, "scope": "user", **value}
               for key, value in state[cli].items()]
    print(json.dumps(entries if cli == "claude" else {"installed": entries, "available": []}))
elif args[:2] in (["plugin", "install"], ["plugin", "add"], ["plugin", "update"]):
    if os.environ.get("FAKE_PLUGIN_FAIL") in ("install", args[2]):
        fail("simulated install failure")
    name = args[2].split("@")[0]
    manifest = Path(marketplaces["prateek-local"]) / "plugins" / name / f".{cli}-plugin/plugin.json"
    state[cli][args[2]] = {"enabled": True, "version": json.loads(manifest.read_text())["version"]}
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
