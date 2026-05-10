---
name: pal
description: Use the `pal` MCP server via MCPorter (with optional keep-alive daemon for multi-turn tools).
---

# Pal

This skill wraps an MCP server via MCPorter (shell calls), with an optional keep-alive daemon so stdio servers can support multi-turn `continuation_id` flows.

## Quick start

List tools:

```bash
bash "scripts/mcp" list
```

Call a tool (recommended: JSON args):

```bash
bash "scripts/mcp" call <tool> --output json --args '{"key":"value"}'
```

## Multi-turn note

If the server uses `continuation_id` backed by in-memory state (like PAL), you must keep the underlying server process alive between calls. This skill does that by configuring MCPorter `lifecycle=keep-alive` (daemon-managed). MCPorter will auto-start (and reuse) the daemon as needed; you can just keep calling tools.

## Assumptions / requirements

- Default: `npx` is available (Node installed) so the wrapper can run `mcporter@${MCPORTER_VERSION}`.
- Optional: set `MCPORTER_BIN=mcporter` to use a local `mcporter` binary on `PATH` instead of `npx`.
- `uvx` is available (uv installed).
  - Optional: set `PAL_UVX_BIN` to an absolute `uvx` path if it isn’t on `PATH`.
- The MCP server transport is reachable:
  - For stdio servers: the configured command exists and can start.
  - For HTTP servers: the URL is reachable and any required auth is configured.
- PAL requires provider credentials in the environment (e.g. `OPENAI_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, etc.).
- Optional env:
  - `PAL_MCP_FROM` to override where PAL is fetched from.
  - `PAL_DEFAULT_MODEL` to set `DEFAULT_MODEL` (defaults to `auto`).
- For multi-turn `continuation_id` flows: `lifecycle=keep-alive` is required (daemon-managed).

## Selftest

```bash
bash "scripts/selftest"
```
