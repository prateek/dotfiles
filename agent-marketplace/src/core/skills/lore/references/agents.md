# Agents surface

What coding agents recorded: session transcripts with prompts, reasoning, tool
calls, and abandoned attempts, plus agent-written plans, handoffs, and
scratch notes. Strongest when an agent wrote or shaped the target, or when the
question is "what did we already try".

## Tools

- **agentsview**: one SQLite store of Claude Code, Codex, Cursor, and other
  sessions on this machine. Read `~/.agents/docs/agentsview.md` for the CLI
  and read-only store access before querying.
- **Cross-machine archive**: sessions from other hosts; the
  `agent-session-wiki` skill finds them.
- **Repo-local artifacts**: plans, handoffs, and ledgers the repo keeps (for
  example `docs/plans/`, `GHOST_OF_COMMITS_PAST.md`).
- **Commit-linked sessions**: some repos attach sessions to commits through
  git notes or refs (`git notes list`, `git for-each-ref refs/notes`).

## Seeding from the anchor

Search user prompts and assistant text for the branch name, PR number or URL,
file paths, symbols, and distinctive strings from the anchor, within a window
around the commit dates. Filter by project or worktree path when the store
records it. Read the session around each hit, not the hit alone: the reason
often sits a few turns before the edit.

## Pitfalls

- **Agent text is not a decision record.** A plan an agent proposed is
  evidence of what was considered; the human's reply shows what was accepted.
- **Pasted briefs repeat.** Subagent prompts duplicate the parent's context;
  count one origin, not many corroborations.
- **Coverage is per machine.** A missing session may live on another host or
  predate the store; name that gap.
