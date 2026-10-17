---
status: active
doc_type: research
created: 2026-10-16
updated: 2026-10-16
related:
  - ../plans/browser-runtime-controller-plan.md
  - ../plans/browser-skill-plan.md
  - ../../agent-marketplace/packages/utils-agent/skills/browser/SKILL.md
status_detail: "Adversarial review of the runtime/controller plan against local skill source, agent-browser v0.38.2, and Obscura main/v0.2.4. Plan amended in place; no Obscura runtime trial performed."
---

# Browser runtime/controller plan review

Adversarial review of [the plan](../plans/browser-runtime-controller-plan.md)
on 2026-10-16. Each finding was checked against source before being kept;
refuted candidates are listed at the end.

## Later runtime evidence

The [local evaluation](obscura-browser-evaluation.md) supersedes source-only
uncertainty where it has an executed result. Both CDP controllers pass basic
forms; release MCP defects and pinned-main fixes are recorded there. GitHub's
release asset API exposes SHA-256 digests despite the absence of separate
checksum files, correcting finding 3's original assumption. Retain this review
as the design-review record, not the authority for current runtime support.

## Evidence base

| Source | Ref | How read |
| --- | --- | --- |
| Local browser skill | this worktree, dirty | `SKILL.md`, `policy.md`, `auth.md`, five driver files, `certificate.md`, `agents/openai.yaml` |
| Obscura | `main` @ [`bd95294`](https://github.com/h4ckf0r0day/obscura/commit/bd9529418b7fa975b50eabeac415cfaaa865a588) (2026-10-16) | `ask src github:h4ckf0r0day/obscura`; docs, `crates/obscura-cdp`, `crates/obscura-mcp`, `skills/obscura` |
| Obscura release | [`v0.2.4`](https://github.com/h4ckf0r0day/obscura/releases/tag/v0.2.4) → commit `1fccab2` (2026-10-04) | GitHub API: 20 archive assets, no checksum or attestation files; `release.yml` stages binaries only |
| agent-browser | [`v0.38.2`](https://github.com/vercel-labs/agent-browser/tree/v0.38.2) (installed version) | `ask src npm:agent-browser@0.38.2`; `cli/src/native/**` |
| Local tools | `agent-browser 0.38.2`, Orca `1.4.224`, `mcporter` (mise); `obscura`, `playwright` absent | `which`, `--version`, `orca status --json`, `mcporter call --help` |

Nothing was executed against Obscura. "Source-supported" below means read in
code; "unknown" means neither code nor a run settles it.

## Findings

Severity: **High** blocks implementation or would publish a false claim;
**Medium** causes rework or a wrong route; **Low** is drift.

### 1. Direct-CDP evidence strengthens an existing deferral (Medium)

The original plan already deferred agent-browser/Obscura qualification and
explicitly said basic Playwright connectivity was insufficient. The review's
initial High-severity interpretation overstated that defect. The useful new
evidence is that agent-browser `0.38.2` uses a native Rust CDP client, so each
required operation needs its own compatibility check.

Source inspection found `Page.bringToFront` calls in
`cli/src/native/browser.rs`. Tab switching at line 1681 deliberately ignores
that command's error (`let _ =`); the explicit `bring_to_front` method at line
1892 propagates it. Obscura's inspected dispatcher has no implementation of
that command and rejects unknown methods. This supports a capability gap,
not the initial claim that tab switching necessarily fails. A string-diff
count also mixes commands and events and is not a compatibility result.

Failure scenario: a recipe requires an operation whose error is propagated,
then discovers at runtime that Obscura does not implement it. The affected
user-facing commands remain unqualified until exercised.

Change: section C names the native client and the gap; blocker 5 records the
need for operation-specific evidence. The route remains deferred.

### 2. Obscura `Target.setAutoAttach` is a no-op (Medium; compatibility impact unverified)

`crates/obscura-cdp/src/domains/target.rs` line 224: `"setAutoAttach" => Ok(json!({}))`.
The effect on the selected Playwright version needs source inspection and a
live discovery test; this review did not fetch Playwright's implementation.
Obscura's upstream examples create pages explicitly (`browser.contexts()[0] ||
newContext()` then `newPage()`), which is consistent with that no-op.
Plausible failure scenario: a recipe relying on `context.pages()` after
connect sees an empty list. This is a test hypothesis, not an observed result.
Change: section C instructs explicit page creation and a discovery check.

### 3. Artifact verification must include release API metadata (corrected)

The review initially inferred that absence of checksum files and workflow steps
meant no upstream checksum existed. The installation experiment refuted that:
GitHub's asset API exposes SHA-256 `digest` fields. Both standard and stealth
archives were independently matched against them. The plan now directs checking
that metadata; a local-only hash is a fallback identity record, not equivalent
verification. Version authority remains `obscura --version`, because the
workspace Cargo.toml package version can differ from the injected build version.

### 4. Native MCP integration needs a lifetime check (Medium)

The plan deferred "confirm the actual client's launch path" without saying
what candidates exist. Facts: `home/dot_codex` and `home/dot_claude` manage no
stdio MCP server; `mcporter` is declared (`home/dot_config/mise/conf.d/mcporter.toml`)
and `mcporter call --stdio <command>` runs ad-hoc stdio servers. Unknown:
whether the ad-hoc server survives between `call` invocations without the
`mcporter daemon`. If not, the navigate-then-act model Obscura's MCP server
assumes (`BrowserState.active_tab`, `crates/obscura-mcp/src/lib.rs:63-135`)
is unusable through it.
Failure scenario: each `mcporter call` spawns a fresh `obscura mcp`; the
snapshot call sees `about:blank`.
Change: section B lists both candidates with the two-call trial as the gate;
blocker 4 restated.

### 5. Orca readiness gate affects existing routes, not only Obscura (Medium)

`SKILL.md` step 2 polls `orca status --json` for up to one minute whenever
`ORCA_WORKTREE_ID` is set, before any route, including browser-harness live
attach and fetch/API reads that never touch Orca's embedded browser. The plan already proposed dependency-scoped readiness checks; the review
makes the implications for existing routes explicit.
Change: phase 2 names the affected routes and keeps the regression check
requirement.

### 6. `references/backends.md` risks duplicating the router (Medium, judgment)

The plan mandated a new inventory file. With five recipes and at most one new
runtime, the per-recipe contract header plus the router table already answer
"which combinations are supported?" A second table restating router rows is
the duplication the writing-for-agents skill warns about and one more file to
keep current. Not refuted: if Playwright ends up carrying both its engines and
Obscura CDP, one table may earn its place.
Change: downgraded to a conditional recommendation with the condition stated.

### 7. Keep Jev out of the regular browser skill's acceptance (Low)

The earlier acceptance table required the skill to explain Jev retirement.
That added maintenance unrelated to browser-runtime/controller separation.
The row was removed. The user subsequently chose relocation into the existing
`experimental` plugin in a separate child worktree instead of the proposed
standalone archive. This review and plan impose no Jev maintenance work.

### 8. Fixture row omitted the private-network flag (Low)

A local JS fixture is loopback; Obscura blocks loopback by default
(`skills/obscura/SKILL.md:76-78`). The CLI fixture row now says so, so the
first run does not fail on `Access to private/internal IP address`.

### 9. Mutable refs and missing evidence pins (Low)

Source references pointed at `main` blobs. Replaced with commit permalinks for
`bd95294`, added the release tag, the agent-browser tree, and the exact `ask`
spec for an immutable re-read.

### 10. Drift the plan did not list (Low)

`agents/openai.yaml` and `home/dot_agents/docs/browser.md` both say "driver";
`auth.md` pins a `--restore` behavior to agent-browser `0.38.1` while `0.38.2`
is installed. Added to the file table so vocabulary changes land everywhere.

## Writing-for-agents gate

Added as a named section in the plan, between the file table and routing.
Seven checks, each with a done condition: context pointers, progressive
disclosure, single authority, ordered steps with completion criteria,
positive phrasing, invocation choice, post-edit validation. Milestone 2 now
depends on it. Applied to this review's own plan edits: the gate is in-file
reference reached in order, `backends.md` was demoted on the single-authority
test, and new instructions are phrased as actions with a stated condition.

## Refuted or not retained

- "Obscura's HTTP MCP is the right shared mode." Refuted by the plan itself
  and `http.rs`; the plan already prefers stdio per task. No change.
- "Phase 1 can drop the harness column." The Orca named-tool redirect and the
  live-Chrome exception are harness-specific today; collapsing them is a
  behavior change. Kept phase 1 terminology-only.
- "Playwright driver should document CDP attach now." No local Playwright
  install, no run; documenting it would publish an unqualified route. Kept
  conditional.
- "The plan should pick `ubi:` definitively." mise asset matching against four
  suffixed variants is untested here; left as a recommendation with the
  scratch fallback.

## Unresolved decisions

1. Adopt the runtime/controller vocabulary (needs an ADR when accepted).
2. Whether an Obscura route is wanted at all before the CLI trial produces
   evidence.
3. MCP client: harness config versus `mcporter`; the two-call trial decides.
4. `backends.md`: create only under the stated condition.
5. Scoping the Orca readiness gate: accept the behavior change for
   browser-harness and fetch routes inside Orca.

## Readiness

At review time the plan was ready for a terminology refactor and scratch
trials, not publication. Those trials have since run; use the linked evaluation
and revised plan for current readiness and remaining adoption gates.
