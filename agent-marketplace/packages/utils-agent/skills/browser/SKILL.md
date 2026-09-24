---
name: browser
description: Browser and desktop-UI work. Use to open, read, click, fill, screenshot, or test a web page; log into a site or reuse a browser login; drive Orca's built-in browser; or operate native app windows and dialogs. Overrides harness browser defaults such as Claude in Chrome.
---

# Browser

## Terms

- **Harness**: where this agent runs. **Orca** when `ORCA_WORKTREE_ID` is set;
  otherwise **terminal**.
- **Driver**: the tool that acts on the page or window.
- **Identity**: the browser state a task runs with.
  - **Isolated**: a fresh profile owned by the task. The default.
  - **Imported**: login state copied from a browser profile Prateek names into
    one the task owns. Only when Prateek asks.
  - **Live attach**: control of Prateek's running browser. Only when Prateek
    asks.
- **Owned**: a browser, session, profile, or tab this task created, or one
  Prateek named.

## Steps

1. **Harness.** When `ORCA_WORKTREE_ID` is set, the harness is Orca: run
   `orca status --json` until `runtime.reachable` is `true`, checking every 10
   seconds for up to a minute. If it stays unreachable, stop and tell Prateek
   Orca's runtime is unavailable. Inside Orca, every route comes from the Orca
   column; never fall back to the Terminal column. Done when the harness is
   terminal, or Orca reports `runtime.reachable: true`.
2. **Driver.** Take the first row whose task matches; the specific rows sit
   above the generic ones.

   | Task | Orca | Terminal |
   | --- | --- | --- |
   | Live attach: Prateek asks to use his running Chrome | [browser-harness](references/drivers/browser-harness.md); tell Prateek it is used because Orca cannot drive his Chrome. If he asked for Orca to do it, tell him Orca cannot | [browser-harness](references/drivers/browser-harness.md), or Claude in Chrome when he names it |
   | Prateek names a driver or harness browser tool (Claude in Chrome, Codex browser) | Orca; tell Prateek Orca handles browser work here | That tool |
   | Native window, dialog, or app chrome | `orca computer` ([Orca](references/drivers/orca.md)) | [Native UI](references/drivers/native.md) |
   | Cross-browser test suite (Firefox, WebKit) | [Playwright](references/drivers/playwright.md) | [Playwright](references/drivers/playwright.md) |
   | Read a public page, no interaction | Web fetch, API, or domain CLI | Web fetch, API, or domain CLI |
   | Any other web page, or a read whose fetch came back client-rendered, blocked, or missing the needed content | [Orca](references/drivers/orca.md) | [agent-browser](references/drivers/agent-browser.md) |

   Done when exactly one row is chosen and the reference it links, if any, is
   read end to end.
3. **Identity.** Read [auth.md](references/auth.md) whenever the task needs a
   login or cookies. Done when the identity is isolated, or Prateek has named
   the import source or live browser.
4. **Policy.** Read [policy.md](references/policy.md) before the first action.
   It binds every driver; when a driver's own guide disagrees with it,
   `policy.md` wins. Done when every action in the task has passed its rules.
5. **Finish.** Close owned sessions and tabs, and delete profiles the task
   created. Keep a session or profile only when Prateek asked to reuse its
   login. Done when you have reported to Prateek what was done, the identity
   used, and anything left open.
