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
service_tier = "fast"
custom_top_level = "keep"

[agents]
max_threads = 1
max_depth = 1

[tui]
status_line = ["old"]

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

python3 - "$merged" <<'PY'
import sys
import tomllib

path = sys.argv[1]
data = tomllib.loads(open(path, "rb").read().decode())

assert data["model"] == "gpt-5.5"
assert data["model_reasoning_effort"] == "xhigh"
assert data["service_tier"] == "fast"
assert data["custom_top_level"] == "keep"
assert data["agents"]["max_threads"] == 16
assert data["agents"]["max_depth"] == 3
assert data["tui"]["status_line"] == [
    "thread-title",
    "model-with-reasoning",
    "context-used",
    "five-hour-limit",
    "weekly-limit",
    "context-window-size",
    "current-dir",
]
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
# Reflects default_loaded in each package.toml; flip the source there if
# this rotates.
assert data["plugins"]["design@prateek-local"]["enabled"] is False
assert data["plugins"]["experimental@prateek-local"]["enabled"] is False
assert data["plugins"]["ios@prateek-local"]["enabled"] is False
assert data["plugins"]["utils-human@prateek-local"]["enabled"] is False
assert data["plugins"]["review@prateek-local"]["enabled"] is True
assert data["plugins"]["utils-agent@prateek-local"]["enabled"] is True
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
python3 - "$empty_merged" <<'PY'
import sys
import tomllib

data = tomllib.loads(open(sys.argv[1], "rb").read().decode())
assert data["marketplaces"]["prateek-local"]["source_type"] == "local"
expected = {
    "design": False,
    "experimental": False,
    "ios": False,
    "utils-human": False,
    "review": True,
    "utils-agent": True,
}
for slug, want in expected.items():
    assert data["plugins"][f"{slug}@prateek-local"]["enabled"] is want, slug
PY

