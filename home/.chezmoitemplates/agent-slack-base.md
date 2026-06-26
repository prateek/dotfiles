# Slack Conventions (agent-slack CLI)

<!-- Generated file: composed at chezmoi apply by run_after_37-agent-slack-doc.
     Edit the base in home/.chezmoitemplates/agent-slack-base.md; the Chronosphere
     internal map is appended from the private overlay (prateek/dotfiles-private). -->

## Purpose

Playbook for all Slack read/search/send tasks, driven by the `agent-slack` **CLI**
— a command-line tool on `$PATH`, not a subagent. Installed via mise
(`npm:agent-slack`); the bundled skill lives at `~/.agents/skills/agent-slack/`,
with the full command map and flags under its `references/`.

## When to use

- Reading or searching Slack history (threads, channels, files, unreads).
- Posting updates, review requests, or coordination messages (only on explicit request).
- Resolving channel/user routing questions (where to post, who to cc).

## Defaults

- Use the `agent-slack` CLI for every Slack interaction. Invoke it directly
  (`agent-slack ...`); it is a CLI, not a subagent.
- **Workspace is explicit.** Several workspaces are configured and the default is
  *not* Chronosphere, so pass `--workspace chronosphereio` on every command except
  `auth whoami`. `agent-slack auth whoami` lists configured workspaces;
  `agent-slack auth test --workspace <ws>` confirms identity.
- **Read first.** `search`, `message get`/`list`, `channel list`, `user list`/`get`,
  `unreads`, `later list`, and `canvas get` are safe to run freely.
- **Writes need an explicit ask.** `message send`/`edit`/`delete`/`react`,
  `channel` create/invite, and `later`/`workflow` mutations require a clear request
  and a confirmed channel + audience. Prefer `message draft` to stage a send first.
- Don't guess channel or user IDs; resolve them (`channel list`, `user get`).
- Private channels (lock icon): keep messaging need-to-know.

## Workflow

### 1) Confirm workspace + resolve the target

```sh
agent-slack auth whoami                                   # list configured workspaces
agent-slack channel list --workspace chronosphereio       # your channels (resolve IDs/names)
agent-slack user get --workspace chronosphereio @handle   # resolve a person
```

### 2) Read / search

```sh
agent-slack search messages "query" --workspace chronosphereio --limit 20 --resolve-users
agent-slack message get  --workspace chronosphereio "SLACK_URL" --resolve-users
agent-slack message list --workspace chronosphereio "#channel" --thread-ts <ts> --resolve-users
agent-slack unreads --workspace chronosphereio
```

### 3) Send (only when asked)

```sh
agent-slack message draft --workspace chronosphereio "#channel" "text"      # native rich editor
agent-slack message send  --workspace chronosphereio "#channel" "text" --thread-ts <ts>
```

**Compose natively — do not `pbcopy` a hand-assembled draft for manual pasting.**
`agent-slack message draft` opens a rich Slack-like editor (correct rich text,
mentions, emoji, lists) that you review and send from; prefer it for anything
non-trivial, then `message send` once approved. Bullet/numbered lists already
render as native Slack rich text; use `--blocks <file>` for Block Kit layouts and
`--attach <path>` to upload a file. Reserve clipboard / manual paste for when
agent-slack genuinely cannot reach the target.

### 4) Review requests

There is no fixed `r?` prefix convention here. To ask for a code review, post the
merge-request / PR link with a one-line description and @mention the reviewer(s) in
the relevant team channel; **"PTAL"** (please take a look) is the common phrasing.
Reference the tracker story when one exists. Workspace-specific review host, tracker
org, and channel routing are in the Chronosphere internal map below (rendered when
the private overlay is enabled).

## Notes / limitations

- The installed release (v0.9.3) has **no scheduling**; the bundled skill documents
  `--schedule-in` / `message scheduled …` for forward-compat once `latest` advances.
- Auth subcommands are `auth whoami` and `auth test` (there is no `auth status`).
- JSON shape varies by command (`channels` vs `conversations`; search returns
  `messages[]` with `channel_id`/`content`); filter defensively.

## Validation checklist

- `--workspace chronosphereio` passed on every non-`whoami` call.
- Channel/user IDs resolved, not guessed.
- Correct channel for the audience and sensitivity (private = need-to-know).
- For sends: explicit user request, confirmed target, drafted and reviewed first.
