#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

cd "$REPO_ROOT"

.agents/skills/agent-skill-management/scripts/inventory-agent-skills \
  | python3 -m json.tool >/dev/null
.agents/skills/agent-skill-management/scripts/validate-agent-packages
[[ ! -e home/dot_agents/skills ]]
[[ ! -e home/dot_claude/skills ]]
[[ ! -e home/dot_agents/plugins ]]
[[ -e home/dot_agents/packages/core/skills/vendor/deep-research/SOURCE.md ]]
[[ -e home/dot_agents/packages/review/skills/vendor/crit/SOURCE.md ]]
[[ -e home/dot_agents/packages/utils-agent/skills/vendor/cli-creator/SOURCE.md ]]
[[ ! -e home/dot_agents/packages/core/skills/local/deep-research ]]
[[ ! -e home/dot_agents/packages/ios/skills/vendor/swift-patterns/swift-patterns/SKILL.md ]]
[[ ! -e home/dot_agents/packages/ios/skills/vendor/swiftui-expert/swiftui-expert-skill/SKILL.md ]]

.agents/skills/agent-skill-management/scripts/audit-apm-source-surface \
  home/dot_agents/packages/core/skills/local/code-gardening
mkdir -p "$tmp_root/source-audit/prompts"
if .agents/skills/agent-skill-management/scripts/audit-apm-source-surface \
  "$tmp_root/source-audit" >"$tmp_root/source-audit.out" 2>&1; then
  echo "expected audit-apm-source-surface to reject unsupported component roots" >&2
  exit 1
fi
grep -q 'unsupported APM component' "$tmp_root/source-audit.out"

packages_root="$tmp_root/packages"
sample_package="$packages_root/sample"
fake_bin="$tmp_root/bin"
mkdir -p "$sample_package" "$fake_bin"
cat >"$sample_package/package.toml" <<'TOML'
display_name = "Sample"

[render]
codex = "none"
claude = "none"
TOML
cat >"$sample_package/apm.yml" <<'YAML'
name: sample
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm:
    - example/repo/skills/fake-skill
YAML
mkdir -p "$sample_package/skills/vendor/curated-fake" "$sample_package/skills/vendor/stale-skill"
cat >"$sample_package/skills/vendor/curated-fake/SKILL.md" <<'SKILL'
---
name: fake-skill
description: Existing curated fake skill.
---

# Curated Fake Skill
SKILL
cat >"$sample_package/skills/vendor/curated-fake/SOURCE.md" <<'MD'
# Source

- Upstream: https://github.com/example/repo/tree/old/skills/fake-skill
- APM dependency: `example/repo/skills/fake-skill`
- Ref: `old`
- License: MIT.
- Notes: Vendored source is kept under the local skill id `curated-fake`.
MD
cat >"$sample_package/skills/vendor/stale-skill/SKILL.md" <<'SKILL'
---
name: stale-skill
description: Stale skill from a removed dependency.
---

# Stale Skill
SKILL
cat >"$sample_package/skills/vendor/stale-skill/SOURCE.md" <<'MD'
# Source

- Upstream: https://github.com/example/old/tree/old/skills/stale-skill
- APM dependency: `example/old/skills/stale-skill`
- Ref: `old`
- License: MIT.
- Notes: Should be removed when APM no longer deploys it.
MD

invalid_pin_package="$packages_root/invalid-pin"
mkdir -p "$invalid_pin_package/skills/local/invalid-pin-skill"
cat >"$invalid_pin_package/package.toml" <<'TOML'
display_name = "Invalid Pin"

[render]
codex = "none"
claude = "none"
TOML
cat >"$invalid_pin_package/apm.yml" <<'YAML'
name: invalid-pin
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm:
    - example/repo/skills/invalid#main
YAML
cat >"$invalid_pin_package/apm.lock.yaml" <<'YAML'
lockfile_version: '1'
dependencies: []
YAML
cat >"$invalid_pin_package/skills/local/invalid-pin-skill/SKILL.md" <<'SKILL'
---
name: invalid-pin-skill
description: Local skill for invalid pin validation tests.
---

# Invalid Pin Skill
SKILL
if AGENT_SKILL_PACKAGES_ROOT="$packages_root" \
  .agents/skills/agent-skill-management/scripts/validate-agent-packages \
  >"$tmp_root/invalid-pin.out" 2>&1; then
  echo "expected validate-agent-packages to reject non-SHA APM ref pins" >&2
  exit 1
fi
grep -q 'dependency ref pins must be full commit SHAs' "$tmp_root/invalid-pin.out"
rm -rf "$invalid_pin_package"

long_description_package="$packages_root/long-description"
mkdir -p "$long_description_package/skills/local/long-description-skill"
cat >"$long_description_package/package.toml" <<'TOML'
display_name = "Long Description"

[render]
codex = "none"
claude = "none"
TOML
cat >"$long_description_package/apm.yml" <<'YAML'
name: long-description
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
long_description="$(printf '%*s' 1100 '' | tr ' ' x)"
{
  print -- '---'
  print -- 'name: long-description-skill'
  print -- 'description: >-'
  print -- "  $long_description"
  print -- '---'
  print -- ''
  print -- '# Long Description Skill'
} >"$long_description_package/skills/local/long-description-skill/SKILL.md"
if AGENT_SKILL_PACKAGES_ROOT="$packages_root" \
  .agents/skills/agent-skill-management/scripts/validate-agent-packages \
  >"$tmp_root/long-description.out" 2>&1; then
  echo "expected validate-agent-packages to reject long skill descriptions" >&2
  exit 1
fi
grep -q 'description exceeds 1024 chars' "$tmp_root/long-description.out"
rm -rf "$long_description_package"

cat >"$fake_bin/apm" <<'SH'
#!/usr/bin/env zsh
set -euo pipefail

if [[ "$1" == "install" ]]; then
  if [[ " $* " == *" --dry-run "* ]]; then
    exit 0
  fi
  if grep -q 'apm: \[\]' apm.yml; then
    rm -f apm.lock.yaml
    exit 0
  fi
  mkdir -p .agents/skills/fake-skill/agents
  mkdir -p .agents/skills/second-skill
  cat >.agents/skills/fake-skill/SKILL.md <<'SKILL'
---
name: fake-skill
description: Fake skill for vendoring tests.
---

# Fake Skill
SKILL
  cat >.agents/skills/second-skill/SKILL.md <<'SKILL'
---
name: second-skill
description: Second fake skill from the same dependency.
---

# Second Skill
SKILL
  : >.agents/skills/fake-skill/agents/openai.yaml
  mkdir -p apm_modules/example/repo/skills/fake-skill
  cp -R .agents/skills/fake-skill/. apm_modules/example/repo/skills/fake-skill/
  cat >apm.lock.yaml <<'YAML'
lockfile_version: '1'
generated_at: '2026-05-12T00:00:00+00:00'
apm_version: 0.0.0-test
dependencies:
- repo_url: example/repo
  host: github.com
  resolved_commit: abc123
  virtual_path: skills/fake-skill
  is_virtual: true
  package_type: claude_skill
  deployed_files:
  - .agents/skills/fake-skill
  - .agents/skills/second-skill
  content_hash: sha256:test
YAML
  exit 0
fi

if [[ "$1" == "audit" ]]; then
  exit 0
fi

echo "unexpected fake apm invocation: $*" >&2
exit 1
SH
chmod +x "$fake_bin/apm"

PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  sample \
  --packages-root "$packages_root"
[[ -e "$sample_package/skills/vendor/curated-fake/SKILL.md" ]]
[[ -e "$sample_package/skills/vendor/curated-fake/agents/openai.yaml" ]]
[[ -e "$sample_package/skills/vendor/second-skill/SKILL.md" ]]
[[ ! -e "$sample_package/skills/vendor/fake-skill" ]]
[[ ! -e "$sample_package/skills/vendor/stale-skill" ]]
grep -q 'Ref: `abc123`' "$sample_package/skills/vendor/curated-fake/SOURCE.md"
grep -q 'APM dependency: `example/repo/skills/fake-skill`' \
  "$sample_package/skills/vendor/curated-fake/SOURCE.md"
grep -q 'local skill id `curated-fake`' \
  "$sample_package/skills/vendor/curated-fake/SOURCE.md"
[[ -e "$sample_package/apm.lock.yaml" ]]

empty_package="$packages_root/empty"
mkdir -p "$empty_package/skills/local/keep-skill" "$empty_package/skills/vendor/old-skill"
cat >"$empty_package/package.toml" <<'TOML'
display_name = "Empty"

[render]
codex = "none"
claude = "none"
TOML
cat >"$empty_package/apm.yml" <<'YAML'
name: empty
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
cat >"$empty_package/apm.lock.yaml" <<'YAML'
lockfile_version: '1'
dependencies: []
YAML
cat >"$empty_package/skills/local/keep-skill/SKILL.md" <<'SKILL'
---
name: keep-skill
description: Local skill that keeps the package valid after APM cleanup.
---

# Keep Skill
SKILL
cat >"$empty_package/skills/vendor/old-skill/SKILL.md" <<'SKILL'
---
name: old-skill
description: Old APM-managed skill.
---

# Old Skill
SKILL
cat >"$empty_package/skills/vendor/old-skill/SOURCE.md" <<'MD'
# Source

- Upstream: https://github.com/example/old/tree/old
- APM dependency: `example/old`
- Ref: `old`
- License: MIT.
- Notes: Should be removed when all APM dependencies are removed.
MD
PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  empty \
  --packages-root "$packages_root"
[[ ! -e "$empty_package/skills/vendor/old-skill" ]]
[[ ! -e "$empty_package/apm.lock.yaml" ]]

rendered_root="$tmp_root/rendered"
plugins_root="$rendered_root/.agents/plugins"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$plugins_root" \
  --skip-config-templates
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$plugins_root"
python3 - "$plugins_root" <<'PY'
import json
import pathlib
import sys

plugins_root = pathlib.Path(sys.argv[1])
codex = json.loads((plugins_root / "marketplace.json").read_text())
for plugin in codex["plugins"]:
    name = plugin["name"]
    assert plugin["source"] == {
        "source": "local",
        "path": f"./.agents/plugins/plugins/{name}",
    }

claude = json.loads((plugins_root / ".claude-plugin/marketplace.json").read_text())
for plugin in claude["plugins"]:
    name = plugin["name"]
    assert plugin["source"] == f"./plugins/{name}"
PY

# maintain-agent-skill-roots keeps Codex's writable stub (preserving .system/)
# and removes the retired Claude root only when it is our generated dir.
roots_home="$tmp_root/roots"
mkdir -p "$roots_home/.agents/skills/.system/runtime" \
  "$roots_home/.agents/skills/stale-core-skill" \
  "$roots_home/.claude/skills"
: >"$roots_home/.agents/skills/.system/runtime/SKILL.md"
: >"$roots_home/.agents/skills/stale-core-skill/SKILL.md"
: >"$roots_home/.claude/skills/README.generated.md"
.agents/skills/agent-skill-management/scripts/maintain-agent-skill-roots \
  --codex-root "$roots_home/.agents/skills" \
  --claude-root "$roots_home/.claude/skills"
[[ -e "$roots_home/.agents/skills/.system/runtime/SKILL.md" ]]
[[ ! -e "$roots_home/.agents/skills/stale-core-skill" ]]
[[ -e "$roots_home/.agents/skills/README.generated.md" ]]
[[ -e "$roots_home/.agents/skills/.gitignore" ]]
[[ ! -e "$roots_home/.claude/skills" ]]

mkdir -p "$roots_home/.claude/skills/hand-authored"
.agents/skills/agent-skill-management/scripts/maintain-agent-skill-roots \
  --codex-root "$roots_home/.agents/skills" \
  --claude-root "$roots_home/.claude/skills" \
  2>"$roots_home/maintain.err"
grep -q 'not a generated skill root' "$roots_home/maintain.err"
[[ -e "$roots_home/.claude/skills/hand-authored" ]]

.agents/skills/agent-skill-management/scripts/audit-skill-context \
  --agent codex "$plugins_root/plugins/core/skills" \
  | python3 -m json.tool >/dev/null
chezmoi --source home execute-template \
  --file home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl \
  | python3 -m json.tool >/dev/null

# default_loaded = false in package.toml must propagate to both rendered
# settings templates as `false` / `enabled = false`. This catches a regression
# in either renderer emitter independently of the --check baseline.
python3 - <<'PY'
import json, subprocess, tomllib
expected = {
    "core@prateek-local": True,
    "design@prateek-local": False,
    "experimental@prateek-local": False,
    "ios@prateek-local": False,
    "utils-human@prateek-local": False,
    "review@prateek-local": True,
    "utils-agent@prateek-local": True,
}
claude_json = subprocess.check_output([
    "chezmoi", "--source", "home", "execute-template",
    "--file", "home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl",
])
claude = json.loads(claude_json)["enabledPlugins"]
assert {k: claude[k] for k in expected} == expected, claude

codex_text = open("home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl").read()
codex = tomllib.loads(codex_text)["plugins"]
assert {k: codex[k]["enabled"] for k in expected} == expected, codex
PY

# inventory-agent-skills must surface default_loaded so audit tooling sees it.
.agents/skills/agent-skill-management/scripts/inventory-agent-skills \
  | python3 -c '
import json, sys
for p in json.load(sys.stdin)["packages"]:
    assert "default_loaded" in p, p
    assert isinstance(p["default_loaded"], bool), p
'

[[ "$(cat home/dot_codex/symlink_skills)" == "../.agents/skills" ]]
