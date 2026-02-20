---
name: mcporter-skillifier
description: Generate Codex skills that wrap MCP servers via MCPorter (CLI + keep-alive daemon) so skills can “just call” an MCP server (no Codex MCP wiring), including multi-turn `continuation_id` flows.
---

# Mcporter Skillifier

## Overview

This skill generates other skills: it writes a new `$skill-name/` folder that wraps an MCP server via the `mcporter` CLI (default: pinned `mcporter@${MCPORTER_VERSION}` via `npx`; optionally set `MCPORTER_BIN=mcporter` to use a local binary).

Use this when you want:
- Skill-local MCP access without modifying Codex core (no always-on Codex MCP server wiring).
- Multi-turn MCP flows that require server process persistence (e.g. PAL `continuation_id`) via MCPorter’s keep-alive daemon.
- A generic wrapper you can reuse for any MCP server (stdio or HTTP) without writing MCP protocol glue.

Important: Generated skills are **not** first-class Codex MCP tools (`mcp__...`). They are shell wrappers (`bash scripts/mcp ...`) that the skill can invoke via `exec_command`.

## Generate a skill

Generator:
- `dotfiles/.codex/skills/mcporter-skillifier/scripts/generate_skill.py`

Typical invocation (stdio server):

```bash
python3 "scripts/generate_skill.py" \
  --skill-name my-mcp-skill \
  --stdio 'uvx --from ${PAL_MCP_FROM} pal-mcp-server' \
  --keep-alive \
  --with-fixture-tests
```

Options (high level):
- `--skill-name`: folder name (hyphen-case).
- `--out-dir`: where to write the generated skill (defaults to `.../.codex/skills/`).
- `--http-url` or `--stdio`: how to connect to the MCP server.
- `--env KEY=VALUE`: fixed env overrides passed to the server process (repeatable).
- `--keep-alive`: enables MCPorter daemon keep-alive (required for in-memory `continuation_id` flows).
- `--idle-timeout-ms`: optional keep-alive idle timeout.
- `--with-fixture-tests`: adds a deterministic fixture MCP server + offline tests to validate keep-alive multi-turn behavior without API keys.
- `--[no-]verify`: runs the generated skill’s `scripts/selftest` after writing files (default: no-verify).

Note on interpolation: MCPorter supports `${VAR}` interpolation in config commands, but not bash defaulting like `${VAR:-fallback}`. If you need defaults, set env vars before running.

Also: if you embed a bash snippet inside `mcporter.json`, avoid `${local_var}` for shell-local variables. MCPorter may treat it as a required placeholder and fail unless that env var is set.

## Using a generated skill

From inside the generated skill directory:

```bash
bash "scripts/mcp" list
bash "scripts/mcp" call <tool> --output json --args '{"key":"value"}'
```

## Tests

When generating with `--with-fixture-tests`, the generated skill includes an offline unittest:

```bash
python3 -m unittest -q tests/test_offline.py
```

In the `codex-skill-scoped-mcp` experiment, there are also integration tests that prove:
- multi-turn continuity works via keep-alive across separate CLI invocations
- config-path isolation (continuation IDs don’t cross skills/configs)
- parallel calls and parallel invocations behave as expected

See:
- `experiments/codex-skill-scoped-mcp/scripts/test_mcporter_skillifier_fixture_multiturn.sh`
- `experiments/codex-skill-scoped-mcp/scripts/test_mcporter_skillifier_parallel_calls_same_daemon.sh`
- `experiments/codex-skill-scoped-mcp/scripts/test_mcporter_skillifier_parallel_invocations_isolated_daemons.sh`
