import json
import os
import subprocess
import sys

result = subprocess.run(
    [sys.argv[1], "--dry-run-all"], capture_output=True, timeout=20,
    env=os.environ | {"GOKU_EDN_CONFIG_FILE": sys.argv[2]},
)
# Goku v0.8.0 prints dry-run JSON then exits 1 (core.clj:118-122).
assert result.returncode == 1, f"unexpected Goku dry-run status {result.returncode}: {result.stderr.decode(errors='replace')}"
assert not result.stderr, result.stderr.decode(errors="replace")
config = json.loads(result.stdout)
profile = next(profile for profile in config["profiles"] if profile["name"] == "Default")
manipulators = [item for rule in profile["complex_modifications"]["rules"] for item in rule["manipulators"]]


def from_key(item, key):
    return item.get("from", {}).get("key_code") == key


def mode_condition(item, kind):
    return any(condition.get("type") == kind and condition.get("name") == "pad_mouse_mode"
               for condition in item.get("conditions", []))


def pad_scoped(item):
    return any(condition.get("type") == "device_if" and any(
        identifier.get("vendor_id") == 11720 and identifier.get("product_id") == 36888
        for identifier in condition.get("identifiers", [])
    ) for condition in item.get("conditions", []))


def no_variable_gate(item):
    return not any(condition["type"].startswith("variable") for condition in item.get("conditions", []))


for key, action in (
    ("g", {"mouse_key": {"y": -1536}}),
    ("f", {"mouse_key": {"vertical_wheel": -40}}),
    ("c", {"mouse_key": {"horizontal_wheel": 40}}),
    ("m", {"pointing_button": "button1"}),
    ("k", {"pointing_button": "button2"}),
):
    matches = [item for item in manipulators if from_key(item, key)
               and all(item["to"][0].get(field) == value for field, value in action.items())
               and mode_condition(item, "variable_if")]
    assert matches, (key, action)
    if key == "g":
        assert any(pad_scoped(item) for item in matches)

for key, target in (("f", "up_arrow"), ("i", "escape"), ("m", "vk_none"), ("n", "vk_none")):
    matches = [item for item in manipulators if from_key(item, key) and item["to"][0].get("key_code") == target]
    assert matches, (key, target)
    if key != "n":
        assert any(no_variable_gate(item) and (key != "f" or pad_scoped(item)) for item in matches)

overlay = next(i for i, item in enumerate(manipulators) if from_key(item, "f")
               and item["to"][0].get("mouse_key", {}).get("vertical_wheel") == -40)
base = next(i for i, item in enumerate(manipulators) if from_key(item, "f") and item["to"][0].get("key_code") == "up_arrow")
assert overlay < base, "mouse overlay must precede the ungated base layer"

for kind, value in (("variable_unless", 1), ("variable_if", 0)):
    toggles = [item for item in manipulators if from_key(item, "o") and mode_condition(item, kind)
               and any(event.get("set_variable", {}).get("name") == "pad_mouse_mode"
                       and event["set_variable"]["value"] == value for event in item["to"])]
    assert any(any(event.get("set_notification_message", {}).get("id") == "pad_mouse_mode"
                   and bool(event["set_notification_message"]["text"]) == bool(value)
                   for event in item["to"]) for item in toggles), (kind, value)

assert any(from_key(item, "left_control") and item.get("parameters", {}).get("basic.to_if_alone_timeout_milliseconds") == 200
           for item in manipulators)
assert any(from_key(item, "caps_lock") and item.get("to_if_alone", [{}])[0].get("key_code") == "escape"
           and any(condition.get("type") == "device_if" and any(identifier.get("is_built_in_keyboard") is True
                   for identifier in condition.get("identifiers", [])) for condition in item.get("conditions", []))
           for item in manipulators)

for key in ("left_shift", "right_shift"):
    matches = [item for item in manipulators if from_key(item, key) and item["to"][0].get("key_code") == key
               and "lazy" not in item["to"][0] and item.get("to_if_alone", [{}])[0].get("key_code") == "f18"]
    assert matches, key
    if key == "left_shift":
        assert any(item.get("parameters", {}).get("basic.to_if_alone_timeout_milliseconds") == 100
                   and "conditions" not in item for item in matches)
