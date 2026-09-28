---
status: active
doc_type: research
owner: Prateek
created: 2026-09-28
updated: 2026-09-28
related:
  - ../references/agent-marketplace.md
  - ../../agent-marketplace/packages/pstack/publish.toml
  - ../../home/.chezmoidata/agent_plugins.toml
status_detail: "Measured against pstack 0.15.5 at ecc249f1 and native Claude/Codex clients; repeat when the upstream pin or client loading behavior changes."
---

# pstack Context Impact

## Result

The packaged pstack plugin adds no skill rows to either default agent context.
Two controls enforce that result:

- `default_loaded = false` disables the whole plugin for Claude and Codex.
- Every published skill has both `disable-model-invocation: true` and
  `policy.allow_implicit_invocation: false`.

The package-level default also keeps pstack's two custom agents out of Claude's
default tool surface. If an operator later enables the package, Claude's
human-only flag keeps the skill rows out of its model context. The corresponding
Codex sidecars deny implicit invocation, but this experiment did not capture an
enabled-state Codex prompt or listing, so it does not claim that Codex omits the
skill metadata in that state. It also does not assign a token cost to enabled
custom-agent metadata.

| State | Claude skill rows | Codex skill rows | Skill-metadata delta |
| --- | ---: | ---: | ---: |
| Repo default | 0 | 0 | 0 characters |
| Package enabled, human-only controls retained | 0 | Not measured | Codex delta not measured |
| Hypothetical implicit listing | 47 | 47 | 11,298 Claude-listing characters; 15,045 Codex-style characters |

The hypothetical listing is about 3,767 Claude tokens at the console's current
three-bytes-per-token estimate. The Codex-style listing is about 3,762 tokens at
four bytes per token. These are size estimates, not billed-token readings: no
model call was made, and Codex does not expose the exact prompt tokenizer through
the plugin CLI.

The Claude serializer projection is version-qualified. The console constants
were captured from Claude Code `2.1.258`, while the native install test used
`2.1.283`; the console warned about that hash mismatch. The default-disabled
native state and all 47 frontmatter controls were verified on the newer client,
but its exact enabled-listing serializer was not recaptured for this change.

## Inputs And Method

The APM lock pins [cursor/plugins pstack](https://github.com/cursor/plugins/tree/ecc249f1e306fc64ddf83c7bed16cacf7c2239db/pstack)
at commit `ecc249f1e306fc64ddf83c7bed16cacf7c2239db`, upstream version `0.15.5`.
The package publishes 47 skills, two custom agents, and the MIT license. Upstream
already marked 46 skills human-only. The local patch gives `setup-pstack` the
same flag, and overlays provide the matching Codex policy for all 47.

The comparison concatenated each built skill's name and description using the
Claude console's `- name: description` row format. The Codex comparison added
the file-path field used by the local available-skills listing. Both measurements
used the validated built artifact, not the acquisition cache. After building the
marketplace, reproduce the serialized inputs and size estimates from the
repository root with:

```sh
cd agent-marketplace
uv run --offline --frozen python3 - <<'PY'
from pathlib import Path

import yaml

root = Path("build/marketplace/plugins/pstack/skills")
rows = []
for skill_dir in sorted(root.iterdir()):
    skill_file = skill_dir / "SKILL.md"
    frontmatter = skill_file.read_text().split("---", 2)[1]
    metadata = yaml.safe_load(frontmatter)
    rows.append((skill_dir, metadata["name"], metadata["description"]))

claude = "\n".join(f"- {name}: {description}" for _, name, description in rows)
codex = "\n".join(
    f"- {name}: {description} (file: {skill_dir / 'SKILL.md'})"
    for skill_dir, name, description in rows
)

for label, listing, bytes_per_token in (
    ("claude", claude, 3),
    ("codex", codex, 4),
):
    size = len(listing.encode())
    print(f"{label}_listing_chars={len(listing)}")
    print(f"{label}_listing_utf8_bytes={size}")
    print(f"{label}_estimated_tokens={round(size / bytes_per_token)}")
PY
```

The default result has three independent checks:

1. The marketplace build validates all 47 Claude/Codex invocation-control pairs.
2. The Claude listing projection excludes every pstack row under the committed
   default policy. Anthropic documents that `disable-model-invocation: true`
   removes a skill from model context until manual invocation and reduces its
   skill-context cost to zero.
3. The isolated native-client scenario installed pstack into Claude Code
   `2.1.283` and Codex CLI `0.157.1`, verified it remained disabled, discovered
   all 47 Codex skills, and passed versioned update, relocation, rollback, and
   local Git marketplace checks. It made no model calls and did not modify the
   live user profiles.

OpenAI's skill documentation states that enabled skills normally contribute
their name and description before the full instructions are loaded. Its plugin
documentation states that `enabled = false` disables a local-marketplace plugin
for a project. See [Skills](https://developers.openai.com/plugins/concepts/skills)
and [Package your plugin](https://developers.openai.com/plugins/build/plugins).
Claude's loading and zero-cost human-only behavior is documented in
[Extend Claude Code](https://code.claude.com/docs/en/features-overview).

## Compatibility Boundary

This is a reviewed package and discovery result, not a Claude/Codex port of
pstack. Several workflows assume Cursor-specific commands, model names,
`Task` subagents, `.cursor/skills`, `.cursor/rules`, or `/loop`. The package is
therefore default-disabled even though the skill metadata is also human-only.
Enable it only for an explicit trial, and judge each invoked workflow against
the current client rather than treating successful installation as behavioral
compatibility.
