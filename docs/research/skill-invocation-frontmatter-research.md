---
status: current
doc_type: research
created: 2026-09-01
updated: 2026-09-01
related:
  - agent-skill-management-research.md
  - ../plans/skill-management-console-plan.md
  - ../adr/0007-default-loaded-plugin-policy.md
---

# Skill Invocation-Control Frontmatter Across Harnesses

## Scope

Which `SKILL.md` frontmatter fields control skill invocation in each harness
this repo renders packages for: Claude Code, Codex, pi, and cursor-agent.
The two controls of interest:

- `disable-model-invocation: true` — the model cannot auto-invoke the skill;
  the human still can (slash command / explicit invocation).
- The inverse (`user-invocable: false` in Claude Code) — hidden from the
  human's command menu; only the model invokes it.

Everything below was verified locally on 2026-09-01 against the installed
binaries and package sources on this machine, except Codex, which is not
installed here; its section relies on the companion research doc's 2026-05-10
local verification and OpenAI's config reference.

## Summary

| Harness | `disable-model-invocation` | Inverse (hide from user) | Evidence |
| --- | --- | --- | --- |
| Claude Code 2.1.257 | Yes; excluded from model listing, slash-only | Yes: `user-invocable: false` | binary schema + `/context` capture |
| pi 0.84.3 | Yes; excluded from system prompt, `/skill:name` only | No; unknown keys ignored | `dist/core/skills.d.ts` |
| cursor-agent 2026.07.01 | Yes; parsed and sent to server | No; zero references in bundle | bundle + protobuf types |
| Codex | Not frontmatter; sidecar `agents/openai.yaml` `policy.allow_implicit_invocation: false` | No equivalent | Codex config reference |

Neither field is part of the Agent Skills open standard. The
[agentskills.io specification](https://agentskills.io/specification) defines
only `name`, `description`, `license`, `compatibility`, `metadata`, and
`allowed-tools`; `disable-model-invocation` has an open standardization
proposal at
[agentskills/agentskills#241](https://github.com/agentskills/agentskills/discussions/241),
and `user-invocable` is a Claude Code extension.

## Claude Code

Version inspected: 2.1.257, via `strings` over the installed binary
(`/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe`).
Official reference: [Extend Claude with skills](https://code.claude.com/docs/en/skills).

Both directions exist, with these schema descriptions embedded in the binary:

- `disable-model-invocation`: "If true, the model cannot invoke this via the
  Skill tool; only users can type the slash command."
- `user-invocable`: "If false, hides the slash command from users; only the
  model can invoke it via the Skill tool." Defaults to `true`.

Findings from the binary and from a live `/context` capture:

- **Flagged skills leave the model listing entirely.** The internal
  `model_invocable` predicate requires `!disableModelInvocation`, and a
  2026-09-01 `/context` capture on this machine listed exactly the 11
  non-flagged mattpocock skills — all 14 `disable-model-invocation` skills in
  that plugin were absent. (`claude plugin details` still assigns them a
  per-row cost; that is an estimator artifact, not real listing cost.)
- **The flag author-locks the `/skills` UI.** A skill declaring
  `disable-model-invocation` shows "(on/name-only locked by frontmatter
  disable-model-invocation)"; the user can only choose `user-invocable-only`
  or `off`.
- **`skillOverrides` is inert for plugin skills.** The state-resolution
  function returns `"on"` unconditionally when `source === "plugin"` before
  consulting `skillOverrides` (`on`/`name-only`/`user-invocable-only`/`off`).
  Plugin skills are managed through `/plugin` enablement instead, which the
  `/skills` UI states ("Plugin skills are managed via /plugin").
- **Recognized frontmatter keys** (the binary's known-keys array, 48 entries):
  `name`, `description`, `model`, `allowed-tools`, `argument-hint`,
  `arguments`, `disable-model-invocation`, `user-invocable`, `effort`,
  `shell`, `version`, `when_to_use`, `paths`, `hooks`, `context`, `agent`,
  `created_by`, `improved_by`, `mcpServers`, `lspServers`, `agents`,
  `outputStyles`, `themes`, `workflows`, `channels`, `monitors`, `settings`,
  `experimental`, `commands`, `skills`, `dependencies`, `userConfig`,
  `metadata`, `displayName`, `defaultEnabled`, `fallback`, `evals`, `author`,
  `homepage`, `repository`, `license`, `keywords`, `compatibility`, `tools`,
  `disallowedTools`, `color`, `permissionMode`, `maxTurns`, `initialPrompt`,
  `memory`, `background`, `isolation`, `keep-coding-instructions`,
  `force-for-plugin`, `type`, `originSessionId`,
  `hide-from-slash-command-tool`. The last appears only in the schema list,
  with no other reference in the binary — vestigial.
- **Setting both flags makes a skill unreachable** (hidden from `/` and from
  the model). The docs warn against combining them, and
  [anthropics/claude-code#19141](https://github.com/anthropics/claude-code/issues/19141)
  tracks the docs clarification between the two fields.
- **Known bugs around explicit invocation of flagged skills:**
  [anthropics/claude-code#26251](https://github.com/anthropics/claude-code/issues/26251)
  and
  [anthropics/claude-code#78523](https://github.com/anthropics/claude-code/issues/78523)
  report `/skill-name` sometimes failing for `disable-model-invocation`
  skills, though slash-only invocation is the documented behavior.

## pi

Version inspected: `@earendil-works/pi-coding-agent` 0.84.3
([npm](https://www.npmjs.com/package/@earendil-works/pi-coding-agent)), which
ships TypeScript declarations. `dist/core/skills.d.ts` declares the complete
frontmatter contract:

```ts
export interface SkillFrontmatter {
    name?: string;
    description?: string;
    "disable-model-invocation"?: boolean;
    [key: string]: unknown;
}
```

Semantics, from the `formatSkillsForPrompt` doc comment: "Skills with
disableModelInvocation=true are excluded from the prompt (they can only be
invoked explicitly via /skill:name commands)." The same comment cites the
Agent Skills standard's
[integration guide](https://agentskills.io/integrate-skills) for the XML
listing format.

Unknown keys pass through untyped and unused, so `user-invocable: false` is a
no-op: the skill stays in pi's command list and in the model listing.

## cursor-agent

Version inspected: 2026.07.01-41b2de7
(`~/.local/share/cursor-agent/versions/2026.07.01-41b2de7/index.js`).
Official reference: [Agent Skills | Cursor Docs](https://cursor.com/docs/skills),
which documents `disable-model-invocation: true` as making a skill "behave
like a traditional slash command," included in context only when explicitly
typed.

From the bundle:

- Parses `disable-model-invocation` with a strict
  `!0 === data?.["disable-model-invocation"]` check, for both directory
  skills and plugin-delivered skills.
- Carries the flag on the `agent.v1.AgentSkill` and `aiserver.v1.ManagedSkill`
  protobuf messages. Cursor's agent loop runs server-side, so enforcement is
  not locally observable, but the field is plumbed end to end and preserved
  when cursor-agent serializes a skill back to frontmatter.
- Has zero references to `user-invocable`.
- Cursor's own invocation vocabulary is different in kind: `environments`,
  `disabled-environments`, `globs`/`paths` (path-scoped activation), and
  `alwaysApply` — the last forces a skill into context, the inverse in the
  opposite direction from hiding it.

## Codex

Codex has no invocation-control frontmatter in `SKILL.md`. Controls live in
two Codex-native places (see
[Codex config reference](https://developers.openai.com/codex/config-reference)
and the Codex sections of
[agent-skill-management-research.md](agent-skill-management-research.md),
locally verified 2026-05-10):

- `agents/openai.yaml` next to the skill:
  `policy.allow_implicit_invocation: false` blocks description-based
  automatic activation while keeping explicit `$skill` invocation. This is
  the closest equivalent to `disable-model-invocation`. A local example ships
  in the experimental package:
  `home/dot_agents/packages/experimental/skills/local/image-gen-nano-banana/agents/openai.yaml`.
- `~/.codex/config.toml`: `[[skills.config]]` with `path` and
  `enabled = false` disables a skill entirely, per path.

There is no "hide from user, keep for model" concept.

## Consequences For This Repo's Packages

Packages under `home/dot_agents/packages/` render into all four harnesses
from one source, so:

- `disable-model-invocation` is the only near-portable control: honored by
  Claude Code, pi, and cursor-agent; silently ignored by Codex unless the
  skill also ships an `agents/openai.yaml` sidecar with
  `allow_implicit_invocation: false`.
- `user-invocable: false` only has effect in Claude Code. The repo's live
  example is the vendored `review` package's `crit-cli` skill
  (`home/dot_agents/packages/review/skills/vendor/crit-cli/SKILL.md`), a
  model-only CLI reference hidden from the `/` menu — in pi and cursor-agent
  it remains fully user-visible.
- For the skill-listing budget work
  ([skill-management-console-plan.md](../plans/skill-management-console-plan.md)),
  flagging a skill removes its row from Claude's model listing entirely,
  which is what makes the flag a real budget lever there.

## Reproduction

```sh
# Claude Code: schema, states, and the known-keys array
strings -n 6 "$(readlink -f "$(which claude)")" |
  grep -o '.\{200\}disable-model-invocation.\{300\}'

# pi: the full frontmatter contract
cat ~/.local/share/mise/installs/npm-earendil-works-pi-coding-agent/latest/\
lib/node_modules/@earendil-works/pi-coding-agent/dist/core/skills.d.ts

# cursor-agent: flag parsing and proto plumbing
grep -o '.\{200\}disableModelInvocation.\{200\}' \
  ~/.local/share/cursor-agent/versions/*/index.js | sort -u
```
