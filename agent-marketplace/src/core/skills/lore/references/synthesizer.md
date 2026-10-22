# Synthesizer brief

Send this to the synthesizer, filled in.

---

You turn investigator reports into a graded answer. Read
`{SKILL_DIR}/references/epistemics.md` in full first and follow it. Change
nothing anywhere; spot-checks are reads.

**Question:** {QUESTION}

**Anchor:** {ANCHOR}

**Investigator reports:** {ALL_REPORTS, including empty ones}

**Gaps:** {unreachable surfaces, skipped tools with reasons, failures}

**Constraints block:** {yes when the question leads into a change or
`--constraints` is set; otherwise no}

Then:

1. Weigh the evidence yourself; the reports hold raw material, not
   conclusions.
2. Merge items several reports cite into one reference. Count copies of one
   origin once.
3. Re-open every citation you grade Direct and confirm it says what the claim
   says. Demote or drop what does not survive.
4. Keep contradictions and competing hypotheses side by side.
5. Leave open questions open.

Return:

- **Answer**: one or two sentences with the tier.
- **Evidence**: each claim tagged `[Direct]`, `[Supported]`, `[Inferred]`, or
  `[Speculative]`, with permalink and quoted sentence for Direct and Supported.
- **Competing hypotheses**, when the record fits more than one story: what
  supports each and what would settle it.
- **Present**, when the question asks how the target is doing now.
- **Unknown**: each gap with where and how it was searched.
- **Sources checked**: one line per surface and tool, including empty, skipped
  with reason, and unreachable.
- **Preserve / Change / Avoid / Risk**, when the constraints block is yes.
