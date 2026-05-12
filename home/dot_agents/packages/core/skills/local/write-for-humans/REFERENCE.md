# Write for Humans — Reference

Full pattern catalog, vocabulary tables, and detection examples. Load this when rewriting heavy-slop drafts, when running a detection pass over a long piece, or when `SKILL.md` doesn't have the specific tell you're looking for.

## Table of contents

1. [Structural tells](#1-structural-tells)
2. [Register and voice tells](#2-register-and-voice-tells)
3. [Punctuation and typography tells](#3-punctuation-and-typography-tells)
4. [Vocabulary watchlist](#4-vocabulary-watchlist)
5. [Opener and closer tells](#5-opener-and-closer-tells)
6. [Structure-of-document tells](#6-structure-of-document-tells)
7. [Detection and scoring](#7-detection-and-scoring)
8. [Positive patterns — what human prose sounds like](#8-positive-patterns--what-human-prose-sounds-like)

---

## 1. Structural tells

### Negative parallelism
The "not X, it's Y" / "not X — Y" construction. AI's single most commonly identified tell. Also: "Not only X but Y", "Not X. Not Y. Just Z.", "The X? A Y."
- **Bad:** "It's not a bug. It's a feature."
- **Better:** "The behavior is intentional."

### Rule-of-three abuse (tricolon stacking)
Every list is three items. Every argument has three points. One tricolon per document is fine. Three stacked is a tell.
- **Bad:** "Innovation, inspiration, and insight drive the team. They build products, platforms, and people."
- **Better:** "The team builds plumbing that other teams turn into products."

### Anaphora abuse
Three-plus consecutive sentences with identical openers.
- **Bad:** "They built engines. They built walls. They built silos."
- **Better:** "They built infrastructure — engines, walls, silos — but never the product on top."

### Participial tack-ons
"-ing" phrases appended to a complete sentence, editorializing.
- **Bad:** "The population grew 12%, reflecting broader demographic trends."
- **Better:** "The population grew 12%."
- Also: "highlighting its importance", "underscoring the significance", "ensuring relevance", "contributing to heritage", "solidifying its position", "marking a shift".

### Rhetorical Q&A
Asking a question nobody asked, then answering for drama.
- **Bad:** "The result? Catastrophic."
- **Better:** "The result was a 40% outage."

### Listicle-in-a-trenchcoat
Prose disguising enumeration.
- **Bad:** "The first wall is access. The second wall is permissions. The third wall is approvals."
- **Better:** "Three things block this: access, permissions, approvals."

### Elegant variation (synonym cycling)
An RLHF artifact: repetition penalty pushes the model toward synonyms that don't fit.
- **Bad:** "The protagonist… the hero… the central figure… the main character…"
- **Better:** Repeat "the protagonist", or use "she"/"he"/"they".

### False ranges
"From X to Y" where X and Y aren't endpoints of a real scale.
- **Bad:** "From biology to politics, the implications are profound."
- **Better:** "The implications touch biology, ecology, and urban planning."

### Copula avoidance
Replacing plain "is/are/has" with inflated substitutes.
- **Bad:** "The gallery serves as an exhibition space." / "The library boasts 2M volumes."
- **Better:** "The gallery is an exhibition space." / "The library has 2M volumes."

### Passive voice hiding the actor
- **Bad:** "Mistakes were made. The decision was finalized."
- **Better:** "I missed the deadline. The board signed off on Thursday."

### False agency / inanimate verbs
- **Bad:** "The complaint becomes a fix." / "The data tells us a story."
- **Better:** "The on-call engineer fixed it that Thursday." / "The logs show a single failing request."

### Fragmented headers
Heading immediately followed by a single-line restatement.
- **Bad:** `## Performance\nSpeed matters.`
- **Better:** Delete the restatement.

### Hedging clusters
"Could potentially possibly". Pick one modal.

### Fractal summaries
Summary per subsection, summary per section, summary of the doc. Delete the intra-doc summaries.

### "Despite challenges" formula
Acknowledge problem → dismiss it → forced optimism. Drop the arc.
- **Bad:** "Despite these challenges, the initiative continues to thrive."
- **Better:** "Traffic worsened after 2015; a drainage project started in 2022."

### Grandiose stakes inflation
Every claim rises to world-historical.
- **Bad:** "This will fundamentally reshape civilization."
- **Better:** "This will change how teams estimate."

### Historical-analogy stacking
Rapid-fire company name-drops for false authority.
- **Bad:** "Apple didn't build Uber. Stripe didn't build Shopify. Twilio didn't build Segment."
- **Better:** "Platforms rarely build the apps that run on them; see the App Store."

### Invented concept labels
`-paradox`, `-trap`, `-creep`, `-divide` slapped on a domain word.
- **Bad:** "The supervision paradox means review bandwidth scales worse than output."
- **Better:** "Review bandwidth doesn't scale with throughput — at high output you run out of reviewers before you run out of work."

---

## 2. Register and voice tells

### Sycophantic openers
"Great question!", "Certainly!", "Of course!", "Excellent point!" Delete.

### Corporate cheer
LinkedIn-voice forced enthusiasm.
- **Bad:** "Excited to share this transformative update!"
- **Better:** "Here's what changed."

### Flattery sandwiches
"While traditional methods have merit, modern approaches offer…" Cut the setup; state the position.

### Fake authenticity signals
"Here's the thing:", "Here's the truth:", "Let me be clear:", "But honestly?" Cut.

### Performative intimacy
"I promise, they exist", "creeps in", "makes my chest tight". Cut.

### False vulnerability
Polished, risk-free self-awareness.
- **Bad:** "I'll admit — I'm openly in love with this model."
- **Better:** Name a specific concrete mistake.

### Manufactured personality
- **Bad:** "That got old fast. So I built…"
- **Better:** Describe the situation plainly.

### Vague attributions
"Experts argue", "industry reports suggest", "several publications have noted". Name the source or cut the claim.

### Defensive hedges
"happy to do the legwork", "zero effort on your end", "just let me know if". Rewrite without the reassurance scaffolding.

### Knowledge-cutoff disclaimers
"While specific details are limited in available sources" → "Unknown." / "I don't know."

### Moralizing / safety padding
"It is crucial to approach this topic with sensitivity", "We must remember the human cost". Cut. If the facts are serious, the reader notices.

### Telling-not-showing emphasis
"This is genuinely hard", "This is what leadership actually looks like". Cut. Show the specific thing.

### Lazy extremes
"Every", "always", "never", "everyone", "nobody". Replace with specifics when possible.

### Cutesy reassurance
"And that's okay." Cut.

### Pull-quote-able sentences
If it sounds like a LinkedIn screenshot, rewrite. "Culture eats strategy for breakfast" energy.

---

## 3. Punctuation and typography tells

### Em-dash addiction
Budget: ≤2 per page of prose. Em-dash-as-comma is the strongest typographic tell. Prefer commas, colons, periods, or parentheses; when possible, rewrite the sentence to not need an aside.

### Decorative Unicode
→, ←, ↑, …, curly quotes, curly apostrophes. Use ASCII where possible.

### Emoji sprinkles
💡 🚀 ✅ on bullets. Remove unless the platform or audience demands them (some Slack channels, some social media).

### Bold-first bullets
Every bullet opens with `**Keyword:**` then content. Either convert to prose paragraphs or use plain bullets. Reserve bold for genuinely emphatic phrases that appear once.

### Bold scattered through prose
Bolding every technical term in a paragraph. Cut to zero or one.

### Title Case Headings
Prefer sentence case. "## Strategic partnerships and negotiations" — not "## Strategic Partnerships And Negotiations".

### Short-punchy-fragment paragraphs
- **Bad:** "He published this. Openly. In a book. As a priest."
- **Better:** "He published it openly, in a book, while serving as a priest."

### Semicolon overuse in casual prose
If it isn't academic or legal, use periods.

### Small decorative tables
Tables belong when data has two or more dimensions and several rows. For two or three items, use prose.

---

## 4. Vocabulary watchlist

Cluster-sensitive: a single "pivotal" in a 2000-word doc is fine. Five of these in one paragraph is a confession.

### Significance inflation

| Avoid | Write instead |
|---|---|
| pivotal, crucial, vital, paramount | important, or cut |
| key (adj) | main, primary, or rephrase |
| testament (to) | evidence, or cut |
| watershed moment, turning point | state what changed |
| indelible mark, enduring legacy, lasting legacy | state the effect |
| deeply rooted | long-standing, or cut |
| transformative, revolutionary, groundbreaking (figurative) | new, first |
| profound, seminal | important, or name the influence |
| plays a significant role | matters, affects |
| marks/represents a shift | state the change |
| contributing to (abstract) | state the contribution, or cut |
| reflects broader (trends) | name what it reflects |
| reminder (as in "is a reminder") | evidence, sign, or cut |

### False sophistication

| Avoid | Write instead |
|---|---|
| delve (into) | look at, discuss |
| intricate, intricacies | detailed, complex, or cut |
| interplay | relationship, interaction |
| garner | get, earn |
| underscore, highlight (v), emphasize | stress, show |
| showcase, exemplify | show, display, has |
| foster, cultivate (figurative) | encourage, build |
| encompass | include, cover |
| align (with) | match, fit |
| resonate (with) | appeal to, affect |
| vibrant, rich (cultural), bustling, breathtaking, stunning, dynamic, robust, seamless, comprehensive, meticulous, multifaceted, holistic, innovative, cutting-edge | cut, or be specific |
| nestled, in the heart of | in, in central, located |
| boasts, features, offers | has |
| navigate (figurative) | handle, deal with |
| leverage (v) | use |
| elevate, reimagine, orchestrate, curate, embark | raise, redesign, organize, start |
| paradigm, ecosystem, tapestry, mosaic, fabric, landscape (figurative), realm, nexus | cut, or name the actual thing |
| bespoke | custom |
| facilitate | help, allow |
| instrumental | important, useful |
| valuable, renowned, esteemed, commendable | useful, well-known, or cut |
| featuring | with, has |

### Structural tics

| Avoid | Write instead |
|---|---|
| Additionally, (opener) | cut, or restructure |
| Furthermore, Moreover | cut, or restructure |
| However, (overused) | but |
| Therefore, (overused) | so |
| Nonetheless, Nevertheless | but, still |
| Hence, Thus | so |
| It is worth noting / It bears mentioning / Importantly | state the thing directly |
| Despite these challenges | name the challenge |
| setting the stage for | before, leading to |
| Not only X but Y | rephrase without the setup |
| In today's fast-paced / digital / modern world | cut entirely |
| In the realm of / In the world of | in |
| At its core | cut |
| A delicate balance | describe the actual tradeoff |
| It's not just X, it's Y | rephrase without negation setup |
| Challenges and Legacy (as heading) | avoid |
| Future Outlook (as heading) | avoid |
| While specific details are limited | "unknown", or state what IS known |
| based on available information | cut |

### Filler phrases

| Avoid | Write instead |
|---|---|
| in order to | to |
| due to the fact that | because |
| at this point in time | now |
| has the ability to | can |
| a wide range of | list the items |
| when it comes to | cut, or restate as "for X" |
| in the process of | while |
| it is important to | cut, then state |

### Magic adverbs

quietly, deeply, fundamentally, remarkably, arguably, inherently, inevitably, truly, genuinely, honestly, really, just, literally, simply, actually, interestingly, importantly, crucially, notably, undeniably, seamlessly, meticulously, profoundly.

Most can be deleted with no loss. "It quietly reshapes everything" → "It reshapes X." Pick one per document max.

### Business-jargon replacements

| Avoid | Write instead |
|---|---|
| unpack, deep dive, dive in | explain, examine |
| lean into | commit to, emphasize |
| double down | commit to |
| circle back, loop back | follow up, revisit |
| take a step back | pause, reconsider |
| on the same page | agree |
| game-changer, needle-mover | (state the change) |
| at the end of the day | cut |
| moving forward | next, later |
| touch base | talk |
| streamline | simplify |
| synergy | (cut) |
| best-in-class | (state what makes it good) |

### Vague attribution

| Avoid | Write instead |
|---|---|
| industry reports suggest | name the report |
| experts argue / observers note / critics say | name the person |
| several publications | name them |
| studies show | cite the study |
| some people say | name them, or cut |
| such as (before an exhaustive list) | just list the items |
| cited in NYT, BBC, FT (as a list) | quote what the source said |

---

## 5. Opener and closer tells

### Openers

- "Great question!" / "Certainly!" / "Of course!" / "Absolutely!"
- "Let's dive in" / "Let's unpack" / "Let's break this down" / "Let's explore"
- "In this post we'll cover" / "By the end of this article" / "The rest of this essay explores"
- "In today's fast-paced world" / "In the modern era" / "In the digital age"
- "Without further ado" / "Let me walk you through"
- "Imagine a world where…"
- "Think of it as…" (patronizing analogy)
- "The truth is simple" / "The reality is"
- "Here's the thing" / "Here's the kicker" / "Here's what most people miss"
- "You're absolutely right!" (sycophantic reply-opener)

### Closers

- "In conclusion" / "In summary" / "To sum up" / "Overall" / "Ultimately"
- "The future looks bright" / "Exciting times lie ahead"
- "Despite these challenges…"
- "I hope this helps" / "Let me know if" / "Would you like me to elaborate" / "Feel free to ask"
- "Full stop." / "Period." / "Let that sink in." / "Make no mistake."
- "And that's okay."
- "The possibilities are endless."

### Throat-clearers mid-doc

- "It's worth noting" / "It's important to note" / "Notably" / "Interestingly" / "Importantly" / "Crucially" / "It bears mentioning"
- "As mentioned above" / "As we've seen" / "As I noted earlier"

---

## 6. Structure-of-document tells

- **Over-bulleting.** Every paragraph becomes a bullet list. Use prose for anything that isn't genuinely enumerable.
- **Header per paragraph.** If you have 12 H2s in a 1500-word doc, they're not headers — they're scaffolding. Consolidate.
- **TOC for short docs.** No TOC under ~1500 words.
- **Summary section that restates the doc.** Cut.
- **Balanced-by-default sections.** If section 3 has 60% of the argument, let it be longer than sections 1 and 2.
- **"What This Means For You" / "Why This Actually Works" / "Here's What's Really Going On"** as headers. Avoid explanatory header templates.
- **Promotional column headers** ("The X Advantage", "Key Benefits"). Use descriptive labels ("Where X differs").
- **Content duplication.** Long AI outputs sometimes repeat paragraphs verbatim. Edit.
- **Knowledge-gap padding.** "Specific details are limited in currently available sources" — cut; say "unknown" or remove the paragraph.

---

## 7. Detection and scoring

For a rewrite task, do a quick triage pass before committing to the full rewrite. A rough mental score helps decide between surgical edits and paragraph-by-paragraph rewrites.

### Severity triage

Scan for violations across the seven rule categories. A rough count across the whole piece:

- **0–2 tells** — clean. Return as-is or with one or two small edits.
- **3–6 tells** — light slop. Surgical rewrites; keep most of the author's structure and phrasing.
- **7+ tells, or clear clustering in one paragraph** — heavy slop. Rewrite paragraph by paragraph, applying the seven rules in order.
- **One tell may be fine; three stacked in one paragraph is a confession.** Weight clustering heavily.

### High-signal detectors (fastest to check)

Run these first — they're single regex-grep-able:

1. Em-dash count (`—` character) — more than 2 per 500 words = problem.
2. "it's not" / "not just" — almost always negative parallelism.
3. Banned vocabulary spot-check: delve, tapestry, landscape, robust, seamless, pivotal, testament, showcase, underscore, leverage, foster, nestled, boasts, vibrant, meticulous, intricate.
4. "In conclusion" / "In summary" / "Ultimately" near the end.
5. Bold-first bullets (`\n\*\*[A-Z]\w+:\*\*`).
6. `-ing` at end of sentence (look for ", [something]ing" before a period).

Cluster any three of these and you have a rewrite candidate.

### The horoscope test

For any sentence or paragraph: could this have been written about anything, for anyone? If yes, it's slop. Specificity is the cure.

---

## 8. Positive patterns — what human prose sounds like

Don't just remove tells. Cultivate these.

- **Uneven rhythm.** Some sentences are short. Others can run longer when the content demands it. Variation follows the shape of the ideas, not a formula.
- **Plain copulas.** "The bridge is 200 meters long" needs no synonym for "is".
- **Natural repetition over forced variation.** "The bridge was built in 1910. The bridge connects the north and south banks" beats "the structure… the span… the crossing".
- **Opinions stated plainly.** "This approach is simpler" beats "Not only is this more elegant, but it is also more maintainable".
- **Specific concrete facts.** $2.4M, 1973, 12%, "the on-call engineer", "Tuesday afternoon". Numbers and named actors beat adjectival claims of significance every time.
- **Unknowns admitted directly.** "I don't know" / "The date is unknown" beat "While specific details remain limited in available sources".
- **Willingness to leave things unsaid.** Not every paragraph needs a concluding sentence. Not every topic needs a transition.
- **Contractions when the register permits.** "don't", "can't", "it's", "won't".
- **A question or a fragment, occasionally.** Declaratives only is flat. A genuine question ("Is this right?") or an imperative ("Run it.") or a fragment ("Not quite.") breaks the monotone.
- **Register shifts within a piece.** Two or three shifts in register — e.g., a casual aside inside a technical paragraph — read as human. Register uniformity is a tell.
- **Commits to a position.** Pick a side. Hedging clusters read as AI equivocation.

The goal isn't sterile. Sterile prose is still slop. Protect the author's voice, opinions, rough edges, and rhythm — clean up only the statistical signature.
