# Team surface

What people wrote outside the repo. Two kinds of record, each with its own
strengths:

- **Written intent**: design docs, RFCs, tickets, wikis, roadmaps,
  postmortems, runbooks (Google Docs, Confluence, Notion, Jira, Linear, GitHub
  Projects). Best at motivation written before the code and the business or
  product forcing function.
- **Conversation**: chat, meeting notes and transcripts, email (Slack, Teams,
  Discord, Granola, Gemini notes, Gmail). Best at decisions that never reached
  a doc, and at who to ask.

Which tools an organization uses comes from the guidance layers or from what
this session can call. Read a tool's own convention doc under
`~/.agents/docs/` before its first query (for example `slack.md`,
`google-workspace.md`, `granola.md`, `linear.md`).

## Seeding from the anchor

- The PR URL or `/pull/<n>`: reviews and launches get linked in chat and docs.
- The author's messages in a window around the merge date.
- Ticket IDs from commits and PR bodies; open each ticket's parent, links, and
  comments.
- Distinctive strings: error messages, config keys, metric names, the literal
  number.
- The feature's name as people say it, which often differs from the symbol.
- For incident lineage: the incident channel or postmortem for the date range
  just before a defensive change (guard, retry, timeout, limit, flag).

## Pitfalls

- **Read the whole thread or doc.** A single message out of context misleads;
  the decision is often in a reply or a comment.
- **Banter is not a decision.** Look for considered discussion, an owner's
  call, or a written outcome.
- **Retention and access.** Old messages expire and DMs or private docs are
  unsearchable. Name the retention cliff and the unsearched spaces.
- **Docs drift.** A design doc records the plan at a moment; compare it with
  what shipped before citing it as the reason.
- **Auth failures are gaps.** Report the surface as unsearched; never fill it.
