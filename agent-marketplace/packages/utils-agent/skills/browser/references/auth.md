# Browser identity and login

Choose the identity before the task's first browser command. Isolated is the
default.

| Identity | Orca | Terminal |
| --- | --- | --- |
| Isolated | `orca tab profile create --label <task> --scope isolated --json`, then `orca tab create --url <url> --profile <id> --json` | `agent-browser --session <name>` with a session name unique to this task |
| Imported | `scripts/orca-import-login`; see [Import source](#import-source) | `agent-browser --profile <Chrome profile name>` |
| Live attach | [browser-harness](drivers/browser-harness.md); Orca cannot drive Prateek's Chrome | [browser-harness](drivers/browser-harness.md), or Claude in Chrome when Prateek names it; both act inside his running Chrome |

## Import source

Import only from a browser and profile Prateek named. If he has not named one,
ask.

- Orca: run
  `~/.agents/plugins/plugins/utils-agent/skills/browser/scripts/orca-import-login
  --url <url> --browser <family> --browser-profile <directory or name>
  [--label <task>] [--worktree <selector>]`. It creates an imported profile,
  copies the named browser profile's login into it, opens the tab, checks the
  tab stayed on the site, and prints the page and profile IDs. On any failure it
  deletes what it created. `orca tab profile create --scope imported` by itself
  creates an empty profile; the import happens only through this script.
- Orca imports from the browser families it detects on this machine (Chrome,
  Edge, Arc, Chromium-based browsers such as Brave, Comet, Helium, and Safari);
  an unknown family's error lists the detected ones. Orca does not detect
  Prisma Access Browser (`Prisma Browser`, bundle `com.talon-sec.Work`), so
  its login cannot be imported. Do not decrypt its cookie store by hand either;
  work in Prisma itself with computer use instead: `orca computer` inside Orca,
  the [native driver](drivers/native.md) outside it. Signing in through Chrome
  and importing from Chrome is the fallback.
- Computer use in Prisma keeps Prateek's focus where it is:
  - Open a page with `open -g -a "Prisma Browser" <url>`, which loads it
    without raising the app.
  - Read with `orca computer get-app-state --app com.talon-sec.Work` and its
    screenshot, without `--restore-window`. Prisma exposes only its browser
    chrome (tabs, address bar) to accessibility, so page content comes from
    the screenshot.
  - Act by `--element-index` (`click`, `set-value`,
    `perform-secondary-action`) without `--restore-window`.
  - `type-text`, `press-key`, `hotkey`, and coordinate clicks act on whatever
    has focus. Use them only after Prateek agrees to hand over the window, and
    restore focus to where he left it afterwards.
- When the script reports a stop at the login page, the source browser's
  session has expired. Ask Prateek to sign in there, then rerun; leave the
  login and MFA prompts to him.
- `agent-browser --profile <name>` copies a named Chrome profile to a
  temporary directory; `agent-browser profiles` lists the names.
- For another browser, ask Prateek for the profile directory path. Tell him
  agent-browser uses a path in place as a persistent profile, so the browser
  writes to that directory. Pass the path only after he confirms.

## Sessions

Give each terminal task its own session name: a task prefix plus a short
random part, such as `checkout-k3f9`. Each shell command may run in a new
shell, where a shell variable is gone, so write the name down and type the
literal name into every command. If the name is lost,
`agent-browser session list` shows the active sessions. Reuse an earlier name
only to resume a login saved under it.

## Login hand-off

When the task needs a login the identity lacks:

1. Terminal: before the session's first command, ask Prateek whether to keep
   the login. To keep it, pass `--restore` on every command from the first
   one. In agent-browser 0.38.1, adding `--restore` to a running session
   relaunches its browser and loses the login.
2. Open the page headed (`agent-browser --headed ...`, or the Orca tab, which
   is already visible).
3. Ask Prateek to sign in, and wait for his reply.
4. Confirm the signed-in state from a page element, such as the account menu;
   never from cookies.

## Kept logins and credentials

A kept login is saved on close as plaintext cookies and localStorage under
`~/.agent-browser`, and loads again when a later command uses the same session
name with `--restore`. agent-browser deletes saved state after 30 days.

When Prateek asks for a reusable credential,
`agent-browser auth save <name> --url <login-url> --username <user>
--password-stdin` stores it in agent-browser's encrypted vault. He supplies
the password on stdin, and `agent-browser auth login <name>` uses it later.
