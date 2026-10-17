# Agent conventions and CLI surface

Type: grilling
Status: open
Blocked by: 03

## Question

What do agents actually do with the inbox?

- The CLI verbs and flags an agent uses: add a note to itself, write to another worktree, list, propose a resolution, resolve agent-only items.
- How the session-start count line is injected for Claude (SessionStart hook) and for Codex (hooks are enabled in `codex-config-managed.toml.tmpl`), next to Orca's own managed hooks, without touching them.
- What the skill or convention text tells agents about raising items addressed to both before claiming done.
- How the worktree card comment count (`orca worktree set --comment`) stays current without stomping on the comments agents already write.
