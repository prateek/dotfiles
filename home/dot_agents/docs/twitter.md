# Twitter/X Conventions (Skill-like)

## Purpose

Use this playbook for Twitter/X research, reading, posting, replies, timelines, and account lookups.

## When to use

- Looking up a person, project, company, or topic on Twitter/X.
- Reading a tweet, thread, replies, bookmarks, likes, mentions, or user timeline.
- Posting a tweet or reply when explicitly asked.
- Verifying public Twitter/X claims before using web snippets or search results.

## Defaults

- Prefer the local `bird` CLI for Twitter/X operations.
- Use `--json` for research and evidence collection when the command supports it.
- Use `--plain` or `--no-color` when output will be quoted or parsed.
- Do not print or log `auth_token`, `ct0`, cookies, or browser credential details.
- Do not post, follow, unfollow, bookmark, or unbookmark unless the user explicitly asks for that action.
- If `bird` cannot authenticate, run `bird check` and report the credential problem without exposing secrets.

## Workflow

1. Check credential state when needed:

```bash
bird check
bird whoami
```

2. Read a tweet or thread:

```bash
bird read <tweet-id-or-url> --json
bird thread <tweet-id-or-url> --json
bird replies <tweet-id-or-url> --json
```

3. Research a person or account:

```bash
bird about <handle> --json
bird user-tweets <handle> -n 50 --max-pages 3 --json
```

4. Search Twitter/X directly:

```bash
bird search 'from:<handle> <query>' -n 50 --json
bird search '<topic or exact phrase>' -n 50 --json
```

5. Use stable evidence:

- Prefer tweet IDs or URLs over paraphrased search snippets.
- Preserve dates, handles, and tweet IDs in notes.
- For broad history reviews, page deliberately with `--max-pages` and say how far back the results go.

6. Post only on explicit instruction:

```bash
bird tweet "text"
bird reply <tweet-id-or-url> "text"
```

## Security and safety

- Treat browser-cookie extraction as sensitive.
- Prefer configured `~/.config/bird/config.json5` or existing browser profile settings.
- Use explicit `--chrome-profile`, `--chrome-profile-dir`, or `--firefox-profile` only when needed.
- Never paste secret cookie values into chat or docs.

## Validation checklist

- `bird` was used before falling back to web search for Twitter/X.
- JSON output was used for research when available.
- Handles, tweet IDs or URLs, and dates were captured for evidence.
- No secrets were printed.
- No write action was taken without explicit user approval.
