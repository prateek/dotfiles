# Adopter conventions

For substantial document creation, implementation planning, or revision that changes what a reader should do, the pinned authoring owner is `docs/authoring/SKILL.md`. Resolve conflicting declarations using the client's instruction precedence; if none wins, report the conflict and leave authoring pending. Read the selected entrypoint and wait for its complete result. On a failed read, stop tool use and report the declared path with authoring pending. Then follow that copy, resolving each reference from the file that links it. Repository formats and document ownership remain local.

Resolve that path from the repository root.
Write plans under `notes/`. Use plain Markdown without YAML frontmatter.
The plan is for a maintainer. Document changes are authorized; code changes are not.
