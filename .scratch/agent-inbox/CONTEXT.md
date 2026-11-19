# Worktree inbox: glossary

**Worktree inbox**: the set of items addressed to one worktree on one host. That host owns them.

**Item**: one note or message in a worktree inbox. It has exactly one recipient and exactly one owning inbox.

**Recipient**: who an item is for: `human`, `agent`, or `both`.

**Target session**: an optional narrowing of an agent-bound item to one agent session inside the worktree. Without it, any agent session in the worktree may take the item.

**Author**: who wrote the item: the human, the same worktree's agent (a note to itself), or an agent elsewhere.

**Open / Resolved**: an item is open until resolved. Items whose recipient includes the human resolve only after human confirmation. An agent may *propose* a resolution.

**Delivered**: stored in the recipient's worktree inbox. It does *not* mean pushed into a live session; that is **auto-delivery**, which is out of v1.

**Outbox**: the author's view of items they sent and their status. Not a separate store. The only physical outbox is the **pending queue**: items held on the author's host while the recipient's host is unreachable.

**Done check**: the point where open items involving the human must be dealt with before work counts as done. In v1 it is Orca worktree removal (the archive hook).
