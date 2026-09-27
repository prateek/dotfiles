---
name: browser
description: Browser automation and desktop UI. Use for web-page reads and interaction, screenshots, browser tests, login or session reuse, Orca's embedded browser, and native windows or dialogs. Routes browser tool selection by harness.
---

# Browser

## Workflow

1. **Read policy.** Read [policy.md](references/policy.md) before browser or
   desktop actions. It defines authorization, focus, ownership, and secret
   handling for every driver and takes precedence over driver-specific advice.
2. **Identify the harness.** Use Orca when `ORCA_WORKTREE_ID` is set; otherwise
   use the terminal. When using Orca, poll `orca status --json` every ten
   seconds for at most one minute. Continue once `runtime.reachable` is true.
   If it remains unavailable, stop browser work and report the blocker.
3. **Select a driver.** Choose the first matching row and read its linked
   reference. Stay within the selected harness column for the task.

   | Task | Orca | Terminal |
   | --- | --- | --- |
   | Prateek requests his running Chrome | [browser-harness](references/drivers/browser-harness.md) | [browser-harness](references/drivers/browser-harness.md), or Claude in Chrome when named |
   | Prateek names another browser tool | [Orca](references/drivers/orca.md); explain this harness's routing | The named tool |
   | Native window, dialog, or app chrome | [Orca](references/drivers/orca.md), using `orca computer` | [Native UI](references/drivers/native.md) |
   | Cross-browser test suite (Firefox or WebKit) | [Playwright](references/drivers/playwright.md) | [Playwright](references/drivers/playwright.md) |
   | Public-page read without interaction | Web fetch, API, or domain CLI | Web fetch, API, or domain CLI |
   | Other page work, including blocked or incomplete fetches | [Orca](references/drivers/orca.md) | [agent-browser](references/drivers/agent-browser.md) |

   For Chrome running inside Orca, use browser-harness and explain that Orca's
   browser commands operate only on Orca's embedded pages.
4. **Choose identity.** Use isolated state by default. Before creating a
   session, importing a login, or entering credentials, read
   [auth.md](references/auth.md). Continue when the identity is chosen and any
   import source or live browser has been named by Prateek.
   For an owned private service whose self-signed certificate Orca cannot
   accept, follow [certificate recovery](references/certificate.md).
5. **Work.** Follow the selected driver's workflow and the shared
   [interaction loop](references/policy.md#interaction). Verify the requested
   page or app state before calling the task complete.
6. **Clean up and report.** Apply [resource cleanup](references/policy.md#ownership).
   State the result, identity used, and any resources intentionally retained.

## Terms

- **Harness:** the environment running this agent: Orca or terminal.
- **Driver:** the tool that acts on a page or native window.
- **Identity:** browser state used for the task. **Isolated** means fresh,
  task-owned state. **Imported** means a login copied from a source Prateek
  names. **Live attach** means control of his running browser. Imports and live
  attaches require his request.
- **Owned resource:** a browser, session, profile, or tab created for this task
  or explicitly named by Prateek for it.
