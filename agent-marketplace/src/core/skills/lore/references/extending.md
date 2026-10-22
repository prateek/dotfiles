# Extending lore

Read this when adding a tool, a surface, or guidance. Ordinary runs do not
need it.

| Observed need | Smallest owning change |
| --- | --- |
| A tool exists but the agent did not find it | Name it, and how to query it, in a guidance layer |
| An organization's channels, spaces, projects, or dashboards matter | A guidance layer: repo `.agents/lore.md`, user `~/.agents/docs/lore.md`, or a `lore-*.md` beside it |
| One repo has its own history conventions (trailers, ADR path, ticket prefix) | That repo's `.agents/lore.md` |
| A tool needs its own auth, CLI, or query dialect | That tool's convention doc under `~/.agents/docs/` or its own skill; lore points at it from guidance |
| A recurring kind of record changes which evidence to seek or how to verify it | A section in the matching surface reference |
| A kind of record fits no surface (rare) | A new surface reference plus a row in the SKILL.md surface table and argument docs |
| A one-off query | Nothing |

Guidance is prose. Give each entry the surface it serves, the tool, what it is
best at, and how to seed a search from the anchor. Keep secrets and private
URLs out of public layers; employer-specific guidance belongs in a private
layer.

Before adding to a surface reference, check that the entry changes what an
investigator does. A tool name alone, with nothing about how to search it or
what it is best at, belongs in guidance or nowhere.
