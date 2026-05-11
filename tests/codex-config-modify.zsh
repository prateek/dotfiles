#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

script="$tmp_root/modify_codex_config.py"
current="$tmp_root/current.toml"
merged="$tmp_root/merged.toml"
semantic_current="$tmp_root/semantic-current.toml"
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

[projects."/tmp/live-project"]
trust_level = "trusted"

[marketplaces.last30days-skill]
last_updated = "live"
last_revision = "live-revision"
source_type = "git"
source = "https://example.invalid/skill.git"

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
assert data["projects"]["/tmp/live-project"]["trust_level"] == "trusted"
assert data["marketplaces"]["last30days-skill"]["last_updated"] == "live"
assert data["hooks"]["state"]["/Users/prateek/.codex/hooks.json:pre_tool_use:0:0"]["trusted_hash"] == "sha256:live"
PY

cat >"$semantic_current" <<'TOML'
model = "gpt-5.5"
model_reasoning_effort = "xhigh"
plan_mode_reasoning_effort = "xhigh"
service_tier = "fast"
custom_top_level = "keep"

[projects."/tmp/live-project"]
trust_level = "trusted"

[marketplaces.last30days-skill]
last_updated = "live"
last_revision = "live-revision"
source_type = "git"
source = "https://example.invalid/skill.git"

[hooks.state]

[hooks.state."/Users/prateek/.codex/hooks.json:pre_tool_use:0:0"]
enabled = false
trusted_hash = "sha256:live"

[agents]
max_threads = 16
max_depth = 3

[mcp_servers.granola]
enabled = false
url = "https://mcp.granola.ai/mcp"

[features]
hooks = true
multi_agent = true
memories = true
apps = false

[plugins."last30days@last30days-skill"]
enabled = true

[tui]
status_line = ["thread-title", "model-with-reasoning", "context-used", "five-hour-limit", "weekly-limit", "context-window-size", "current-dir"]
TOML

"$script" <"$semantic_current" >"$semantic_merged"

cmp -s "$semantic_current" "$semantic_merged"
