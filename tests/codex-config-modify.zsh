#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

script="$tmp_root/modify_codex_config.py"
current="$tmp_root/current.toml"
merged="$tmp_root/merged.toml"
semantic_merged="$tmp_root/semantic-merged.toml"

chezmoi \
  --source "$REPO_ROOT/home" \
  execute-template \
  --file "$REPO_ROOT/home/dot_codex/modify_private_config.toml.tmpl" \
  >"$script"
chmod +x "$script"

cat >"$current" <<'TOML'
model = "old-model"
model_reasoning_effort = "max"
service_tier = "fast"
custom_top_level = "keep"

[agents]
max_threads = 1
max_depth = 1

[tui]
status_line = ["old"]
status_line_use_colors = false

[tui.keymap.pager]
page_down = "old"
close = "old"

[projects."/tmp/live-project"]
trust_level = "trusted"

[marketplaces.last30days-skill]
last_updated = "live"
last_revision = "live-revision"
source_type = "git"
source = "https://example.invalid/skill.git"

[marketplaces.prateek-local]
last_updated = "old"
source_type = "git"
source = "https://example.invalid/old.git"

[plugins."stale@prateek-local"]
enabled = false

[plugins."other@other-market"]
enabled = false

[hooks.state]

[hooks.state."/Users/prateek/.codex/hooks.json:pre_tool_use:0:0"]
enabled = false
trusted_hash = "sha256:live"
TOML

"$script" <"$current" >"$merged"

python3 - "$merged" "$REPO_ROOT/home/dot_agents/packages" <<'PY'
import sys
import tomllib

path = sys.argv[1]
data = tomllib.loads(open(path, "rb").read().decode())

assert data["model"] == "gpt-6-astra"
assert data["model_reasoning_effort"] == "xhigh"
assert data["service_tier"] == "default"
assert data["custom_top_level"] == "keep"
assert data["agents"]["max_threads"] == 16
assert data["agents"]["max_depth"] == 3
assert data["tui"]["status_line"] == [
    "model-with-reasoning",
    "context-used",
    "context-window-size",
    "five-hour-limit",
    "weekly-limit",
]
assert data["tui"]["status_line_use_colors"] is True
assert data["tui"]["keymap"]["pager"] == {
    "scroll_up": ["up", "k"],
    "scroll_down": ["down", "j"],
    "page_up": ["page-up", "shift-space", "ctrl-b"],
    "page_down": ["page-down", "space", "ctrl-f"],
    "half_page_up": "ctrl-u",
    "half_page_down": "ctrl-d",
    "jump_top": "home",
    "jump_bottom": "end",
    "close": ["q", "ctrl-c"],
    "close_transcript": "ctrl-t",
}
assert data["projects"]["/tmp/live-project"]["trust_level"] == "trusted"
assert data["marketplaces"]["last30days-skill"]["last_updated"] == "live"
import os
assert data["marketplaces"]["prateek-local"]["source_type"] == "local"
assert data["marketplaces"]["prateek-local"]["source"] == os.path.expanduser("~/.agents/plugins")
# Managed plugin tables reflect default_loaded in each package.toml.
import pathlib, tomllib
for manifest in sorted(pathlib.Path(sys.argv[2]).glob("*/package.toml")):
    package = tomllib.loads(manifest.read_text())
    if package.get("render", {}).get("codex") == "plugin":
        assert data["plugins"][f"{manifest.parent.name}@prateek-local"]["enabled"] is package.get("default_loaded", True), manifest.parent.name
# Stale @prateek-local tables persist as harmless cruft (no automatic cleanup).
assert data["plugins"]["stale@prateek-local"]["enabled"] is False
assert data["plugins"]["other@other-market"]["enabled"] is False
assert data["hooks"]["state"]["/Users/prateek/.codex/hooks.json:pre_tool_use:0:0"]["trusted_hash"] == "sha256:live"
PY

"$script" <"$merged" >"$semantic_merged"
cmp -s "$merged" "$semantic_merged"

# tomlkit comment preservation: comments next to non-managed keys/tables in
# the user's config must round-trip through the merge.
comment_input="$tmp_root/comment-input.toml"
comment_output="$tmp_root/comment-output.toml"
cat >"$comment_input" <<'TOML'
# user-authored top-of-file comment
custom_top_level = "keep"  # inline comment

[unrelated]
# explanatory comment for the unrelated section
note = "preserve"
TOML
"$script" <"$comment_input" >"$comment_output"
raw="$(cat "$comment_output")"
[[ "$raw" == *"# user-authored top-of-file comment"* ]] || { echo "missing top comment" >&2; exit 1; }
[[ "$raw" == *"# inline comment"* ]] || { echo "missing inline comment" >&2; exit 1; }
[[ "$raw" == *"# explanatory comment for the unrelated section"* ]] || { echo "missing section comment" >&2; exit 1; }

# Nested merge: a user-added sibling key inside a managed table survives.
# (Demonstrates deep-merge passes through what desired doesn't own.)
nested_input="$tmp_root/nested-input.toml"
nested_output="$tmp_root/nested-output.toml"
cat >"$nested_input" <<'TOML'
[marketplaces.prateek-local]
user_tag = "keep-me"
TOML
"$script" <"$nested_input" >"$nested_output"
python3 - "$nested_output" <<'PY'
import sys, tomllib, os
data = tomllib.loads(open(sys.argv[1], "rb").read().decode())
local = data["marketplaces"]["prateek-local"]
assert local["user_tag"] == "keep-me", local
assert local["source_type"] == "local", local
assert local["source"] == os.path.expanduser("~/.agents/plugins"), local
PY

# From-scratch: empty config in -> prateek-local marketplace and plugins seeded
# with their package.toml defaults.
empty_current="$tmp_root/empty-current.toml"
empty_merged="$tmp_root/empty-merged.toml"
: >"$empty_current"
"$script" <"$empty_current" >"$empty_merged"
python3 - "$empty_merged" "$REPO_ROOT/home/dot_agents/packages" <<'PY'
import sys
import tomllib

data = tomllib.loads(open(sys.argv[1], "rb").read().decode())
assert data["marketplaces"]["prateek-local"]["source_type"] == "local"
import pathlib, tomllib
for manifest in sorted(pathlib.Path(sys.argv[2]).glob("*/package.toml")):
    package = tomllib.loads(manifest.read_text())
    if package.get("render", {}).get("codex") == "plugin":
        assert data["plugins"][f"{manifest.parent.name}@prateek-local"]["enabled"] is package.get("default_loaded", True), manifest.parent.name
PY
