Use the task metadata above as paths and scope. Work in `workspace`. Read its
root AGENTS.md and `.agents/skills/agent-skill-management/SKILL.md`, then read
`guidance/SKILL.md` and `guidance/SKILL-MECHANICS.md`. Apply
$mattpocock:writing-for-agents to the whole assigned skill folder, including
references, prompts, examples, scripts, tests, and interface metadata.

Preserve the skill's purpose, caller-visible behavior, exact command contracts,
authorship/license notices, and required safety boundaries. Reorganize and
rewrite prose using context pointers, hierarchy, co-location, completion criteria,
leading words, positive instructions, and pruning. Inspect supporting code and
assets for consistency; retain correct executable behavior and binary assets.
Preserve independent test guarantees when editing tests. Keep each skill's root
SKILL.md and its invocation metadata pair consistent.

Scope edits to `roots` in this isolated checkout. The sole additional writable
artifact is `report`. Keep repository history, Git configuration, source checkout,
other artifact files, imported APM inputs, package selection, and plugin metadata
unchanged. The controller handles patches and version increments. Run local
checks needed to establish your changes; keep generated files out of skill
payloads. This is a local patch-authoring task: no publication, installation,
chezmoi apply, external messages, or additional agent delegation.

Write the phase's completion JSON to `report` after completing the work. It is
evidence, not an aspiration: list unresolved problems when any remain. Your final
reply summarizes changes, checks, and limitations; the transcript is retained.
