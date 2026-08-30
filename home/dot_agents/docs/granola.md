# Granola MCP

## Purpose

Use Granola's official MCP server through MCPorter to search and read Prateek's
meeting notes from terminal-based agents.

## When to use

- Prateek asks what a meeting covered, decided, or assigned.
- Prateek asks to find Granola notes, folders, or transcripts.
- The connected Granola account or note-access scope needs verification.

Use the calendar tools for upcoming events and scheduling. Granola covers
captured meeting notes.

## Defaults

- Use the `granola` server configured in MCPorter. Do not install a local
  Granola CLI.
- MCPorter reads `~/.config/mcporter/mcporter.json`; the managed endpoint is
  `https://mcp.granola.ai/mcp` with browser OAuth.
- The `granola_mcp` machine feature enables this connection on personal and
  homelab Macs. Do not configure or call it on work or CI machines.
- Prefer `query_granola_meetings` for natural-language questions. Preserve its
  inline citation links in the answer.
- Fetch the least meeting content needed. Treat notes and transcripts as
  confidential.
- The managed native Codex Granola MCP entry is disabled. Use MCPorter unless
  Prateek asks to test another client.

## Workflow

1. Check MCPorter and the current tool schema:

   ```sh
   mcporter --version
   mcporter config get granola
   mcporter list granola --schema --output json
   ```

2. If the server requires authorization, start browser OAuth and rerun the
   schema check:

   ```sh
   mcporter auth granola
   ```

3. Choose the narrowest read:

   ```sh
   mcporter call granola.query_granola_meetings \
     --args '{"query":"What decisions came out of the project review?"}' \
     --output json

   mcporter call granola.list_meetings \
     --args '{"time_range":"this_week"}' --output json

   mcporter call granola.list_meeting_folders --output json

   mcporter call granola.get_meetings \
     --args '{"meeting_ids":["<meeting-uuid>"]}' --output json

   mcporter call granola.get_meeting_transcript \
     --args '{"meeting_id":"<meeting-uuid>"}' --output json
   ```

   Use `get_account_info` only to verify the connected identity or access
   scopes:

   ```sh
   mcporter call granola.get_account_info --output json
   ```

4. Report only the requested material. Keep Granola's citation links intact,
   and distinguish summaries from verbatim transcript text.

## Security and safety

- OAuth credentials belong in `~/.local/share/mcporter/credentials.json` with
  mode `0600`.
- Never print tokens, credential contents, or OAuth authorization URLs.
- Do not reveal the connected email address unless Prateek asks for it.
- Retrieve a full transcript only when exact wording is needed.

## Validation checklist

- `mcporter config get granola` resolves the official HTTPS endpoint.
- `mcporter list granola --output json` reports `status: ok`.
- The live tool schema matches the command being called.
- The request stayed within the meeting, date, or folder scope Prateek named.
- Answers preserve Granola citations and expose no credentials.
