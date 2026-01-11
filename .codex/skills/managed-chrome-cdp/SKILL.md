---
name: managed-chrome-cdp
description: Start a managed Chrome CDP session with a prewarmed profile dir and reuse login cookies for browser automations.
---

# Managed Chrome CDP (prewarm + reusable cookies)

Use this when Chrome remote debugging (CDP) is blocked on first launch until enterprise policy is cached to disk.

## Tool

- Script: `~/dotfiles/scripts/browser-tools.ts`
- First run auto-installs pinned deps into a per-user cache (override cache root with `BROWSER_TOOLS_CACHE_DIR`).

## Quick start

- Start a headless CDP Chrome using a persistent profile dir:
  - `bun ~/dotfiles/scripts/browser-tools.ts start --headless --port 9333`
  - Default profile: `.dev/chrome-cdp-profile` (relative to your current directory)

## Login flow (cookie reuse)

- Check if automation can access the portal:
  - `bun ~/dotfiles/scripts/browser-tools.ts ensure-auth "<url>" --port 9333`
- If it says login is required:
  - `bun ~/dotfiles/scripts/browser-tools.ts login "<url>" --port 9333`
  - This opens a **headed** Chrome for you to complete login, then restarts **headless** by default (so it won’t grab focus during automation).

## Reset / recovery

- If the profile gets wedged/corrupted (or CDP won’t come up), reset it:
  - `bun ~/dotfiles/scripts/browser-tools.ts reset-profile --force`
  - Then re-run `start` and `login` as needed.

## Notes

- Don’t run multiple Chrome instances using the same `--profile-dir` at once (Chrome profile lock).
- The default profile dir is gitignored automatically when running inside a git repo.
- The script may append `**/.dev/chrome-cdp-profile/` to `.gitignore` and `.git/info/exclude` (when using the default profile dir).
- `content` / `search` inject third-party JS from `unpkg.com` (Readability/Turndown) into the page to extract readable text; avoid on sensitive pages if that trust boundary is a concern.
