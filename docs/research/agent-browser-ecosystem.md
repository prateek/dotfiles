---
status: active
doc_type: research
created: 2026-10-16
updated: 2026-10-16
related:
  - ../plans/browser-runtime-controller-plan.md
  - obscura-browser-evaluation.md
status_detail: "Source survey; candidate architectures are not locally qualified integrations."
---

# How projects make browsers usable by agents

## Finding

The strongest candidates in this survey retain Chrome/Chromium and improve the
agent-facing control surface, session attachment, observation, or task loop.
Replacing the browser engine, as Obscura does, is a different bet. Our skill
should model these choices separately rather than adopt a list of interchangeable
“agent browsers.” This is an architectural inference from the projects below,
not a measured market-share claim.

## Search and evidence boundary

Used the skills-searcher doctor and its multi-backend searches for `browser`,
`browser extension`, and `CDP` (eight results each). All backend doctor checks
passed. Returned candidates were principally from GitHub skill search and
skills.sh; no finalist had demonstrated agreement across all four indexes.
Broadened discovery with web search, then read producer repositories and docs.
Dropped extension-building tutorials and unrelated high-install skills.
Popularity informed discovery, not compatibility or quality conclusions.

Read producer SKILL.md files for agent-browser, Playwriter, Playwright CLI,
and Browser Harness. The first three also came through `ask` source retrieval.
The installed ask required explicit `github:` specs; bare owner/repo failed as
npm lookups. BrowserOS ask retrieval failed, so its current GitHub README and
official documentation were used directly. Mutable upstream main and website
content were inspected on the date above; pin exact versions before trials.
No candidate was installed or given browser access during this survey.

## Architecture map

| Project | What it adds | Relevant distinction |
| --- | --- | --- |
| [Vercel agent-browser](https://github.com/vercel-labs/agent-browser) | Native Rust CLI using CDP, accessibility snapshots and compact refs, sessions, snapshot diffs, optional WebMCP discovery | Controller over Chrome/Chromium; not a new page engine. Already one of our documented controllers. |
| [Microsoft Playwright CLI](https://github.com/microsoft/playwright-cli) | Named browser sessions, reference-based actions, snapshots saved to files, selective snapshot search, traces, dashboard and manual takeover | Producer-maintained CLI plus skill; can launch browsers or attach through CDP/extension. |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | Structured browser tools through MCP, accessibility snapshots, optional visual/devtools capabilities | Another agent interface to Playwright. Its own README recommends considering CLI plus skills for coding agents. |
| [Playwriter](https://github.com/remorses/playwriter) | Chrome extension and local relay; stateful Playwright snippets through CLI or MCP | Reuses running browser sessions. JavaScript session state is separate, but browser tabs are shared. |
| [Browser Harness](https://github.com/browser-use/browser-harness) | CDP connection to real Chrome, Python helpers and task-local reusable helper code | Already our live-Chrome route. Its documented local daemon has one mutable current tab, requiring serialized browser operations across agents. |
| [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Puppeteer-backed actions plus network, console and performance inspection; CLI also offered | Especially relevant for diagnosing failures. Official support is Chrome/Chrome for Testing, not arbitrary Chromium embeddings. |
| [BrowserOS / neo](https://github.com/browseros-ai/BrowserOS) | Chromium forks plus agent platform, MCP, dashboard and session replay | BrowserOS embeds an AI agent for human browsing; neo is a secondary browser driven by external agents. Reuses Chromium rather than rebuilding web compatibility. |
| [Browser Use](https://github.com/browser-use/browser-use) | An autonomous task loop plus local/cloud browser and hosted-agent options | Distinguish the decision loop, browser hosting, and CLI/controller products. Local operation is supported. |
| [Stagehand](https://github.com/browserbase/stagehand) | Model-assisted observe/act/extract alongside explicit browser code | Useful for workflows combining deterministic actions with semantic discovery; introduces model calls above browser control. |
| [Alibaba Page Agent](https://github.com/alibaba/page-agent) | In-page JavaScript agent working from DOM text, optional extension and MCP | App integration can provide an agent without replacing the browser. Base page execution has different scope from browser-level control. |
| [WebMCP](https://developer.chrome.com/blog/webmcp-epp) | Websites expose structured actions through forms or JavaScript | A page-provided action interface, not a browser, controller, or remote MCP server. Chrome's linked announcement describes an experimental preview. |

## Techniques worth borrowing

### Keep observation small and expand on demand

Playwright CLI saves snapshots to files and supports `find`, depth limits and
subtree snapshots. Agent-browser has compact refs and snapshot diffs. Both now
expose experimental WebMCP tools; agent-browser documents bounded discovery
summaries and retrieving the selected schema only when needed.

For Orca, investigate compact interactive snapshots, scoped follow-up reads and
diffs through its existing page-scoped interface. Measure result correctness,
output bytes, latency and model usage separately. A smaller snapshot is not
better if it hides the target or a blocking dialog.

### Separate attachment from identity and retention

Playwriter's extension connects to tabs in a running browser. Playwright supports
[existing-browser extension attachment](https://playwright.dev/mcp/configuration/browser-extension)
as well as fresh or persistent sessions. BrowserOS neo documents importing Chrome
state into a separate browser. These are different identity operations: live
attach, explicit import, and retained task-owned profiles.

Some project comparison tables claim competing tools always start empty browsers
or run only in the cloud. Those claims contradict the competitors' own docs;
do not carry them into our plan. Reusing a session is a candidate way to avoid
repeated login work, not proof of Gmail, Patreon or anti-bot compatibility.

### Make ownership and concurrency observable

Playwriter provides session tab groups and scoped cleanup, but shared tabs are
not isolated browser profiles. Browser Harness explicitly documents current-tab
races. BrowserOS neo emphasizes concurrent agent tabs, live monitoring and replay.
Playwright CLI offers a session dashboard and manual takeover.

For Orca, retain explicit page IDs, task ownership and focus policy. Test two
agents acting on different pages before claiming concurrency safety. Never infer
isolation from a named session or tab group alone. Replay/recording retention
should be explicit, especially for authenticated pages.

### Keep the decision loop optional

Browser Use and Page Agent can decide actions themselves; Stagehand can add
model-assisted operations to code. CLI controllers can leave planning to the
calling coding agent. Our design needs an optional decision-loop dimension so
Jev, Browser Use, and deterministic commands are not classified as engines.
Jev relocation remains separate work in its existing experimental plugin.

### Let cooperating applications expose actions

WebMCP offers declarative forms and imperative JavaScript tools. This is worth a
small owned-app experiment: expose a read-only catalog query or navigation action,
compare it with DOM interaction, and verify the resulting UI/application state.
Treat page tool descriptions and annotations as untrusted page data. Native
support in Orca's embedded runtime is unverified; support in an external CLI
does not establish that the embedded engine implements the protocol.

## Proposed comparison before adoption

1. Use Chrome with current agent-browser as a baseline, and Orca through its
   existing supported route as a second baseline. Match viewport, task and
   identity class; do not compare a logged-in browser with an anonymous one.
2. Compare producer Playwright CLI against agent-browser on forms, Enter,
   stale references, shadow roots, iframes, SPA navigation, downloads and state
   persistence. Reuse our Obscura fixtures where the caller-visible contract fits.
3. Compare current Browser Harness with Playwriter or Playwright extension for
   an explicitly authorized live-Chrome task. Verify tab ownership, background
   behavior, recovery and scoped cleanup as well as successful interaction.
4. Study BrowserOS neo's MCP and ownership implementation for Orca design ideas;
   installing another Chromium fork is not needed to answer the controller question.
5. Only prototype a direct third-party controller attachment to Orca after
   establishing a supported endpoint and lifecycle contract. Our local Orca
   guide delegates page operations, but that is not proof that arbitrary CDP
   clients can safely take ownership of its embedded browser.
6. Keep Obscura as a separately qualified runtime. An alternative controller
   cannot supply missing web-platform behavior. Preserve the public-site and
   login failures in the existing evaluation until retested successfully.

The immediate shortlist is Playwright CLI for controlled comparison, Playwriter
for an alternative live-session bridge, and BrowserOS neo for product/ownership
patterns. This is a trial order, not a request to install every candidate or a
production-routing change. Final skill writing still requires the plan's
writing-for-agents gate.
