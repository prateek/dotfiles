# Write an implementation plan

Use these additions to the entrypoint when a document directs future implementation.
A useful plan adds a design to the request and makes acceptance inspectable.

## Preserve the contract

Keep explicit requirements distinct from assumptions and selected approaches.
Quote exact wording when it changes scope or acceptance. Preserve user-required
ordering and real evidence gates. An answer becomes a decision in its owning
section, with useful rationale; resolve the corresponding open question.

Explain the mechanism, affected interfaces, ownership, and material alternatives.
Leave local implementation choices flexible when they cannot change the agreed
outcome. Background, Goals, Non-goals, and Proposal are a starting example, not
mandatory headings. Add rollout, risks, or open decisions when they contain work.

## Define verifiable deliverables

Give each deliverable a result, scope, prerequisite, and acceptance evidence.
Name the dependency state it needs: an agreed interface, working-branch code,
merged code, deployed behavior, or another concrete condition. Use the earliest
useful end-to-end slice when the work has one. Keep necessary blockers ahead of
polish without inventing a fixed task count or banning legitimate gates.

For example, an opt-in output-format change can first connect the option parser
to the renderer for one representative record while preserving default output.
That slice requires the parser-to-renderer contract and a test through that
boundary. Its acceptance is the requested new output plus unchanged default
behavior. Wider input coverage and documentation follow from the same contract.
A merge or deployment is required only when the user's acceptance includes it.

Acceptance for an integration slice must exercise the boundary it claims, not
just its components separately. Trace the actual caller. If no caller connects
the components yet, name that limit and the planned connection instead of
describing intended wiring as existing behavior. Keep checks for distinct
interfaces separate when they have different error or success contracts.

Finish when a fresh implementer can identify the first useful result, its
prerequisites, and the evidence that would establish it. A task list that merely
restates the request has not supplied the design.

## Revise the remaining work

When evidence or requirements change, reconcile the mechanism, affected
deliverables, their dependencies, acceptance, and examples together. Remove
conflicting old instructions and resolve answered questions. Integrate
plan-affecting review feedback in the same change.

Repair ordinary sequencing defects within authorized scope. Ask when the repair
changes intent, authority, or a material constraint. Finish when the remaining
plan describes one coherent path and preserves unrelated valid edits.

## Keep progress distinct

Reuse the repo's existing progress location. If none is declared, append dated
entries under one Progress heading at the end of the plan. Create it when there
is progress to record. Long execution can warrant a separate log, but no filename
or extra file is mandatory.

Entries record changed state and supporting evidence. Keep the specification
separate from those entries. Completion means the agreed acceptance criterion,
which might be a reviewed plan, tests, a merge, deployment, or a physical check.
Let the existing lifecycle owner interpret that evidence when setting document
state. Planning completion alone does not authorize implementation.

## Ask the fresh reader

Ask which decisions would stop implementation, what the first useful deliverable
is, which prerequisites it needs, and what would prove it complete. For an
integration project, check that later polish has not displaced the first required
slice. A reader's guess is not evidence that an unstated decision was settled.
Correct missing context before calling the plan ready.
