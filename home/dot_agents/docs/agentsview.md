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
