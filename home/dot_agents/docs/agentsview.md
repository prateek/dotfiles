# Agentsview Conventions

## Purpose

`agentsview` is a local web viewer plus a SQLite store that syncs sessions from AI coding agents (Claude Code, Codex, Cursor, and others) into one queryable database. Use this playbook when you need to inspect or debug what AI agents on this machine actually did: which tools and conventions they used, why some behavior did or did not happen, and what sessions cost.

The store is read-only ground truth about past agent behavior. Treat it as evidence, not as a place to write.

## When to use

- Debugging agent behavior: "why does behavior X never happen?", "did the agent take path Y?".
- Checking whether a convention, tool, or skill is actually being used (for example: is the `gh` wrapper invoked, does anyone read a given convention doc, which skills fire most).
- Auditing usage and cost across agents and projects.
- Pulling a specific session's messages or tool calls to reconstruct what happened.

## Defaults

- Prefer the `agentsview` CLI. It speaks to the live store correctly and emits JSON with `--format json`.
- For ad-hoc text search or custom joins, query SQLite on a **copy** of the DB. The viewer daemon holds the live database locked, so `sqlite3 -readonly` on the live file fails with `unable to open database file`. Copy first, then open the copy.
- The live store path is `~/.agentsview/sessions.db`.
- Treat the store as **read-only**. Never write to, mutate, or run `agentsview prune` against the live DB while debugging. Work on the `/tmp` copy.
- Per-agent breakdowns come from joining `tool_calls` / `messages` to `sessions` on `session_id` and grouping by `sessions.agent`.

## Orca-launched Codex sessions live outside ~/.codex

Orca gives Codex processes it launches their own private `CODEX_HOME` at
`<ORCA_USER_DATA_PATH>/codex-runtime-home/home` instead of the real `~/.codex`
(`~/Library/Application Support/orca/codex-runtime-home/home` on macOS, or
`orca-dev` for the dev build). This keeps Orca's own automation hooks out of
your real Codex profile, but it also means agentsview's default Codex root
(`~/.codex/sessions` + `~/.codex/archived_sessions`) silently misses every
session Orca launched.

The fix is `codex_sessions_dirs` in `~/.agentsview/config.toml`. Setting it
**replaces** agentsview's built-in defaults rather than extending them, so the
stock paths must be listed explicitly alongside the Orca one(s):

```toml
codex_sessions_dirs = [
  "~/.codex/sessions",
  "~/.codex/archived_sessions",
  "~/Library/Application Support/orca/codex-runtime-home/home/sessions",
  "~/Library/Application Support/orca-dev/codex-runtime-home/home/sessions",
]
```

This repo keeps that key in sync via
`home/dot_agentsview/modify_private_config.toml.tmpl`, a chezmoi `modify_`
script (same pattern as `home/dot_codex/modify_private_config.toml.tmpl`)
that sets only `codex_sessions_dirs` and never reads or reasons about any
other key. Everything else in the file, including the `auth_token` and
`cursor_secret` that agentsview generates itself, round-trips untouched,
preserved verbatim by `tomlkit`.

agentsview has no config-layering or include mechanism to keep those
secrets in a separate file (checked the source at v0.35.2), and no env var
that can express more than one Codex directory (`CODEX_SESSIONS_DIR` sets
exactly one path, and env always wins over the config-file array wholesale
rather than merging) — the config-file array plus a narrowly-scoped
`modify_` script is the least-risk way to keep this durable.

After the config changes, an already-running daemon needs a restart to pick
it up: `agentsview serve --background --replace`. `agentsview sync` alone
just re-syncs against the daemon's stale in-memory config.

## Workflow

### 1) Copy the live DB before any SQLite query

```sh
cp ~/.agentsview/sessions.db /tmp/av.db
sqlite3 /tmp/av.db   # open the copy read-write; the live file is locked by the daemon
```

Core tables and the columns you will use most:

- `sessions(id, project, agent, machine, started_at, ended_at, message_count, git_branch, cwd, health_grade, ...)`
- `messages(id, session_id, ordinal, role, content, timestamp, ...)`
- `messages_fts` — FTS5 index over `messages.content` (`content='messages'`), for fast full-text search.
- `tool_calls(id, message_id, session_id, tool_name, category, input_json, result_content, skill_name, subagent_session_id, ...)`

### 2) Count how often a CLI tool is invoked

Tool invocations live in `tool_calls`. Bash commands are in `input_json`, so a `LIKE` on the command string counts them. Example: how often agents shell out to `gh`.

```sh
sqlite3 /tmp/av.db \
  "SELECT COUNT(*) FROM tool_calls WHERE tool_name='Bash' AND input_json LIKE '%gh %';"
```

Per-agent breakdown via a join on `sessions.agent`:

```sh
sqlite3 -header -column /tmp/av.db "
  SELECT s.agent, COUNT(*) AS gh_calls
  FROM tool_calls t JOIN sessions s ON s.id = t.session_id
  WHERE t.tool_name='Bash' AND t.input_json LIKE '%gh %'
  GROUP BY s.agent ORDER BY gh_calls DESC;"
```

### 3) Check whether a convention doc is actually read

Reads of a file show up as `tool_name='Read'` with the path in `input_json`. Example: how many times the git convention doc was read.

```sh
sqlite3 /tmp/av.db \
  "SELECT COUNT(*) FROM tool_calls
   WHERE tool_name='Read' AND input_json LIKE '%/.agents/docs/git.md%';"
```

### 4) See which skills fire

`tool_calls.skill_name` is populated when a skill runs, so you can rank skill usage directly.

```sh
sqlite3 -header -column /tmp/av.db "
  SELECT skill_name, COUNT(*) AS n
  FROM tool_calls
  WHERE skill_name IS NOT NULL AND skill_name != ''
  GROUP BY skill_name ORDER BY n DESC LIMIT 10;"
```

### 5) Full-text search message content

`messages_fts` is FTS5, so use `MATCH` and join back to `messages` / `sessions`.

```sh
sqlite3 /tmp/av.db "
  SELECT m.session_id, m.role, substr(m.content,1,120)
  FROM messages_fts f JOIN messages m ON m.id = f.rowid
  WHERE messages_fts MATCH 'worktree' LIMIT 10;"
```

### 6) Use the CLI for session-level access

```sh
agentsview session list --limit 20 --format json          # recent sessions (filters: --agent, --project, --date-from, --outcome, --health-grade)
agentsview session get <id> --format json                 # metadata + quality signals for one session
agentsview session tool-calls <id> --format json          # every tool call in a session
agentsview session messages <id> --format json            # a window of messages
agentsview session export <id> > /tmp/session.jsonl        # raw source JSONL (local only)
```

`session list` excludes automated, one-shot, and subagent sessions by default; pass `--include-automated`, `--include-one-shot`, or `--include-children` when you need them.

### 7) Usage, cost, and workspace analytics

```sh
agentsview usage daily              # per-day input/output/cache tokens and cost by model
agentsview usage statusline         # one-line cost summary for today
agentsview stats --since 28d --format json   # window-scoped analytics; filter with --agent / --include-project
agentsview token-use <id>           # token usage for one session
```

## Validation checklist

- Queried the live store through the `agentsview` CLI, or via SQLite on a `/tmp` **copy** (`cp ~/.agentsview/sessions.db /tmp/av.db`), never `sqlite3` on the locked live file.
- Did not mutate, write to, or prune the live store.
- Per-agent breakdowns join `tool_calls`/`messages` to `sessions` on `session_id` and group by `sessions.agent`.
