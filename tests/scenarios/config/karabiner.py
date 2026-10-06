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

matches = [item for item in manipulators if from_key(item, "left_command")
           and item["to"][0].get("key_code") == "left_command" and "lazy" not in item["to"][0]
           and item.get("to_if_alone", [{}])[0].get("key_code") == "f18"]
assert any(item.get("parameters", {}).get("basic.to_if_alone_timeout_milliseconds") == 200
           and "conditions" not in item for item in matches)
assert not any(event.get("key_code") == "f18" for item in manipulators
               if not from_key(item, "left_command") for event in item.get("to_if_alone", []))


def gated_on(item, *names):
    return {condition["name"] for condition in item.get("conditions", [])
            if condition["type"] == "variable_if" and condition["value"] == 1} == set(names)


def sets(item, name, value, field="to"):
    return any(event.get("set_variable") == {"name": name, "value": value} for event in item.get(field, []))


def chord(item):
    event = item["to"][0]
    return event.get("key_code"), sorted(event.get("modifiers", []))


toggles = [item for item in manipulators if from_key(item, "spacebar")
           and item["from"].get("modifiers", {}).get("mandatory") == ["left_control"]]
assert any(sets(item, "nav_mode", 1) and not gated_on(item, "nav_mode") for item in toggles)
assert any(sets(item, "nav_mode", 0) and sets(item, "nav_select", 0) and gated_on(item, "nav_mode") for item in toggles)
assert any(from_key(item, "escape") and sets(item, "nav_mode", 0) and gated_on(item, "nav_mode") for item in manipulators)

nav = [item for item in manipulators if gated_on(item, "nav_mode")]
select = [item for item in manipulators if gated_on(item, "nav_mode", "nav_select")]
for key, plain in (("w", ("up_arrow", [])), ("a", ("left_arrow", [])), ("e", ("right_arrow", ["left_option"])),
                   ("1", ("left_arrow", ["left_command"])), ("t", ("page_up", [])),
                   ("g", ("page_down", []))):
    assert any(from_key(item, key) and chord(item) == plain for item in nav), key
    assert any(from_key(item, key) and chord(item) == (plain[0], sorted(plain[1] + ["left_shift"]))
               for item in select), key
for key, plain in (("v", ("v", ["left_command"])), ("f", ("delete_or_backspace", [])), ("r", ("tab", []))):
    assert any(from_key(item, key) and chord(item) == plain for item in nav), key
assert not any(from_key(item, "b") for item in nav + select), "b has no nav binding (no forward delete)"
for item in nav + select:
    allowed = set(item["from"].get("modifiers", {}).get("optional", []))
    assert allowed <= {"shift", "option"} or item["from"]["key_code"] in ("caps_lock", "left_command"), item["from"]
assert any(from_key(item, "left_shift") and sets(item, "nav_select", 1, "to_if_alone") for item in nav)
assert any(from_key(item, "left_shift") and sets(item, "nav_select", 0, "to_if_alone") for item in select)
assert any(from_key(item, "x") and chord(item) == ("x", ["left_command"]) and sets(item, "nav_select", 0)
           for item in select)
copies = [item for item in manipulators if from_key(item, "c") and "nav_mode" in str(item.get("conditions"))]
assert copies and all(chord(item) == ("c", ["left_command"]) and sets(item, "nav_mode", 0)
                      and sets(item, "nav_select", 0) and gated_on(item, "nav_mode") for item in copies)
assert not any(event.get("key_code") == "vk_none" for item in nav + select for event in item["to"])
first_select = manipulators.index(select[0])
assert first_select < manipulators.index(next(item for item in nav if from_key(item, "w"))), \
    "select-mode rules must precede the plain nav layer"

leader = [item for item in manipulators if from_key(item, "left_command") and gated_on(item, "nav_mode")]
assert any(sets(item, "nav_mode", 0, "to_if_alone") and item["to_if_alone"][-1].get("key_code") == "f18"
           for item in leader), "a leader tap inside the layer must leave it before opening combo mode"
assert manipulators.index(leader[0]) < next(i for i, item in enumerate(manipulators)
                                            if from_key(item, "left_command") and "conditions" not in item)
for item in nav + select:
    if from_key(item, "left_shift"):
        assert item["parameters"]["basic.to_if_alone_timeout_milliseconds"] == 200
for key in ("x", "v", "f"):
    assert any(from_key(item, key) and sets(item, "nav_select", 0) for item in select), key


def nocfree_scoped(item):
    return any(condition.get("type") == "device_if" and {
        (identifier.get("vendor_id"), identifier.get("product_id")) for identifier in condition.get("identifiers", [])
    } == {(19269, 13877), (19269, 13876)} for condition in item.get("conditions", []))


# The NocFree's firmware layer 1 taps F20 for select mode; Karabiner owns that state.
assert any(from_key(item, "f20") and sets(item, "fw_select", 1) and nocfree_scoped(item)
           and not gated_on(item, "fw_select") for item in manipulators)
fw_select = [item for item in manipulators if gated_on(item, "fw_select")]
assert fw_select and all(nocfree_scoped(item) for item in fw_select)
for key in ("up_arrow", "left_arrow", "page_down"):
    assert any(from_key(item, key) and chord(item) == (key, ["left_shift"]) for item in fw_select), key
assert any(from_key(item, "left_arrow") and {"option", "command"} <= set(item["from"]["modifiers"]["optional"])
           for item in fw_select), "firmware word and line moves must keep their ⌥/⌘ in select mode"
for key in ("x", "v", "delete_or_backspace", "escape", "f20"):
    assert any(from_key(item, key) and sets(item, "fw_select", 0) for item in fw_select), key

sheets = [item for item in nav if from_key(item, "grave_accent_and_tilde")]
assert len(sheets) == 2 and nocfree_scoped(sheets[0]) and "nav-layer-nocfree.svg" in sheets[0]["to"][0]["shell_command"]
assert not nocfree_scoped(sheets[1]) and "nav-layer.svg" in sheets[1]["to"][0]["shell_command"]
