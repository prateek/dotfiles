---
status: active
doc_type: research
summary: "Pinned source comparison of Hermes structured tools, Camofox sessions, and browser guidance against the proposed browser skill."
created: 2026-10-17
updated: 2026-10-17
related:
  - ../plans/browser-runtime-controller-plan.md
  - local-browser-runtime-evaluation.md
  - agent-browser-ecosystem.md
status_detail: "Pinned Hermes source comparison against our proposed browser skill; no complete Hermes integration was run."
---

# Hermes Camofox integration versus our browser proposal

## Decision

Hermes supports keeping Camofox as a serious candidate for agent-facing Camoufox
browsing. It supplies a tool interface and session lifecycle around the existing
Camofox REST API. Direct Playwright remains our tested scripting and comparison
baseline; its successful trials do not establish that we should recreate
Camofox's agent interface ourselves.

Our skill should reuse an upstream controller and describe explicit supported
recipes. It should not grow Hermes's provider registry, gateway or tool facade.
Those are executable parts of Hermes's agent runtime, while our skill routes
several independently maintained tools across Orca and terminal agents.

## Evidence and scope

Read Hermes with `ask src github:NousResearch/hermes-agent@main`. GitHub's main
head was `92acf4e794a22da49968fbcdec6ef4c0a83963fa` on 2026-10-17. Relevant cached
file blobs were compared with that commit; a stale config-defaults cache entry
was read from the pinned source instead. Links below pin that revision.

The source inventory did not contain a standalone general-purpose browser
`SKILL.md`. The comparable guidance is the built-in browser tool descriptions,
the embedded Browser Use helper reference, and the browser operator docs.
Specialized skills can call those tools. Copying their prose alone would not
install their Python adapter or supply Hermes's tools to another agent.

This is source inspection, including an independent reader's review. The
[local trials](local-browser-runtime-evaluation.md) tested Camofox REST and
direct Playwright separately; they did not run a complete Hermes agent. No new
browser, authentication or provider installation was performed for this comparison.

## Actual control paths

```text
Hermes with Camofox selected
  model -> browser_navigate/snapshot/click/type/... tools
        -> Hermes Python adapter -> Camofox REST -> Playwright -> Camoufox

Hermes with its default Browser Use driver and a compatible browser source
  model -> browser_exec(Python) -> browser-harness -> CDP -> browser

Our direct Camoufox experiment
  model -> task script -> Playwright/Juggler -> Camoufox
```

Hermes's `is_browser_use_cli_mode()` explicitly returns false when Camofox is
active. It retains structured browser tools because Camofox's REST service is
not a CDP endpoint. This agrees with our released-browser-harness compatibility
result; Hermes does not use that harness to control Camoufox.
[Driver selection](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_use_cli.py#L260-L268),
[Camofox adapter](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py).

## Comparison

| Concern | Hermes implementation | Our proposal and resulting change |
| --- | --- | --- |
| Agent interface | Common `browser_*` tools dispatch to provider-specific code. Camofox actions go through REST. | Keep a small skill router over existing controllers. An optional Camofox recipe must name its actual callable API/client; prose cannot manufacture Hermes's tools. |
| Controller versus browser source | `browser.backend` selects Browser Use mode or built-in tools; `browser.cloud_provider` selects a source, including local Camofox; `browser.engine` selects a local engine when applicable. | Preserve the separation, but call these controller, runtime/source and identity explicitly. Do not copy the misleading `cloud_provider` name for a local service. |
| Selection | Explicit Camofox selection wins over incidental provider credentials; a CDP override takes precedence. `CAMOFOX_URL` is the address, with legacy autodetection only when no provider was selected. | Make requested combinations explicit. Installation or an environment variable should not silently change our default runtime. |
| Observation | Navigation includes a snapshot; oversized snapshots are truncated by lines and stored for paging. | Borrow compact observations and reuse the navigation result when it is adequate. Keep saved observations task-owned with explicit retention. |
| Identity | Default random user ID; optional stable profile-scoped user ID and task-scoped session key; optional external identity/tab adoption. | Specify user ID, session key and tab ID separately. Shared identity means shared browser state, not independent task isolation. |
| Cleanup | Ephemeral close requests deletion of the live server session; Camofox's default persistence plugin may save its state to disk. Managed/external identities use soft cleanup that drops Hermes tracking while retaining server resources. | Separate closing owned tabs, retaining or removing disk state and stopping an owned server. Verify actual cleanup rather than treating local bookkeeping as closure. |
| References | The adapter strips the `@` prefix and forwards Camofox refs. | Apply the same fresh-observation rules as Orca. Hermes does not add ref generations or persistent node identity. |
| Recovery | Navigation to a remembered tab can recreate it on HTTP 404. Other failed actions return errors. | Reobserve after uncertainty, verify whether an action happened, and only then choose a retry. Recreating a tab does not restore the prior workflow. |
| Distribution | The Camofox server is installed and operated separately from Hermes. | Pin the tested wrapper/browser/Playwright combination in any adopted recipe and managed installation proposal. Avoid importing Hermes's integration code as another maintained adapter. |

Sources: [tool descriptions](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_tool.py#L479-L546),
[selection](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L93-L110),
[session lifecycle](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L242-L308),
[stable identity](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox_state.py),
[snapshot storage](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_tool_snapshot.py#L37-L110),
[operator configuration](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/website/docs/user-guide/features/browser.md).

## Limits to preserve rather than copy as guarantees

1. **No reference-generation guard.** Click and type forward the current numeric
   string. The shared schemas tell the agent to refresh snapshots after page
   changes, but this is an instruction rather than enforced reference identity.
   [Actions](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L484-L508).
2. **Uniform tools do not imply equal capabilities.** Camofox's `full` snapshot
   argument is unused; the same snapshot endpoint and output budget are used.
   Hermes's CDP supervisor cannot supply Camofox with its dialog/OOPIF workflow.
   [Snapshot implementation](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L367-L377),
   [unused full argument](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L475-L481),
   [supervisor support boundary](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/website/docs/developer-guide/browser-supervisor.md#L24-L46).
3. **Success envelopes need postconditions.** The type adapter discards the
   successful HTTP response body before reporting success. Close can report
   `closed: true` with a warning after DELETE fails. This is a source-level
   reason to verify page values and server resources, not a claim that every
   successful action is incorrect.
   [Type](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L491-L508),
   [close](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L527-L535).
4. **Persistence and ownership differ.** A stable user ID asks the server to
   reuse state; Hermes cannot establish that a particular server build restores
   it across restart. Soft cleanup leaves resources on that server. External
   tab adoption also falls back to the last returned tab for the identity when
   no session key matches. Our policy requires an explicitly owned/named tab,
   so a missing match should not authorize that fallback.
   [Adoption and soft cleanup](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_camofox.py#L242-L308).
5. **Generic lifecycle documentation is not Camofox proof.** The inspected idle
   reaper uses the facade's session/activity maps, while Camofox tracks sessions
   separately. Do not claim the documented generic inactivity timeout cleans
   up Camofox without a targeted runtime test.
   [Lifecycle implementation](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/tools/browser_tool_lifecycle.py).

The catalog also lists a separate community `camofox-human-auth` plugin. That is
an additional integration, not evidence that core Hermes solves Google/Patreon
login or all challenges. Its implementation was outside this comparison.
[Catalog entry](https://github.com/NousResearch/hermes-agent/blob/92acf4e794a22da49968fbcdec6ef4c0a83963fa/plugin-catalog/camofox-human-auth.yaml).

The later [Fable review](browser-runtime-controller-fable-review.md) checked
Camofox v1.18.1's persistence implementation: session deletion checkpoints
state, while the dedicated storage-state reset removes it. Thus Hermes's
ephemeral identifier is not a guarantee of ephemeral disk state.
[Persistence plugin](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/plugins/persistence/index.js).

## Changes to our proposal

- Evaluate Camofox's existing agent-facing API before building helpers above
  raw Playwright. Keep direct Playwright for scripts, precise locators and the
  comparison baseline. Existing Orca/terminal defaults remain unchanged.
- A Camofox recipe must name its tested API/client combination. The later
  [qualification](browser-controller-qualification.md) separately exercises curl
  REST and the upstream MCP adapter through MCPorter; it does not qualify a
  complete Hermes integration or native harness activation.
- Require explicit ephemeral, retained and externally owned modes, each with
  tab/session/server cleanup rules and observable completion criteria.
- Match runtime/dependency pins when comparing controllers. Actual-client
  qualification now covers missing tabs, uncertain actions, fresh references,
  isolated concurrent servers, cleanup and synthetic retention. Carry those
  concrete contracts into the recipe; real authenticated retention remains open.
- Borrow compact snapshots and provider-aware capability descriptions. Keep our
  foreground, secret-entry and ownership policy; do not infer their enforcement
  from an upstream tool schema or a server's HTTP status.

The production skill is unchanged. Its eventual creation still uses the plan's
writing-for-agents gate. Source notes and file-blob receipts remain in ignored
`.scratch/browser-comparison/`.
