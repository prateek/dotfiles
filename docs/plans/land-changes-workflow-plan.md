---
status: archived
doc_type: plan
created: 2026-09-22
updated: 2026-09-22
closed: 2026-09-22
status_detail: "Implementation complete; publication uses the separately invoked landing procedure."
current_guidance:
  - ../../agent-marketplace/packages/review/skills/land-changes/SKILL.md
  - ../runbooks/dotfiles-landing.md
related:
  - ../adr/0031-discovered-landing-workflows.md
  - ../runbooks/dotfiles-landing.md
---

# Discovered landing workflows

Replace the landing skill's fixed review/test/deploy enums with discovered
methods, actions, and gates. Preserve a short ordinary landing path and expose
granular choices through natural language and named selectors. The accepted
decision is [ADR 0031](../adr/0031-discovered-landing-workflows.md).

## Scope

- Publish the revised entrypoint and conditional preference, direct-Git,
  host-policy, and history references.
- Implement a data-only preference resolver: canonical repository/target
  identity, concrete choices, explicitly dynamic groups, stale-choice detection,
  and deliberate v1 migration. It never executes workflow commands.
- Align dotfiles follow-up effects and explicit hook overrides with that model.
- Preserve Git recovery and preference storage guarantees; add observable
  decision cases and bump the review plugin version.

## Evidence

The design audit found 83 deduplicated named invocations across the three archived
hosts and local transcripts, plus five additional activations. Eight named entries
had command history only. Remote freshness gaps and excluded/oversized transcripts
limit coverage; this is not a count of successful landings or every historical run.
Most examples were dotfiles, with two successful Spacejunk PR routes.

The decisive failures were inconsistent meanings of saved deploy/test flags,
an apply after a bare invocation, and another run changing from "without apply"
to applying without a new instruction. The design therefore records the source
and scope of follow-up authorization and retains that plan through execution.
Standing decisions and unfinished authorized actions remain valid within scope.

## Implementation and validation

Review plugin 2.0.0 implements the entrypoint, conditional references, named-choice
resolver, and scoped dotfiles guidance. The old fixed-enum CLI has no aliases;
v1 preference records remain readable without granting new authority.

The package check passed all 43 tests and deterministic rebuild verification.
The helper CLI cases preserve identity, malformed-input, concurrent-write,
atomicity, and isolation guarantees. Named choices and inert v1 migration replace
obsolete enum assertions. Disposable Git fixtures demonstrate that the old zsh
refspec fails and the corrected command publishes exactly the candidate without
following annotated tags. Chezmoi dry-runs passed for ci, personal, and work.

Claude CLI resolved `--model opus` to `claude-opus-5-5`. Thirteen selected decision
cases ran with expected answers withheld. They exposed an incomplete all-hooks
control and an ambiguous pre-publication deployment check. Both were clarified;
three focused scenarios, including seven variants, were rerun and manually checked.
The complete 60-case evaluation set was not run. Decision simulations do not prove
host policy enforcement, deployment, or native client activation.

The repository package validator accepts the supported `argument-hint` frontmatter;
the generic skill-creator quick validator rejects that existing extension. Package
validation is authoritative for this payload. Docs lifecycle validation and diff
whitespace checks are part of the final commit preparation.

Implementation is complete. Publication follows the separately invoked landing
procedure, including its read-only preview. Applying machine state and activating
the new installed plugin are outside this request. Current operation belongs to
the [skill](../../agent-marketplace/packages/review/skills/land-changes/SKILL.md)
and [dotfiles runbook](../runbooks/dotfiles-landing.md).
