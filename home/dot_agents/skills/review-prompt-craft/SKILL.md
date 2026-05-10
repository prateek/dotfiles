---
name: review-prompt-craft
description: |
  Write effective code review prompts, review context documents, and AI-assisted
  review infrastructure for any project. Covers: writing `.roborev.toml`-style
  negative-space context docs that teach reviewers what NOT to flag; designing
  multi-agent review matrices (when and why to use multiple models); structuring
  the review-fix-re-review loop with numbered findings and traceable fix commits;
  and conducting individual PR reviews with project-aware prompts. Use when
  setting up automated review for a repo, writing review instructions or
  guidelines, crafting prompts for AI code reviewers, deciding what reviewers
  should and should not flag, or debugging noisy/unhelpful AI review output.
  Also use when a review produces too many false positives, reviewers miss real
  bugs while flagging style nits, or review findings are vague and unactionable.
---

# Review Prompt Craft

## Purpose

AI code reviewers are only as good as the context they receive. Without project
context, they flood PRs with generic warnings about auth, rate limiting, input
validation, and error handling that do not apply. This skill teaches you to
build review infrastructure that produces high-signal, actionable findings.

The core insight: the most valuable review document is not a list of what to
check -- it is a list of what NOT to flag. Every project has intentional design
decisions that look like bugs to a context-free reviewer. Documenting those
decisions is the single highest-leverage thing you can do for review quality.

## Two Modes

This skill operates in two modes:

1. **Setup mode**: Build review infrastructure for a project (context docs,
   multi-agent config, CI integration).
2. **Review mode**: Conduct an individual PR review using project context.

Determine which mode the user needs. If they ask to "set up review" or "write
review guidelines," use setup mode. If they ask to "review this PR" or "review
these changes," use review mode (and check whether project context exists first).

---

## Mode 1: Setup -- Build Review Infrastructure

### Step 1: Audit the Project's Threat Model

Before writing any review config, answer these questions by reading the codebase:

1. **Who runs this?** Single user on localhost? Multi-tenant SaaS? Internal
   tool behind a VPN? The answer determines which security findings are valid.
2. **What is the trust boundary?** Loopback-only? Auth-gated API?
   Network-isolated container? Trusted input from local files?
3. **What are the accepted design decisions?** Every project has things that
   look wrong but are intentional. Find them before reviewers do.
4. **What has the project already been falsely flagged for?** Check PR history,
   existing review configs, CLAUDE.md, and issue trackers.

### Step 2: Write the Negative-Space Context Document

The context document teaches reviewers what the project is and what NOT to flag.
It is the single most important artifact in the review system.

**Format**: Use a TOML file (`.roborev.toml`) with a `review_guidelines` key
containing a multi-line string. TOML is preferred because it is
language-agnostic, parseable, and works with any review tool.

**Structure template**:

```toml
review_guidelines = """
<PROJECT NAME> is <one-sentence description including deployment model>.
<Key architectural constraint, e.g. "Not designed for multi-user or
internet-facing deployment.">

Key assumptions reviewers MUST account for:

1. <CATEGORY>: <What the project does and why it is correct>.
   Do not flag <specific false-positive pattern>.
   DO flag <what would actually be a bug in this area>.

2. <CATEGORY>: <Explanation of intentional design decision>.
   Do not flag <the thing reviewers always incorrectly flag>.

...

Do NOT flag issues that only apply to <inapplicable deployment model>.
Focus on <what actually matters: bugs, logic errors, data corruption, etc.>.
"""
```

**Writing principles**:

- **Be specific, not abstract.** "Do not flag missing auth on local-only code
  paths" beats "Consider the auth model." Name the function, the middleware,
  the config flag.
- **Pair every "do not flag" with a "DO flag."** This prevents reviewers from
  over-correcting. Example: "Do not flag missing auth on loopback paths. DO
  flag any path that lets the backend bind non-loopback without auth."
- **Number every item.** Numbered items are referenceable in findings and fix
  commits. "Violates guideline #4" is actionable; "violates the XSS policy"
  is ambiguous.
- **Cover the repeat offenders.** The top false-positive categories for AI
  reviewers are:
  - Auth/authz on single-user or loopback-only tools
  - Rate limiting on non-public services
  - Input validation on trusted local input
  - TOCTOU on user-owned local files
  - Sensitive data exposure when displaying user-owned data is the purpose
  - Subprocess environment inheritance when it is intentional
  - Missing TLS when the user is responsible for transport security
- **Include schema and control-flow caveats.** AI reviewers frequently
  misread database schemas and control flow. If your schema has constraints
  that prevent certain states, say so. If early returns make certain paths
  unreachable, say so.
- **Reference real code.** Use function names, middleware names, and config
  keys. "{@html renderMarkdown(...)} is safe because renderMarkdown()
  sanitizes via DOMPurify" is much stronger than "XSS is handled."

**Anti-patterns to avoid in context docs**:

- Enumerating lists that go stale (e.g., listing every agent name when agents
  are added regularly). Use descriptions of categories instead.
- Over-documenting (the context doc should be 50-150 lines, not 500).
- Vague guidance ("be careful with security" -- this helps nobody).
- Positive-only guidance (telling reviewers what to check without telling
  them what NOT to check produces the same noisy output as no guidance).

### Step 3: Decide on a Review Matrix

**Single-agent review** is sufficient when:
- The project is small or well-understood.
- Review is primarily catching regressions, not discovering novel issues.
- Speed matters more than coverage.

**Multi-agent review** (2-3 models) is worth the cost when:
- The project has a complex security surface.
- PRs touch multiple subsystems (backend + frontend + infra).
- You want to catch different classes of issues: one model may excel at
  logic errors while another catches API design problems.
- You are establishing a review baseline for a new project.

**Recommended matrix** (when using multiple agents):

| Agent        | Strength                                    |
| ------------ | ------------------------------------------- |
| Claude Code  | Architecture, logic errors, subtle bugs     |
| Codex        | Code quality, patterns, missing edge cases  |
| Gemini       | Security surface, API design, documentation |

Each agent receives the same context document but produces independent
findings. Findings are then merged, deduplicated, and prioritized.

### Step 4: Set Up the Review-Fix Loop

The review-fix loop turns findings into commits:

1. **Review produces numbered findings.** Every finding gets a unique ID
   (e.g., `#13915`). Findings include: severity, file/line, description,
   and suggested fix.

2. **Developer (human or AI) fixes findings in traceable commits.** Commit
   messages reference the finding IDs:
   ```
   fix: address review finding #13915 and #13917 on PR #314
   ```

3. **Re-review runs on the fix commits.** The reviewer checks whether the
   fixes are correct and whether they introduced new issues.

4. **Loop terminates** when no blockers remain, or when remaining findings
   are acknowledged as accepted trade-offs.

**Finding format template**:

```markdown
### Finding #<ID> [<SEVERITY>]

**File**: `<path>:<line>`
**Category**: <bug | security | logic | performance | style | docs>

<Description of the issue -- what is wrong and why it matters.>

**Suggested fix**:
<Concrete code change or approach, not just "fix this.">
```

Severity levels:
- **BLOCKER**: Must fix before merge. Correctness, security, data loss.
- **HIGH**: Should fix. Performance, missing edge cases, maintainability.
- **LOW**: Consider fixing. Style, docs, minor improvements.
- **NIT**: Optional. Consistency, naming, formatting.

### Step 5: Integrate with CI (Optional)

For automated review on every PR:

1. Store `.roborev.toml` in the repo root.
2. Configure a CI job that runs on `pull_request` events.
3. The CI job invokes the review agent(s) with the context document.
4. Findings are posted as PR comments (or a review).
5. Fix commits trigger re-review automatically.

The context document travels with the code. When the architecture changes,
update the context document in the same PR.

### Step 6: Leverage Existing Project Instructions

If the project has a `CLAUDE.md`, `AGENTS.md`, or similar instruction file,
the review context document should complement it, not duplicate it. The
instruction file tells the AI builder what to do; the review context tells
the AI reviewer what is already done correctly.

Common pattern: extract the "conventions" and "architecture" sections from
`CLAUDE.md` and reference them in the review context. Do not copy-paste --
link or summarize.

---

## Mode 2: Review -- Conduct a PR Review

### Step 1: Gather Context

Before reviewing, collect:

1. **The diff**: `git diff <base>...HEAD` or `gh pr diff <number>`.
2. **Project review context**: Look for `.roborev.toml`, `CLAUDE.md`,
   `AGENTS.md`, or similar files in the repo root.
3. **PR description**: What is the intent of the change?
4. **CI status**: Are checks passing?
5. **Prior review comments**: Has this PR already been reviewed?

### Step 2: Apply the Context Document

Read the negative-space context document before looking at the code. For each
numbered item, internalize what NOT to flag. This prevents the most common
failure mode: flooding the review with false positives that waste everyone's
time and bury real issues.

### Step 3: Review with the Right Focus

Prioritize findings in this order:

1. **Correctness bugs**: Logic errors, off-by-ones, nil dereferences, race
   conditions that matter (not TOCTOU on local files).
2. **Security issues that apply to THIS deployment model**: Not generic
   "you should add auth" -- only issues that matter given the project's
   actual threat model.
3. **Data integrity**: Anything that could corrupt persistent state.
4. **API/ABI breaks**: Unintentional breaking changes.
5. **Missing tests**: For new behavior, not for every helper function.
6. **Performance**: Only when the impact is measurable and significant.
7. **Maintainability**: Only when the code is genuinely hard to follow,
   not just different from your preferred style.
8. **Style**: Only when it contradicts the project's established patterns.

### Step 4: Format Findings

Use the numbered finding format from Step 4 of Setup mode. Every finding must:

- Have a unique ID (sequential within the review).
- State the severity honestly (most findings are LOW or NIT, not BLOCKER).
- Be specific enough to act on without re-reading the entire file.
- Include a suggested fix (code or approach), not just a complaint.

**Good finding**:
```markdown
### Finding #3 [HIGH]

**File**: `internal/server/sessions.go:142`
**Category**: bug

The error from `db.GetSession()` is checked but the nil session is not --
if the query returns no rows without an error, the handler will panic on
line 145 when accessing `session.ID`.

**Suggested fix**: Add `if session == nil { http.NotFound(w, r); return }`
after the error check.
```

**Bad finding**:
```markdown
### Finding #3 [HIGH]

**File**: `internal/server/sessions.go`
**Category**: security

Consider adding authentication to this endpoint.
```

The bad finding ignores the project's auth model (it might be loopback-only),
lacks a specific line number, and has no actionable suggestion.

### Step 5: Summarize

End the review with a short summary:

```markdown
## Summary

Reviewed <N> files, <M> additions, <K> deletions.

- **Blockers**: <count> (must fix before merge)
- **High**: <count> (should fix)
- **Low/Nit**: <count> (consider fixing)

<One sentence on overall assessment: "Clean change, one edge case to handle
before merge." or "Significant concerns about data integrity in the migration
path.">
```

---

## Anti-Patterns

These are the most common ways AI code review goes wrong. Avoid them.

### Context-Free Flag Flooding

Reviewing code without reading the project's architecture, deployment model,
or existing conventions. Produces dozens of generic warnings about auth, rate
limiting, and input validation that do not apply. The fix: always read the
context document first; if none exists, read `CLAUDE.md` and the README.

### Style-Only Reviews

Reviewing only for formatting, naming, and code organization while missing
actual bugs. Style findings should be at most 20% of a review. If you have
only style findings, say so explicitly -- do not inflate their severity.

### Severity Inflation

Marking everything as BLOCKER or HIGH. If a review has more than 2-3
blockers, re-evaluate whether they are truly merge-blocking. Most findings
are LOW or NIT. Inflated severity trains developers to ignore review output.

### Vague Findings

"This could be improved" or "Consider error handling here" without saying
what is wrong, why it matters, or how to fix it. Every finding must be
specific enough that a developer can act on it without asking follow-up
questions.

### Stale Context Documents

Writing a context document once and never updating it. The context document
must evolve with the codebase. When architecture changes, update the context
document in the same PR. When a new false-positive pattern emerges, add it.

### Over-Documentation in PR Descriptions

PR descriptions should be concise summaries of what the code does now, not
test plans, checklists, or change logs. The code and tests are the
documentation. PR descriptions that are longer than the diff are a smell.

### The "Supersedes" Trap

When a community PR is reworked by a maintainer, the new PR should credit
the original and explain what changed. But do not carry forward stale review
findings from the original PR -- re-review the new code fresh.

---

## Checklist: Is Your Review Infrastructure Working?

Use this checklist to evaluate whether an existing review setup is effective:

- [ ] Context document exists and covers the project's deployment model.
- [ ] Context document has "do not flag" items for the top false-positive
      categories.
- [ ] Every "do not flag" is paired with a corresponding "DO flag."
- [ ] Context document references real code (function names, not abstractions).
- [ ] Context document is under 150 lines.
- [ ] Findings are numbered and include severity, file/line, and suggested fix.
- [ ] Fix commits reference finding IDs.
- [ ] Less than 30% of findings are false positives.
- [ ] Less than 20% of findings are style-only.
- [ ] Context document has been updated in the last 10 PRs that changed
      architecture.

---

## Quick Reference: Review Prompt Structure

When crafting a one-off review prompt (no `.roborev.toml`), use this structure:

```text
Review the following PR diff for <REPO_NAME>.

## Project Context
<1-3 sentences: what the project is, who runs it, deployment model.>

## Do Not Flag
<Numbered list of accepted design decisions and known false positives.>

## Focus Areas
<What actually matters for this review: specific subsystems, risk areas,
or concerns from the PR author.>

## Diff
<The diff or a pointer to it.>

## Output Format
Number every finding sequentially. Use severity levels: BLOCKER, HIGH,
LOW, NIT. Include file:line, category, description, and suggested fix
for each finding. End with a summary count by severity.
```

This structure works for any AI reviewer (Claude, Codex, Gemini, etc.)
and produces consistent, actionable output.
