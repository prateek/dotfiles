---
name: browser
description: Browser automation and desktop UI. Use for web-page reads and interaction, screenshots, browser tests, login or session reuse, Orca's embedded browser, and native windows or dialogs. Routes browser tool selection by harness.
---

# Browser

## Workflow

1. **Policy.** Read [policy.md](references/policy.md) before acting. It owns
   authorization, focus, resource ownership, and secret handling for every
   driver. Resolve any conflict with a driver reference in favor of policy.
2. **Harness.** Use Orca when `ORCA_WORKTREE_ID` is set; otherwise use terminal.
   For Orca, check `orca status --json` until `runtime.reachable` is true, at
   ten-second intervals for at most one minute. Stop the browser workflow if
   it remains unavailable and report the blocker. Continue when the harness
   is identified and, for Orca, its runtime is reachable.
3. **Driver.** Choose the first matching row and read its linked reference.
   Use the selected harness's column throughout the task.

   | Task | Orca | Terminal |
   | --- | --- | --- |
   | Prateek requests his running Chrome | [browser-harness](references/drivers/browser-harness.md) | [browser-harness](references/drivers/browser-harness.md), or Claude in Chrome when named |
   | Prateek names another browser tool | [Orca](references/drivers/orca.md); explain this harness's routing | The named tool |
   | Native window, dialog, or app chrome | [Orca](references/drivers/orca.md), using `orca computer` | [Native UI](references/drivers/native.md) |
   | Cross-browser test suite (Firefox or WebKit) | [Playwright](references/drivers/playwright.md) | [Playwright](references/drivers/playwright.md) |
   | Public-page read without interaction | Web fetch, API, or domain CLI | Web fetch, API, or domain CLI |
   | Other page work, including blocked or incomplete fetches | [Orca](references/drivers/orca.md) | [agent-browser](references/drivers/agent-browser.md) |

   For running Chrome inside Orca, explain that browser-harness controls it
   because Orca's browser commands control only its embedded pages.
4. **Identity.** Use an isolated identity by default. Before creating a browser
   session, importing a login, or entering credentials, read
   [auth.md](references/auth.md). Continue when the identity is chosen and any
   import source or live browser has been named by Prateek.
5. **Work.** Follow the selected driver's workflow and the shared
   [interaction loop](references/policy.md#interaction). Verify the requested
   page or app state before reporting success.
6. **Finish.** Apply [resource cleanup](references/policy.md#ownership).
   Report the result, identity used, and any resources retained for reuse.

## Terms

- **Harness:** where this agent runs: Orca or terminal.
- **Driver:** the tool acting on a page or window.
- **Identity:** browser state. **Isolated** is fresh task-owned state;
  **imported** copies a login from a source Prateek names; **live attach**
  controls his running browser. Import and live attach require his request.
- **Owned:** a browser, session, profile, or tab created by this task or named
  by Prateek for this task.
