---
name: doc-coauthoring
description: Guide users through co-writing substantial documentation, proposals, technical specifications, and decision documents. Use when the user asks to write, draft, or co-author a doc, proposal, spec, PRD, RFC, design doc, or decision doc, or is starting a substantial writing task. The workflow gathers context, drafts and refines section by section, then tests the document with a fresh reader.
---

# Co-author a document

Use this workflow for substantial documents such as proposals, PRDs, technical
specifications, RFCs, and decision documents. Offer the user the three stages:
gather context, draft and refine the document, then test it with a fresh reader.
Explain that this checks whether the document works for its intended audience,
including readers who may give it to an AI assistant. Ask whether they want this
workflow or prefer to work freeform. If they decline or ask to skip a stage, follow
their choice and continue freeform.

For implementation specifications and PRDs, also explain that the process makes
the first end-to-end functional slice and its blockers explicit, keeps later
polish subordinate to those blockers, and keeps execution updates out of the
stable specification.

## 1. Gather context

Start by asking for the document type, primary audience, intended impact, required
template or format, and other constraints. The user can answer briefly or provide
an unstructured context dump.

For implementation specifications and PRDs, also establish:

- The first functional vertical slice and the risky integration it must exercise.
- The blockers and their order for delivering that slice.
- Whether any work may outrank those blockers, and what work is deferred until
  the slice works.
- Whether autonomous implementers will use the document as a stable spec, and
  where execution updates belong. Prefer a separate `IMPLEMENTATION_LOG.md`.

If the user provides a template or names a document type, ask whether they have
a template to share and read any supplied file or link. For an existing shared
document, use the available integration to read it. Check images for missing
alt text; explain that readers using Claude cannot interpret images without it,
and ask whether the user wants alt text generated. If they agree, ask them to
paste each image into chat so it can be described.

Invite the user to share background, related discussions and documents, rejected
alternatives, organizational context, timelines, architecture, dependencies, and
stakeholder concerns. They can provide a stream-of-consciousness dump, point to
channels or threads, or share document links. Mention available integrations
that can retrieve this context. If there are no integrations and the user is in
Claude.ai or the Claude app, suggest enabling the relevant connectors.

When they point to a channel or document, say you will read it before using an
available integration. If you cannot access it, explain that and ask them to
enable a connector or paste the relevant content. When a project or entity is
unknown, ask whether connected tools should search for it and wait for their
answer before searching. Track what is known and what remains unclear as context
arrives.

After the initial dump or substantial context, ask 5–10 numbered questions
targeted at the remaining gaps. The user can answer in shorthand, share more
sources, or continue dumping context. Context is sufficient when you can ask
about edge cases and trade-offs without needing basic facts explained. Then ask
whether they have more context or are ready to draft.

## 2. Refine and draft

Build the document section by section. Begin with the section that has the most
unknowns—usually the core proposal or technical approach—and leave summaries
until last. If the structure is clear, ask which section to start with. Otherwise,
propose 3–5 sections suited to the document type and template, then ask whether
the user wants to adjust them.

For implementation specifications and PRDs, draft the first functional slice,
its current blockers, and the critical path before later polish. Prefer milestones
that deliver an early end-to-end thin slice over a subsystem-by-subsystem plan
that delays it, unless the user explicitly wants that structure. Include explicit
`Current Blockers` and `Critical Path` sections. Make clear that lifecycle polish,
seam work, trace expansion, and fidelity cleanup cannot outrank unfinished
blockers for the first slice. Keep execution history in `IMPLEMENTATION_LOG.md`;
do not add a “completed in this slice” or similar work-log section to the top of
the spec.

Create an initial scaffold with every agreed section and short placeholders. If
artifact access is available, use `create_file`, then share the artifact link.
Otherwise, create an appropriately named Markdown file in the working directory
and report its filename.

For each section, follow this loop:

1. Announce the section and ask 5–10 focused questions. The user may answer in
   shorthand.
2. Brainstorm 5–20 candidate points, scaled to the section's complexity. Look
   for relevant context that may have been missed and useful new angles. Offer
   to brainstorm more.
3. Ask what to keep, remove, or combine, with brief reasons where useful. Give
   examples such as “Keep 1, 4, 7,” “Remove 3 (duplicates 1),” or “Combine 11
   and 12.” If feedback is freeform, infer the requested edits and proceed.
4. Ask whether anything important is missing from the selected material.
5. Draft the section from the user's choices. Use `str_replace` to replace its
   placeholder. After the first draft, ask the user to request changes instead
   of editing directly; their examples teach the style to use in later sections.
   Share the artifact link after each artifact edit, or confirm the filename
   after each file edit.
6. Apply feedback with `str_replace`; do not reprint the whole document. If the
   user edits the document directly and asks you to read it, note their choices
   and carry those preferences into later sections. Iterate until they are
   satisfied.

After three consecutive iterations without a substantial change, ask whether
anything can be removed without losing important information. When a section is
complete, confirm it and ask whether to move to the next one.

Once about 80% of sections are complete, re-read the whole document for flow,
consistency, repetition, contradictions, generic filler, and sentences that do
not carry weight. When all sections are drafted, review overall coherence,
flow, and completeness, then ask whether the user wants reader testing or more
refinement. For implementation specifications and PRDs, verify that the first
slice is unambiguous, blockers are ordered, a fresh implementer would prioritize
them over later polish, and the spec stays separate from the execution log.

## 3. Test with a fresh reader

Explain that a reader test checks whether someone without this conversation's
context can use the document. If sub-agents are available, run the tests directly
with a fresh agent that receives only the document and each question. Otherwise,
guide the user through testing in a fresh Claude conversation.

### With sub-agent access

1. Predict 5–10 realistic questions readers might ask to find or use the
   document, and share the list with the user.
2. Test each question with a fresh Claude instance that receives only the
   document and question. Report what it answered correctly or missed.
3. Ask a fresh reader to identify ambiguity, unsupported assumptions, and
   contradictions, then summarize the findings.

### Without sub-agent access

1. Ask for realistic questions readers might ask to find or use the document,
   then generate 5–10 questions.
2. Have the user open a fresh conversation at <https://claude.ai>, provide the
   document or a connected shared-document link, and ask those questions.
3. For each answer, ask the reader to note ambiguities and assumed context.
   Also ask: “What in this doc might be ambiguous or unclear?”, “What knowledge
   or context does it assume?”, and “Are there internal contradictions or
   inconsistencies?”

For implementation specifications and PRDs, both testing paths must also ask a
fresh reader:

- “What are the first five implementation tasks?”
- “What is the first functional vertical slice?”
- “Is there any later polish work this doc might prioritize ahead of that
  slice?”

Report whether the reader identified the intended slice and blocker-first order.
Ask the user exactly: “If I hand only this doc to a fresh implementation agent,
will it clearly prioritize the earliest blocker for the first functional
vertical slice, or does the doc still allow later polish to outrank unfinished
blockers for that slice?” If the answer is not a clear yes, or the reader's first
tasks do not match the intended slice, return to refinement.

When readers struggle, report the specific gaps, fix them with the user, and
repeat the relevant tests. Testing is complete when fresh readers answer
consistently, reveal no new gaps or ambiguities, and—when applicable—identify the
intended first slice and blocker-first order.

## Finish

After reader testing passes, say so. Recommend a final read by the user, a check
of facts, links, and technical details, and a check that the document achieves
the intended impact. For PRDs and implementation specifications, remind them to
put future execution updates in `IMPLEMENTATION_LOG.md`.

Ask whether they want one more review or consider the work done. If they request
another review, provide it; otherwise, announce completion. Suggest linking the
conversation in an appendix if useful, using appendices for depth that would
bloat the main text, and updating the document as real-reader feedback arrives.

## Keep the process usable

- Be direct and procedural; briefly explain rationale when it changes what the
  user should do. Execute the agreed workflow without selling it.
- If the user wants to skip a stage, ask whether they would prefer to skip the
  workflow and write freeform; honor their choice.
- If the user is frustrated by the pace, acknowledge it and suggest ways to
  move faster.
- Ask about missing context as it arises instead of letting gaps accumulate.
- Use `create_file` for full-section drafting and `str_replace` for edits. Do
  not use artifacts for brainstorming lists; handle those in conversation.
- Keep iterations meaningful and prioritize document quality over speed.
