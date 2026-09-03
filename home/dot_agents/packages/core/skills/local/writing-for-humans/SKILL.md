---
name: writing-for-humans
description: Write or rewrite prose that people will read (replies, docs, READMEs, commit and PR text, messages, reports) so it is clear, specific, and free of AI tells while keeping the writer's voice. Apply by default to final replies unless told to skip. Routes to Strunk for structure, the seven anti-slop rules for register, and voice and genre checks for fit.
---

# Writing for Humans

One entry point for prose. Three bodies of guidance live under `references/`
and this file says which to load, in what order, and when a short pass is
enough.

- `references/writing-clearly-and-concisely/`: Strunk's *Elements of Style*.
  Sentence and paragraph structure. The full text is about 12,000 tokens.
- `references/write-for-humans/`: the seven anti-slop rules in order, voice
  preservation, an exhaustive pattern catalog (`REFERENCE.md`), and a
  `prose-humanizer` subagent for long rewrites.
- `references/better-writing/`: audience and genre fit. Voice dials, genre
  tells and exemptions, an anti-slop audit, and a delivery preflight.

## Scope

Prose humans will read: docs, READMEs, PRs, commit messages, issues, email,
Slack, reports, and any reply the user reads as text. Leave code, config,
data, quoted text, front matter, and structured output alone. When the user
asked for a specific format, keep it.

## Default pass (every reply)

Do this from memory. Do not load references for a normal reply.

1. Lead with the answer. Delete openers, closers, throat-clearing, and
   sentences that announce what the next sentence will do.
2. Kill negative parallelism: "not X, it's Y", "not just X but Y".
3. Be specific instead of significant. Swap inflating words (pivotal,
   crucial, robust, seamless, testament, landscape) for a fact or nothing.
4. Plain verbs: "is", "has", "does", or the active verb hiding in the noun.
5. End sentences at the fact. Cut "-ing" tack-ons that editorialize.
6. Earn adjectives and em-dashes. At most two em-dashes per page. No
   bold-label bullets, no decorative Unicode, no emoji unless the medium
   expects them.
7. Vary rhythm. One tricolon per short piece at most; break anaphora and
   elegant variation.

Then run the self-edit checklist below and return the text with no preamble.

## Full pass (documents, rewrites, anything the user will edit or publish)

Work in this order. Earlier passes remove material later passes would have
to rewrite.

1. **Structure first.** Read `references/writing-clearly-and-concisely/SKILL.md`
   for the rule list; load `elements-of-style.md` only for a long document
   or when a structural problem needs the source. Active voice, one topic
   per paragraph, topic sentence first, omit needless words, emphatic words
   at the end.
2. **Register second.** Read `references/write-for-humans/SKILL.md` and apply
   the seven rules in order. For heavy slop or a long draft, load
   `REFERENCE.md` for the full catalog, or dispatch
   `references/write-for-humans/agents/prose-humanizer.md` with the draft
   when context is tight.
3. **Fit last.** When audience, channel, or genre matters, or the user says
   "humanize", "de-AI", or "make this sound less like a bot", read
   `references/better-writing/SKILL.md`. Set the read (genre, audience,
   tone, outcome) with `references/better-writing/references/voice-and-context.md`,
   check genre exemptions in `genre-tells.md`, and finish with `preflight.md`.

Rewrite mode: read the whole draft, judge light versus heavy slop, cut
first and rewrite second, then diff against the original and revert any
edit that changed meaning or flattened the writer's voice.

## Voice and guardrails

- Only subtract and simplify. Never add facts, quotes, names, numbers,
  next steps, or opinions the source does not hold.
- Keep the author's rhythm, contractions, first person, swearing, and
  rough edges. Lowercase stays lowercase.
- Editing is not fact-checking. Flag a doubtful fact in a note; do not
  silently correct it.
- Preserve code identifiers, API names, product names, regulatory terms,
  and exact UI labels.
- If two rewrites are equally good, pick the shorter one.

## Tables and terminal output

When the text lands in a terminal, TUI, chat transcript, or narrow pane,
keep tables physically readable: short columns, split wide tables, prefer a
list when a table would wrap. Rendered Markdown files can use normal tables
with short column names.

## Self-edit checklist

1. Does the first sentence make a claim, or announce? Announce means cut.
2. Search " not " and "isn't"; kill any not-X-but-Y construction.
3. More than two em-dashes in the piece? Reduce.
4. Inflating vocabulary present? Replace with a fact or delete.
5. Sentences ending in an editorializing "-ing" phrase? Cut the phrase.
6. Signposted closer or a last sentence that restates the first? Cut.
7. Count "X, Y, and Z" lists. Over one per 500 words: convert the weakest
   to prose.
8. Bold-first bullets? Convert to prose or plain bullets.
9. Three consecutive sentences with the same opening subject? Break it.
10. Did anything change meaning or voice? Revert it.
