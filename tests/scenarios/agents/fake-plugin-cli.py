import json, os, sys
cli = os.environ["FAKE_PLUGIN_CLI"]
args = sys.argv[1:]
state = json.load(open(os.environ["FAKE_PLUGIN_STATE"]))
with open(os.environ["FAKE_PLUGIN_LOG"], "a") as log:
    log.write(cli + " " + " ".join(args) + "\n")

def save():
    json.dump(state, open(os.environ["FAKE_PLUGIN_STATE"], "w"))

def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)

if cli == "claude":
    if args[:3] == ["plugin", "marketplace", "list"]:
        print(json.dumps([{"name": m, "path": p, "installLocation": p} for m, p in state["marketplaces"].items()]))
    elif args[:3] == ["plugin", "marketplace", "add"]:
        # Re-adding a registered name updates its path in place (verified 2.1.258).
        state["marketplaces"]["prateek-local"] = args[3]; save()
    elif args[:2] == ["plugin", "list"]:
        print(json.dumps([{"id": k, "scope": "user", "enabled": v} for k, v in state["claude"].items()]))
    elif args[:2] == ["plugin", "install"]:
        if "prateek-local" not in state["marketplaces"]:
            fail(f'Plugin "{args[2]}" not found in marketplace')
        if os.environ.get("FAKE_PLUGIN_FAIL") == "install":
            fail("simulated install failure")
        state["claude"][args[2]] = True; save()
    elif args[:2] in (["plugin", "enable"], ["plugin", "disable"]):
        target = args[1] == "enable"
        if state["claude"].get(args[2]) is target:
            fail(f"Plugin {args[2]} is already {'enabled' if target else 'disabled'} at user scope")
        state["claude"][args[2]] = target; save()
    elif args[:2] == ["plugin", "uninstall"]:
        if args[2] not in state["claude"]:
            fail(f"Plugin {args[2]} not found in installed plugins")
        del state["claude"][args[2]]; save()
    else:
        fail("unexpected fake claude invocation: " + " ".join(args))
elif cli == "codex":
    if args[:2] == ["plugin", "list"]:
        print(json.dumps({"installed": [{"pluginId": p} for p in state["codex"]], "available": []}))
    elif args[:2] == ["plugin", "add"]:
        if args[2] not in state["codex"]:
            state["codex"].append(args[2])
        save()
    elif args[:2] == ["plugin", "remove"]:
        if args[2] not in state["codex"]:
            fail(f"plugin {args[2]} is not installed")
        state["codex"].remove(args[2]); save()
    else:
        fail("unexpected fake codex invocation: " + " ".join(args))
else:
    fail("unexpected fake cli " + cli)
