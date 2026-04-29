---
name: write-for-humans
description: Detect and rewrite AI-slop prose so it reads like a human wrote it. Triggers aggressively on ANY prose-writing or prose-editing task — drafts, rewrites, reviews, commit messages, PR descriptions, READMEs, docs, Slack/email, issue text, SKILL.md / AGENTS.md / CLAUDE.md bodies, and any long natural-language reply to the user. Apply by default unless explicitly told to skip. Use whenever you are about to emit more than a sentence or two of prose, whenever the user asks you to "write", "draft", "rewrite", "humanize", "clean up", "de-slop", "fix the tone", "review this", "too corporate", "too formal", "sounds like AI", "less LinkedIn", or any variant. Also use when reviewing prose the user just wrote if they ask for feedback. Complementary to writing-clearly-and-concisely (which handles Strunk-style structural clarity); this skill handles register, texture, and AI-specific tells.
---

# Write for Humans

## Why this skill exists

AI writing has a statistical signature. Models replace specifics with generalities, inflate significance with stock vocabulary, cycle synonyms to dodge the repetition penalty, and close every loop with a tidy summary. The individual tells are harmless in isolation. Clustered, they produce prose that reads like a press release about everything — confident, fluent, and unmistakably machine-authored.

The fix is not a longer vocabulary ban list. It is a small set of ordered moves that attack the structural and lexical patterns at their source, plus a short detection loop to catch them.

**Two modes, same rules:**
- **Generation** — the user asks you to write something. Apply the rules as you draft.
- **Rewrite** — the user has prose (theirs or yours) and wants it de-slopped. Detect, score, fix, preserve voice.

**Scope.** Apply this skill to prose humans will read: docs, READMEs, PRs, commit messages, issues, email, Slack, and long replies the user will read as text. Also apply it to your own natural-language output when replying to the user. Skip code, config, structured data, agent-facing imperative guidance (AGENTS.md rules, tool-use instructions) where bluntness matters more than humanization, and direct quotes.

## The seven rules, in order

Apply these in sequence. Order matters — earlier rules remove material that later rules would otherwise have to rewrite.

### 1. Cut the scaffolding

Remove openers, closers, and meta-commentary that describe what the prose is about to do or just did. The reader can see it's an answer. Don't announce.

Delete on sight:
- Openers: "Great question", "Certainly", "Of course", "Let's dive in", "Let's unpack", "Let's break this down", "In this post we'll cover", "Without further ado", "In today's fast-paced world".
- Closers: "In conclusion", "In summary", "To sum up", "Overall", "Ultimately", "The future looks bright".
- Throat-clearers: "It's worth noting", "It is important to note", "It bears mentioning", "Interestingly", "Notably", "Importantly".
- Sign-offs: "I hope this helps", "Let me know if", "Would you like me to elaborate", "Feel free to ask".
- Fractal summaries: section intros that preview the section, section outros that restate it.
- Hand-holding: "Let me walk you through", "Think of it as", "At its core", "Here's the thing", "Here's the kicker".
- Moral wrappers: "It is crucial to approach this with sensitivity", "We must remember".
- Defensive hedges / unsolicited labor offers: "happy to do the legwork", "zero effort on your end", "I can handle the PR", "I'll take care of everything", "no action needed from you", "just let me know if". These read as performative deference. If you mean to offer the work, say it once plainly ("I can open the PR if you want") — do not sprinkle hedges into every paragraph or every option.

**Before:** "Great question! Let's dive into how caching works. There are three layers worth exploring. In conclusion, the layered design is powerful."

**After:** "Next.js caches at three layers: request memoization, data cache, router cache."

### 2. Kill negative parallelism

The "not X, it's Y" / "not X — Y" / "not just X, but Y" construction is the single most commonly identified AI tell. It fakes profundity by setting up a strawman. Assert what it is; don't negate what it isn't.

**Before:** "It's not a bug. It's a feature."
**After:** "This behavior is intentional — here's the tradeoff."

**Before:** "This isn't theoretical. It's practical."
**After:** "You can run this today on your laptop."

Also kill variants: "Not only X but Y", "Not X. Not Y. Just Z.", "The X? A Y."

### 3. Be specific, not significant

Replace abstract claims of importance with concrete facts. Cut vocabulary that inflates: pivotal, crucial, vital, key (adj), testament, watershed, indelible, enduring, transformative, groundbreaking, seminal. Replace inflated action verbs: showcase → show, underscore → stress, foster → encourage, leverage → use, delve into → look at, navigate → handle.

The test: if removing the word doesn't change the meaning, remove it. If it does change the meaning, replace it with a concrete fact.

**Before:** "The 1987 renovation marked a pivotal moment in the building's enduring legacy, a testament to the community's deeply rooted commitment to preservation."
**After:** "The building was renovated in 1987 after the roof collapsed in a storm. The city council funded it."

### 4. Use plain verbs

Write "is", "are", "has" instead of "serves as", "stands as", "represents", "embodies", "epitomizes". Copula avoidance is an RLHF artifact, not elegance. Better yet, find the active verb hiding inside the noun phrase.

- "The tool serves as a validation mechanism" → "The tool is a validation mechanism" → "The tool validates inputs."
- "The library boasts over 2 million volumes" → "The library has over 2 million volumes."
- "The museum showcases artifacts" → "The museum has artifacts."

### 5. End sentences at the fact

Cut participial tack-ons — "-ing" phrases that editorialize after the main clause. They add opinion disguised as analysis.

Watch for: "reflecting broader trends", "highlighting its importance", "underscoring the significance", "emphasizing the need", "ensuring continued relevance", "contributing to the region's cultural heritage", "solidifying its position as".

**Before:** "The population grew 12%, reflecting broader demographic trends."
**After:** "The population grew 12%."

**Before:** "The company opened a second factory in 2019, highlighting its commitment to expansion."
**After:** "The company opened a second factory in 2019."

### 6. Earn every adjective and every em-dash

Decorative adjectives: vibrant, rich, bustling, stunning, breathtaking, dynamic, robust, seamless, comprehensive, meticulous, intricate, multifaceted, holistic, innovative, cutting-edge, nestled. Cut or replace with a specific fact. "A vibrant community" means "a community". "A robust framework" means "a framework".

Em-dashes: at most one or two per page of prose. Em-dash-as-comma is the strongest typographic AI tell. Prefer commas, colons, periods, or parentheses. When you find a draft with em-dashes every third sentence, convert most of them — not by substituting one punctuation for another but by rewriting the sentence to not need the aside.

**Literary-voice exception.** When preserving an author's voice in fiction or essayistic prose where the source voice is genuinely em-dash-heavy (McCarthy, DeLillo, DFW, Dickinson, and others use them as rhythmic signatures), the budget expands to ~3–4 per 500 words. The test is still honest use, not substitution: an em-dash must earn its place as a pause the voice actually calls for, not as a default connector. In technical prose, docs, commit messages, Slack, email — the 1–2 cap holds.

**Before:** "The problem — and this is the part nobody talks about — is systemic."
**After:** "The problem is systemic, and nobody talks about it."

Also clamp: emoji sprinkles (remove unless the platform demands them), bold-every-keyword bullets (`**Performance:** fast loads`), decorative Unicode (→ arrows, ellipsis glyph, curly quotes in plain text), title-case headings in prose, unnecessary tables for 2–3 items. Watch the bold-label-em-dash bullet pattern (`**Option** — description`) — it silently blows the em-dash budget once you have three or more bullets. Use `**Option**:` (colon) or a plain hyphen instead.

### 7. Vary rhythm; ration the tricolon

Sentence-length variation is the single highest-impact lever against detection and for readability. AI drafts metronomic prose — every sentence 10–15 words. Humans mix 3-word punches with 35-word explorations.

Default to the rule of three? Stop. Use two, four, or one. One tricolon per document is fine. Three stacked tricolons are a pattern-recognition failure.

Avoid anaphora abuse: three consecutive sentences opening with the same subject. Avoid elegant variation: "the bridge… the structure… the span… the crossing" — repeat "bridge".

**Before:** "Innovation, inspiration, and insight drive the team. They build engines. They build walls. They build silos. The structure represents a commitment to excellence."
**After:** "Innovation drives the team, but they build plumbing — not products."

**Watch the rule-3 / rule-7 collision — this is the single most common way drafts fail this skill.** Listing concrete facts (rule 3) mechanically produces three-item lists. When you reach for "X, Y, and Z", stop and convert BEFORE you write it. Do not draft the tricolon then count it — the counting step fails under time pressure. While drafting, every time a three-item list forms in your head:

- Use two items and promote the third to its own sentence: "A and B. C is the one that changed."
- Use four items when the list is naturally four, not compressed to three.
- Drop the weakest item and write prose.
- Use a colon and a single item: "Only one thing moved the needle: X."

Hard rule for any document under 500 words: at most ONE tricolon. Over 500 words: at most two, and never adjacent. A paragraph that ends with "X, Y, and Z" — even once — should get a second look before you hit return. Three tricolons in one page is a pattern-recognition failure regardless of how honest the specifics are.

## Voice preservation (the overarching principle)

Goal: make the text sound like a better version of the author, not a different person. Protect their rhythm, opinions, contractions, and rough edges.

- Do not add content. Only subtract and simplify.
- Do not change technical meaning.
- Do not touch code blocks, front matter, or structured data.
- If the author writes lowercase, keep lowercase. If they use contractions, keep contractions. If they swear, keep the swearing.
- Opinions, mixed feelings, and first-person "I" are load-bearing. Do not sand them off into neutral third-person.
- If you can't decide between two rewrites, pick the shorter one.

## Workflow

### Generation mode

Asked to write fresh prose:
1. Draft with the seven rules in mind. Especially rules 1 (no scaffolding), 2 (no negative parallelism), 6 (em-dash budget including bold-label bullets), and 7 (don't stack tricolons when listing concrete facts).
2. Before returning, re-read your draft and run the self-edit checklist (below).
3. Return the final text. No preamble explaining what you wrote.

### Rewrite mode

Asked to de-slop, humanize, or clean up existing prose:
1. Read the whole draft.
2. Detect — scan for the seven rule violations. If the draft is long, load `REFERENCE.md` for the exhaustive pattern list and vocabulary tables.
3. Score — rough severity, not a number. "Light slop" (2–4 tells, keep most of the draft, surgical edits) vs. "heavy slop" (pattern clusters, rewrite paragraph by paragraph).
4. Fix — apply the rules in order. Cut first, rewrite second.
5. Preserve voice — diff your rewrite against the original. If you've replaced an idiosyncratic word with a neutral one, revert. If you've made a casual draft sound formal, revert.
6. Return the rewrite. If the user asked for a diff or a list of what changed, provide it; otherwise just return the new text.

### When context is tight

For long rewrites, dispatch the `agents/prose-humanizer.md` subagent with the draft. The subagent applies the seven rules in order, edits files in place, returns a short summary, and keeps the slop pattern details out of the main context.

## Self-edit checklist

Run through this before returning any prose:

1. Opening sentence: does it make a claim or announce what's coming? If announce, cut.
2. Negative parallelism: search for " not ", "it's not", "isn't". Kill any "not X, it's Y" / "not only X but Y" / "not X — Y".
3. Em-dash count: more than two in the whole piece? Reduce.
4. Scan for banned vocabulary: delve, tapestry, landscape, robust, seamless, crucial, pivotal, testament, showcase, underscore, leverage, foster, navigate (figurative), nestled, boasts, vibrant, meticulous, intricate. See REFERENCE.md for the full list.
5. Participial -ing tack-ons at end of sentences: cut.
6. Signposted closer ("In conclusion", "Ultimately", "The future looks bright"): cut.
7. Tricolons: count every "X, Y, and Z" construction. Hard cap = 1 per 500 words. If over, convert the weakest one to prose ("A and B. C is the one that changed."). Do NOT just reduce to the cap — audit every remaining tricolon and ask whether the third item earns its spot. Most don't.
8. Bold-first bullet lists (`**Keyword:** content`): convert to prose or plain bullets.
9. Opening same subject three sentences in a row (anaphora): break it.
10. Does the last sentence restate the first? If yes, cut it.

## Cross-reference

- `writing-clearly-and-concisely` — Strunk-level structural clarity (active voice, omit needless words, one topic per paragraph). Apply first for structure, then this skill for register. If both skills are relevant, do a Strunk pass, then an anti-slop pass — they rarely conflict, and the order matters because Strunk cuts clutter that this skill would otherwise have to diagnose.
- `REFERENCE.md` — exhaustive pattern catalog, vocabulary tables, and detection examples. Load when rewriting heavy-slop drafts or when you need the full ban list.
- `agents/prose-humanizer.md` — subagent that applies the rules in place; use for long rewrites or when main-context budget is tight.
