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
