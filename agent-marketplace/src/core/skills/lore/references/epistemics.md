# Epistemics

Adapted from the `why` skill's epistemics in Cursor's pstack plugin,
Copyright (c) 2026 Lauren Tan, used under the MIT License
([license text](../licenses/pstack-MIT.txt)).

Code shows what it does, not why it exists. The why lives in commits, PRs,
tickets, docs, conversations, sessions, and telemetry, all incomplete and
sometimes contradictory. Grade every claim so the reader knows what to act on.

## Tiers

Every claim sits in exactly one tier, and the tier sets its phrasing.

1. **Direct.** Something an author wrote answers the question: a PR body, a
   ticket, a code comment, a design doc, a chat message from the decider.
   Phrase it plainly, in the present tense, with the citation adjacent: "This
   exists because X (link: 'quote')."
2. **Supported.** Several independent indirect items converge, though none
   states it. Name each item: "The evidence points to X: A, B, and C."
   Copies of one source (a pasted brief, a forwarded message) count once.
3. **Inferred.** A reasonable reading the record does not state. Show the
   chain and hedge it: "Given A and B, C seems likely because D."
4. **Speculative.** A plausible hypothesis on thin evidence, where other
   explanations fit as well. "One possibility is X; no direct evidence."
   These usually sit beside competing hypotheses.
5. **Unknown.** You looked and could not find out. Say exactly where and with
   what terms: "Searched the tracker for A and B, the 6 PRs touching this file
   since 2024, and chat for the PR URL; none gives a reason."

Present-state claims from `runtime` take the same tiers: a query result is
Direct evidence of the measurement, not of the motive behind the code.

## Phrasing

Reserve **confidence words** for Direct and Supported claims, each with its
citation adjacent: "because", "the reason is", "was designed to", "fixes",
"the team decided". Use **hedges** for Inferred and Speculative claims:
"appears to", "likely", "suggests", "is consistent with", "may have been".
Write "the evidence suggests" in place of personal belief, and state the
evidence in place of "obviously" or "clearly".

## Discipline

- **Code is not evidence of its own intent.** Read code to learn what the
  target is; claim intent only where someone stated it.
- **Resist rationalization.** Code that makes sense today may have been
  written for reasons that no longer hold, or were wrong then. A consistent
  pattern may be copy-paste.
- **Absence is a gap, not a finding.** "Nobody mentioned security" does not
  mean security was not a concern.
- **Test the user's hypothesis.** A guess embedded in the question is one
  candidate. Confirm or refute it with citations, and present what the
  evidence supports either way.
- **Keep contradictions visible.** When sources disagree, cite both and say
  what would settle it. A ticket's motive and a PR's framing can both be true.
- **An honest Unknown is valuable.** It tells the reader the answer is not in
  the obvious places and who to ask next: the author, the owner, the team.

## Final check

Before reporting, check every claim:

- Each claim has one tier, and its phrasing matches that tier.
- Each Direct or Supported claim has a citation, and each Direct citation was
  re-opened and says what the claim says.
- No claim cites code as evidence of its own intent.
- The report names at least one gap, or states why the record was complete.
