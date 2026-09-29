# Item model and lifecycle

Type: grilling
Status: open
Blocked by: 01

## Question

What exactly is an item?

- Its fields: recipient, target session, author, body, links, created/updated.
- Its states and transitions: open → proposed → resolved; dropped?; edited after delivery?
- Who may make each transition, per the settled rule that an agent resolves agent-only items and human-involved items need human confirmation.

How is a **target session** identified durably?

- `ORCA_TERMINAL_HANDLE` is runtime-scoped and goes stale after an Orca restart.
- `ORCA_PANE_KEY` exists, and so does the provider session id (Claude/Codex `session_id`).
- What happens when the target session is gone?

Map the result onto aven's model (ticket 01) or onto the fallback store. Update `CONTEXT.md` as terms settle.
