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
[[ -e home/dot_agents/packages/experimental/skills/vendor/cli-creator/SOURCE.md ]]
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
# hooks are vendored as a package payload, so a plugin dependency that ships
# them (in apm's .apm/ normalization or at its root) passes the audit.
mkdir -p "$tmp_root/source-audit-hooks/example/plugin/.apm/hooks" \
  "$tmp_root/source-audit-hooks/example/plugin/hooks"
.agents/skills/agent-skill-management/scripts/audit-apm-source-surface \
  "$tmp_root/source-audit-hooks"

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
    - Example/Repo/skills/fake-skill
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

- Upstream: https://github.com/Example/Repo/tree/old/skills/fake-skill
- APM dependency: `Example/Repo/skills/fake-skill`
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

chezmoi_prefix_package="$packages_root/chezmoi-prefix"
mkdir -p "$chezmoi_prefix_package/skills/local/chezmoi-prefix-skill"
cat >"$chezmoi_prefix_package/package.toml" <<'TOML'
display_name = "Chezmoi Prefix"

[render]
codex = "none"
claude = "none"
TOML
cat >"$chezmoi_prefix_package/apm.yml" <<'YAML'
name: chezmoi-prefix
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
cat >"$chezmoi_prefix_package/skills/local/chezmoi-prefix-skill/SKILL.md" <<'SKILL'
---
name: chezmoi-prefix-skill
description: Local skill for chezmoi attribute prefix validation tests.
---

# Chezmoi Prefix Skill
SKILL
echo '{}' >"$chezmoi_prefix_package/skills/local/chezmoi-prefix-skill/run_manifest.json"
if AGENT_SKILL_PACKAGES_ROOT="$packages_root" \
  .agents/skills/agent-skill-management/scripts/validate-agent-packages \
  >"$tmp_root/chezmoi-prefix.out" 2>&1; then
  echo "expected validate-agent-packages to reject chezmoi attribute-prefixed filenames" >&2
  exit 1
fi
grep -q 'rename with a literal_ prefix' "$tmp_root/chezmoi-prefix.out"
rm -rf "$chezmoi_prefix_package"

hooks_missing_package="$packages_root/hooks-missing"
mkdir -p "$hooks_missing_package/skills/local/hooks-missing-skill" "$hooks_missing_package/hooks"
cat >"$hooks_missing_package/package.toml" <<'TOML'
display_name = "Hooks Missing"

[render]
codex = "none"
claude = "none"
TOML
cat >"$hooks_missing_package/apm.yml" <<'YAML'
name: hooks-missing
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
cat >"$hooks_missing_package/skills/local/hooks-missing-skill/SKILL.md" <<'SKILL'
---
name: hooks-missing-skill
description: Local skill for hooks payload validation tests.
---

# Hooks Missing Skill
SKILL
: >"$hooks_missing_package/hooks/session-start"
if AGENT_SKILL_PACKAGES_ROOT="$packages_root" \
  .agents/skills/agent-skill-management/scripts/validate-agent-packages \
  >"$tmp_root/hooks-missing.out" 2>&1; then
  echo "expected validate-agent-packages to reject a hooks payload without hooks.json" >&2
  exit 1
fi
grep -q 'hooks payload is missing hooks.json' "$tmp_root/hooks-missing.out"
rm -rf "$hooks_missing_package"

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
  mkdir -p .agents/skills/plugin-skill apm_modules/example/plugin/.apm/hooks
  cat >.agents/skills/plugin-skill/SKILL.md <<'SKILL'
---
name: plugin-skill
description: Skill shipped by a marketplace plugin that also carries hooks.
---

# Plugin Skill
SKILL
  cat >apm_modules/example/plugin/.apm/hooks/hooks.json <<'JSON'
{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\""}]}]}}
JSON
  printf '#!/usr/bin/env bash\necho hi\n' >apm_modules/example/plugin/.apm/hooks/session-start
  chmod +x apm_modules/example/plugin/.apm/hooks/session-start
  if [[ "${FAKE_APM_HOOKS:-}" == "conflict" ]]; then
    mkdir -p apm_modules/example/repo/skills/fake-skill/.apm/hooks
    echo '{"hooks": {}}' >apm_modules/example/repo/skills/fake-skill/.apm/hooks/hooks.json
  fi
  cat >apm.lock.yaml <<'YAML'
lockfile_version: '1'
generated_at: '2026-05-12T00:00:00+00:00'
apm_version: 0.28.0
dependencies:
- repo_url: example/repo
  materialization_repo_url: Example/Repo
  name: fake-skill
  host: github.com
  resolved_commit: abc123
  version: unknown
  virtual_path: skills/fake-skill
  is_virtual: true
  package_type: claude_skill
  deployed_files:
  - .agents/skills/fake-skill
  - .agents/skills/fake-skill/SKILL.md
  - .agents/skills/fake-skill/agents/openai.yaml
  - .agents/skills/second-skill
  - .agents/skills/second-skill/SKILL.md
  deployed_file_hashes:
    .agents/skills/fake-skill/SKILL.md: sha256:aaa
    .agents/skills/second-skill/SKILL.md: sha256:bbb
  content_hash: sha256:test
- repo_url: example/plugin
  materialization_repo_url: Example/Plugin
  name: plugin
  host: github.com
  resolved_commit: def456
  version: 1.0.0
  package_type: marketplace_plugin
  deployed_files:
  - .agents/skills/plugin-skill
  - .agents/skills/plugin-skill/SKILL.md
  deployed_file_hashes:
    .agents/skills/plugin-skill/SKILL.md: sha256:ccc
  content_hash: sha256:plugin
deployments:
- kind: project-relative
  target: agent-skills
  value: .agents/skills/fake-skill
  runtime: null
  scope: project
  owners:
  - Example/Repo/skills/fake-skill
  active_owner: Example/Repo/skills/fake-skill
  content_hash: null
YAML
  exit 0
fi

if [[ "$1" == "audit" ]]; then
  if [[ "${FAKE_APM_AUDIT_FAIL:-}" == "other" ]]; then
    cat <<'JSON'
{"checks": [{"name": "hidden-unicode", "passed": false, "message": "hidden character found", "details": ["U+200B in SKILL.md"]}], "summary": {"total": 1, "passed": 0, "failed": 1}}
JSON
    exit 1
  fi
  cat <<'JSON'
{"checks": [{"name": "config-consistency", "passed": false, "message": "1 MCP config inconsistenc(ies) -- run 'apm install' to reconcile", "details": ["Example/Repo: package manifest not found at /tmp/x/apm_modules/Example/Repo/apm.yml; re-run 'apm install' to restore it"]}, {"name": "drift", "passed": true, "message": "no drift detected against lockfile", "details": []}], "summary": {"total": 2, "passed": 1, "failed": 1}}
JSON
  exit 1
fi

echo "unexpected fake apm invocation: $*" >&2
exit 1
SH
chmod +x "$fake_bin/apm"

mkdir -p "$sample_package/hooks"
echo '{"hooks": {}}' >"$sample_package/hooks/hooks.json"
if PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  sample \
  --packages-root "$packages_root" >"$tmp_root/hooks-handmade.out" 2>&1; then
  echo "expected vendor-agent-package to refuse overwriting a hand-authored hooks/ payload" >&2
  exit 1
fi
grep -q 'not APM-vendored' "$tmp_root/hooks-handmade.out"
# The refusal happens before any skill tree is replaced.
[[ -e "$sample_package/skills/vendor/stale-skill/SKILL.md" ]]
[[ ! -e "$sample_package/skills/vendor/second-skill" ]]
rm -rf "$sample_package/hooks"

PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  sample \
  --packages-root "$packages_root"
[[ -e "$sample_package/skills/vendor/curated-fake/SKILL.md" ]]
[[ -e "$sample_package/skills/vendor/plugin-skill/SKILL.md" ]]
[[ -f "$sample_package/hooks/hooks.json" ]]
[[ -x "$sample_package/hooks/session-start" ]]
grep -q 'APM dependency: `Example/Plugin`' "$sample_package/hooks/SOURCE.md"
grep -q 'Ref: `def456`' "$sample_package/hooks/SOURCE.md"
[[ -e "$sample_package/skills/vendor/curated-fake/agents/openai.yaml" ]]
[[ -e "$sample_package/skills/vendor/second-skill/SKILL.md" ]]
[[ ! -e "$sample_package/skills/vendor/fake-skill" ]]
[[ ! -e "$sample_package/skills/vendor/stale-skill" ]]
grep -q 'Ref: `abc123`' "$sample_package/skills/vendor/curated-fake/SOURCE.md"
grep -q 'APM dependency: `Example/Repo/skills/fake-skill`' \
  "$sample_package/skills/vendor/curated-fake/SOURCE.md"
grep -q 'Upstream: https://github.com/Example/Repo/tree/abc123/skills/fake-skill' \
  "$sample_package/skills/vendor/curated-fake/SOURCE.md"
grep -q 'local skill id `curated-fake`' \
  "$sample_package/skills/vendor/curated-fake/SOURCE.md"
[[ -e "$sample_package/apm.lock.yaml" ]]

if FAKE_APM_AUDIT_FAIL=other PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  sample \
  --packages-root "$packages_root" >"$tmp_root/audit-fail.out" 2>&1; then
  echo "expected vendor-agent-package to fail on non-manifest audit findings" >&2
  exit 1
fi

if FAKE_APM_HOOKS=conflict PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  sample \
  --packages-root "$packages_root" >"$tmp_root/hooks-conflict.out" 2>&1; then
  echo "expected vendor-agent-package to reject two dependencies shipping hooks" >&2
  exit 1
fi
grep -q 'multiple dependencies ship hooks/' "$tmp_root/hooks-conflict.out"

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
mkdir -p "$empty_package/hooks"
echo '{"hooks": {}}' >"$empty_package/hooks/hooks.json"
cp "$empty_package/skills/vendor/old-skill/SOURCE.md" "$empty_package/hooks/SOURCE.md"
PATH="$fake_bin:$PATH" \
  .agents/skills/agent-skill-management/scripts/vendor-agent-package \
  empty \
  --packages-root "$packages_root"
[[ ! -e "$empty_package/skills/vendor/old-skill" ]]
[[ ! -e "$empty_package/hooks" ]]
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
[[ -x "$plugins_root/plugins/superpowers/hooks/run-hook.cmd" ]]

hooked_root="$tmp_root/hooked-packages"
hooked_package="$hooked_root/hooked"
mkdir -p "$hooked_package/skills/local/hooked-skill" "$hooked_package/hooks" "$hooked_package/commands"
cat >"$hooked_package/package.toml" <<'TOML'
display_name = "Hooked"

[render]
codex = "plugin"
claude = "plugin"
TOML
cat >"$hooked_package/apm.yml" <<'YAML'
name: hooked
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
cat >"$hooked_package/skills/local/hooked-skill/SKILL.md" <<'SKILL'
---
name: hooked-skill
description: Local skill for payload rendering tests.
---

# Hooked Skill
SKILL
echo '{"hooks": {"SessionStart": []}}' >"$hooked_package/hooks/hooks.json"
printf '#!/usr/bin/env bash\necho hi\n' >"$hooked_package/hooks/session-start"
chmod +x "$hooked_package/hooks/session-start"
: >"$hooked_package/commands/hello.md"
hooked_plugins="$tmp_root/hooked-plugins"
AGENT_SKILL_PACKAGES_ROOT="$hooked_root" \
  .agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$hooked_plugins" \
  --skip-config-templates 2>"$tmp_root/hooked.err"
[[ -f "$hooked_plugins/plugins/hooked/hooks/hooks.json" ]]
[[ -x "$hooked_plugins/plugins/hooked/hooks/session-start" ]]
[[ -f "$hooked_plugins/plugins/hooked/commands/hello.md" ]]
grep -q 'codex has no mapping for hooks' "$tmp_root/hooked.err"
grep -q 'codex has no mapping for commands' "$tmp_root/hooked.err"
python3 - "$hooked_plugins/plugins/hooked" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
claude = json.loads((root / ".claude-plugin/plugin.json").read_text())
# Claude loads hooks/hooks.json itself and rejects a manifest entry that
# repeats it as a duplicate.
assert "hooks" not in claude, claude
codex = json.loads((root / ".codex-plugin/plugin.json").read_text())
# Exactly {} suppresses Codex's hooks/hooks.json auto-discovery.
assert codex["hooks"] == {}, codex
PY
AGENT_SKILL_PACKAGES_ROOT="$hooked_root" \
  .agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$hooked_plugins" \
  --skip-config-templates
chmod -x "$hooked_plugins/plugins/hooked/hooks/session-start"
if AGENT_SKILL_PACKAGES_ROOT="$hooked_root" \
  .agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$hooked_plugins" \
  --skip-config-templates >"$tmp_root/hooked-mode.out" 2>&1; then
  echo "expected --check to report a mode-only change on a hook script as drift" >&2
  exit 1
fi
grep -q 'changed plugins/hooked/hooks/session-start' "$tmp_root/hooked-mode.out"

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

reconcile_output="$(
  .agents/skills/agent-skill-management/scripts/reconcile-agent-plugins
)"
# The reconciler derives every line from package.toml: Codex cache refreshes
# only for default-loaded Codex plugins (codex plugin add also enables), and a
# Claude install plus enable/disable per render policy. Expected commands come
# from the same manifests so the test pins the emission rules, not today's set
# of default-loaded packages.
python3 - "$reconcile_output" <<'PY'
import pathlib, sys, tomllib

commands = sys.argv[1].splitlines()
packages = {
    path.parent.name: tomllib.loads(path.read_text())
    for path in sorted(pathlib.Path("home/dot_agents/packages").glob("*/package.toml"))
}


def loaded(data):
    return data.get("default_loaded", True)


def renders(data, agent):
    return data.get("render", {}).get(agent) == "plugin"


expected_commands = [
    "claude plugin marketplace add ~/.agents/plugins --scope user",
    "claude plugin marketplace update prateek-local",
    *[f"codex plugin add {name}@prateek-local" for name, data in packages.items() if renders(data, "codex") and loaded(data)],
]
for name, data in packages.items():
    if renders(data, "claude"):
        toggle = "enable" if loaded(data) else "disable"
        expected_commands += [
            f"claude plugin install {name}@prateek-local --scope user",
            f"claude plugin {toggle} {name}@prateek-local --scope user",
        ]
assert len(expected_commands) > 2 and any(" disable " in c for c in expected_commands), expected_commands
assert commands == expected_commands, commands
PY

chezmoi --source home execute-template \
  --file home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl \
  | python3 -m json.tool >/dev/null

# --apply converges each CLI's install records through the CLI itself. Fake
# claude/codex binaries keep state in a JSON file and log every invocation so
# the test can pin the mutating command sequence and its idempotence. The
# initial state registers prateek-local at a stale path, so the first run
# must re-add it at the real plugins root.
reconcile_root="$tmp_root/reconcile-packages"
mkdir -p "$reconcile_root/on/skills/local/on-skill" "$reconcile_root/off/skills/local/off-skill"
cat >"$reconcile_root/on/package.toml" <<'TOML'
display_name = "On"

[render]
codex = "plugin"
claude = "plugin"
TOML
cat >"$reconcile_root/off/package.toml" <<'TOML'
display_name = "Off"
default_loaded = false

[render]
codex = "none"
claude = "plugin"
TOML
for name in on off; do
  cat >"$reconcile_root/$name/apm.yml" <<YAML
name: $name
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
YAML
  cat >"$reconcile_root/$name/skills/local/$name-skill/SKILL.md" <<SKILL
---
name: $name-skill
description: Local skill for plugin reconcile tests.
---

# $name skill
SKILL
done
fake_state="$tmp_root/fake-plugin-state.json"
fake_log="$tmp_root/fake-plugin-log"
cat >"$fake_state" <<'JSON'
{"marketplaces": {"prateek-local": "/tmp/stale-plugins-root"}, "claude": {"on@prateek-local": false, "stale@prateek-local": true, "other@other-mkt": true}, "codex": ["on@prateek-local", "stale@prateek-local"]}
JSON
cat >"$fake_bin/fake-plugin-cli.py" <<'PY'
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
PY
for cli in claude codex; do
  printf '#!/usr/bin/env bash\nFAKE_PLUGIN_CLI=%s exec python3 "%s/fake-plugin-cli.py" "$@"\n' "$cli" "$fake_bin" >"$fake_bin/$cli"
  chmod +x "$fake_bin/$cli"
done
reconcile_apply() {
  AGENT_SKILL_PACKAGES_ROOT="$reconcile_root" FAKE_PLUGIN_STATE="$fake_state" FAKE_PLUGIN_LOG="$fake_log" \
    PATH="$fake_bin:$PATH" \
    .agents/skills/agent-skill-management/scripts/reconcile-agent-plugins \
    --apply --agent claude --agent codex --plugins-root "$tmp_root/plugins-root" "$@"
}
: >"$fake_log"
reconcile_apply >"$tmp_root/reconcile-apply.out"
python3 - "$fake_log" "$fake_state" "$tmp_root/plugins-root" <<'PY'
import json, sys
log = [line for line in open(sys.argv[1]).read().splitlines() if " list " not in line]
plugins_root = sys.argv[3]
assert log == [
    f"claude plugin marketplace add {plugins_root} --scope user",
    "claude plugin install off@prateek-local --scope user",
    "claude plugin disable off@prateek-local --scope user",
    "claude plugin enable on@prateek-local --scope user",
    "claude plugin uninstall stale@prateek-local --scope user",
    "codex plugin add on@prateek-local",
    "codex plugin remove stale@prateek-local",
], log
state = json.load(open(sys.argv[2]))
# Other marketplaces' plugins are never touched; policy matches default_loaded.
assert state["claude"] == {"on@prateek-local": True, "other@other-mkt": True, "off@prateek-local": False}, state
assert state["codex"] == ["on@prateek-local"], state
PY
# Converged state: nothing runs except the Codex cache refresh.
: >"$fake_log"
reconcile_apply >/dev/null
python3 - "$fake_log" <<'PY'
import sys
log = [line for line in open(sys.argv[1]).read().splitlines() if " list " not in line]
assert log == ["codex plugin add on@prateek-local"], log
PY
# --dry-run reads state but only prints what would change.
python3 - "$fake_state" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))
state["claude"]["on@prateek-local"] = False
json.dump(state, open(sys.argv[1], "w"))
PY
: >"$fake_log"
reconcile_apply --dry-run >"$tmp_root/reconcile-dry.out"
grep -q '^\[dry-run\] claude plugin enable on@prateek-local --scope user$' "$tmp_root/reconcile-dry.out"
grep -q '^\[dry-run\] codex plugin add on@prateek-local$' "$tmp_root/reconcile-dry.out"
[[ -z "$(grep -v ' list ' "$fake_log")" ]]
python3 - "$fake_state" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))
assert state["claude"]["on@prateek-local"] is False, state
state["claude"]["on@prateek-local"] = True
json.dump(state, open(sys.argv[1], "w"))
PY
: >"$fake_log"
reconcile_apply >/dev/null
python3 - "$fake_log" <<'PY'
import sys
log = [line for line in open(sys.argv[1]).read().splitlines() if " list " not in line]
assert log == ["codex plugin add on@prateek-local"], log
PY
# A CLI failure stops the run and names the command.
python3 - "$fake_state" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))
del state["claude"]["off@prateek-local"]
json.dump(state, open(sys.argv[1], "w"))
PY
if FAKE_PLUGIN_FAIL=install reconcile_apply >"$tmp_root/reconcile-fail.out" 2>&1; then
  echo "expected reconcile-agent-plugins --apply to fail when a CLI command fails" >&2
  exit 1
fi
grep -q 'claude plugin install off@prateek-local --scope user failed' "$tmp_root/reconcile-fail.out"
grep -q 'simulated install failure' "$tmp_root/reconcile-fail.out"

# default_loaded in package.toml must propagate to every rendered settings
# template as `false` / `enabled = false`. Expected values come from the
# package manifests themselves, so this catches a regression in any renderer
# emitter independently of the --check baseline without pinning which
# packages are default-loaded.
python3 - <<'PY'
import json, pathlib, subprocess, tomllib
expected = {
    f"{path.parent.name}@prateek-local": tomllib.loads(path.read_text()).get("default_loaded", True)
    for path in sorted(pathlib.Path("home/dot_agents/packages").glob("*/package.toml"))
}
assert expected and any(expected.values()) and not all(expected.values()), expected
claude_json = subprocess.check_output([
    "chezmoi", "--source", "home", "execute-template",
    "--file", "home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl",
])
claude = json.loads(claude_json)["enabledPlugins"]
assert {k: claude[k] for k in expected} == expected, claude

codex_text = open("home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl").read()
codex = tomllib.loads(codex_text)["plugins"]
assert {k: codex[k]["enabled"] for k in expected} == expected, codex

pi_json = subprocess.check_output([
    "chezmoi", "--source", "home", "execute-template",
    "--file", "home/dot_pi/agent/claude-plugins.json.tmpl",
])
pi = json.loads(pi_json)["plugins"]
assert {k: pi[k]["enabled"] for k in expected} == expected, pi
PY

# inventory-agent-skills must surface default_loaded so audit tooling sees it.
.agents/skills/agent-skill-management/scripts/inventory-agent-skills \
  | python3 -c '
import json, sys
for p in json.load(sys.stdin)["packages"]:
    assert "default_loaded" in p, p
    assert isinstance(p["default_loaded"], bool), p
    assert isinstance(p["payloads"], list), p
'

[[ "$(cat home/dot_codex/symlink_skills)" == "../.agents/skills" ]]
