---
name: pal-mcporter
description: Run PAL MCP tools (precommit, codereview, secaudit, debug, apilookup, listmodels, etc.) via the `mcporter` CLI against the PAL stdio MCP server (`uvx … pal-mcp-server`) instead of configuring PAL as a Codex MCP server in `~/.codex/config.toml`. Use when you want shell/script-friendly PAL runs, want to avoid MCP tool-schema context overhead, or need PAL access in an environment without Codex MCP wiring.
---

# PAL via MCPorter

## Quick start

- List PAL tools:
  - `bash "<path-to-skill>/scripts/pal" list`
- List PAL tools with schemas:
  - `bash "<path-to-skill>/scripts/pal" list --schema`
- Call a PAL tool (examples):
  - `bash "<path-to-skill>/scripts/pal" listmodels --output json`
  - `bash "<path-to-skill>/scripts/pal" apilookup prompt="OpenAI Responses API streaming" --output markdown`

## Workflow

1) Discover tool names and schemas.
   - Run `bash "<path-to-skill>/scripts/pal" list --schema` and search for the tool name.
2) Call the tool via MCPorter.
   - Prefer `--args '{...}'` for complex payloads to avoid shell quoting issues.
3) Treat stdout as the tool result.
   - Use `--output markdown` for readability or `--output json` when the tool returns JSON text.

## Configuration

This skill uses ad-hoc stdio mode (no `mcporter.json` required).

Set these env vars when needed:

- `OPENAI_API_KEY` (required for OpenAI-backed PAL usage; alternatives include `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, etc.)
- `PAL_DEFAULT_MODEL` (default: `gpt-5.2-pro`)
- `PAL_MCP_FROM` (default: `git+https://github.com/BeehiveInnovations/pal-mcp-server.git`)
- `PAL_UVX_BIN` (default: `uvx`, falling back to `~/.local/bin/uvx`)
- `MCPORTER_VERSION` (default pinned in `"<path-to-skill>/scripts/pal"`)
- `PAL_MCPORTER_TIMEOUT_MS` (default: `120000`)

## Notes

- STDIO mode inherits your shell environment automatically; avoid passing secrets via `--env KEY=value` unless you have to.
- If PAL startup is slow (first `uvx` run), increase timeouts with `PAL_MCPORTER_TIMEOUT_MS` or `--timeout <ms>`.
