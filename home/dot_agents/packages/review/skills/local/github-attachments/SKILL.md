---
name: github-attachments
description: Attach a screenshot, image, mockup, diagram, log file, JSON/trace dump, or any binary artifact to a GitHub PR or issue, or share one inline instead of as a gist. Use whenever a PR/issue comment, description, or body would benefit from an embedded image or file — UI changes, repro screenshots, before/after shots, design mockups, captured logs or traces. Wraps the `gh attach` extension. Select this when planning to upload, embed, or inline a file on a GitHub PR/issue rather than reaching for a gist or external host.
---

# GitHub Attachments

Use [`gh attach`](https://github.com/enthus-appdev/gh-attach) (a `gh` extension installed by this dotfiles repo) when a PR or issue benefits from a screenshot, mockup, log file, or other binary. Uploads land on auth-protected refs (`refs/uploads/issues/<N>` for PR/issue uploads, `refs/uploads/misc/<key>` for ad-hoc).

## When to reach for it

- Opening or commenting on a PR/issue and the prose needs an image (UI change, repro screenshot, before/after, design mockup).
- Sharing a small artifact (log snippet, JSON dump, captured trace) inline rather than as a gist.

## Key commands

Default behavior is print-markdown-to-stdout. It does **not** post a comment unless you pass `--comment`.

- `gh attach <pr-or-issue> path/to/file.png` — print the markdown image tag for paste.
- `gh attach path/to/file.png` — auto-detects the PR from the current branch.
- `gh attach --comment <pr> screenshot.png` — upload and post as a comment.
- `gh attach --title "<label>" <pr> file.png` — group uploads under a label (flags must precede the number).
- `gh attach --key <slug> banner.png` — ad-hoc upload not tied to a PR/issue.
- `gh attach --json <pr> file.png | jq -r '.files[0].url'` — script-friendly URL extraction (`--json` suppresses stderr on success; failures still write a plain-text error to stderr).

### Inspecting and reversing uploads

- `gh attach list` — show every upload ref in the current repo (use `--issues` / `--misc` to filter).
- `gh attach get <pr> --output ./restored` — round-trip the uploaded files back to disk.

### Composing with the rest of the `gh` flow

- `screencapture -i -t png - | gh attach --name shot.png <pr> -` to grab and upload (`screencapture` is macOS; `--name` is required when reading from stdin).
- `gh attach <pr> file.png | gh pr comment <pr> --body-file -` to embed inside a longer comment body.

## Cleanup

PR/issue uploads can be auto-purged on close by copying `.github/workflows/cleanup-gh-attach.yml` from the upstream repo into the target repo's `.github/workflows/`. That workflow only cleans issue/PR refs (`refs/uploads/issues/*`); ad-hoc `--key` (misc) uploads are never garbage-collected and must be deleted manually with `gh attach delete --key <slug> --yes` (the `--yes` is required for non-interactive use, including any agent-driven invocation).

## Footguns for agents

- Verifying your own uploads: on **private** repos the `blob/<sha>/<file>?raw=true` embed URL only resolves with a browser session cookie. PATs do not authenticate against it; use the parallel `gh api repos/<owner>/<name>/contents/<file>?ref=<sha>` endpoint instead.
- Deleting ad-hoc uploads non-interactively requires `--yes`; an agent invocation without it will hang on a confirmation prompt.
