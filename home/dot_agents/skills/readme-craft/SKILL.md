---
name: readme-craft
description: |
  Write, rewrite, or audit README files that convert scanners into users.
  Covers greenfield drafts, growth management, and editorial rewrites for
  bloated READMEs. Use when asked to create a README, improve a README,
  review a README, trim a README, or when a project ships without one.
  Also trigger when a README has grown past ~200 lines, when a docs site
  exists but the README duplicates its content, when a README contains
  marketing language ("powerful," "seamless," "game-changing"), or when
  install/quickstart instructions are buried below the fold. README
  quality directly affects adoption -- treat this as product work, not
  docs busywork.
---

# README Craft

## Why This Matters

A README is a landing page rendered in plain text. Most visitors scan for
30 seconds, then leave or install. Every line competes for those seconds.
The job is not to document everything -- it is to get a stranger from
"what is this?" to running it, as fast as possible, then get out of the
way.

## The Information Hierarchy

Structure every README in this order. Sections near the top are
mandatory. Sections near the bottom are optional or should be offloaded.

### The First 29 Lines (The Billboard)

The reader decides to stay or leave here. Pack these lines tight:

1. **H1 + one-liner** (2-3 lines). The one-liner must answer "what does
   this do?" and "why should I care?" in one or two sentences. Embed
   value props and trust signals. No adjectives.
2. **Hero image or screenshot** (1 element, optional). Show the product,
   not a logo. Host externally if the repo is public (keeps git clean,
   images update without commits).
3. **Install** (5-8 lines). The fastest path from zero to installed. One
   code block, two max (macOS/Linux + Windows). No "build from source"
   here -- that goes in Development.
4. **Quick start** (3-5 lines). One or two commands that produce visible
   output. Annotate with inline comments, not prose.

Example (agentsview, post-rewrite):

```markdown
# agentsview

Browse, search, and track costs across all your AI coding agents. One
binary, no accounts, everything local.

## Install

\`\`\`bash
curl -fsSL https://agentsview.io/install.sh | bash
\`\`\`

## Quick Start

\`\`\`bash
agentsview                 # start server, open web UI
agentsview usage daily     # print daily cost summary
\`\`\`
```

That is 15 lines. A reader who stops here still knows what the tool does
and how to get it.

### The Middle (Evidence and Orientation)

After the billboard, provide evidence that the tool delivers on its
promises. Order sections by **fastest path to value** -- put the feature
that requires the least setup first.

5. **Primary feature section** with usage examples. Brief prose intro,
   then a code block showing 3-5 real commands. End with a bullet list
   of capabilities (scan-friendly, no paragraphs).
6. **Screenshots** as a 2x2 or 2x1 table. No explanatory prose -- if
   the screenshot needs explanation, the UI has a problem. Use tables,
   not inline images, to control layout.
7. **Secondary feature sections** (1-2 max). Same pattern: brief intro,
   code block, bullet list.
8. **Compatibility / supported X** as a table. Tables scan faster than
   prose lists and do not need justification text.
9. **Privacy / security** if relevant. Keep it short -- 3-5 sentences.
   Brevity reads as confidence.
10. **Documentation links**. One line linking to the docs site. If the
    project has a docs site, the README must not duplicate it.

### The Footer (Below the Fold)

Use a horizontal rule (`---`) to visually separate user-facing content
from contributor-facing content. This respects two audiences in one
document.

11. **Development** (below the rule). Prerequisites, build commands, test
    commands. Keep to essentials -- 10-15 lines max.
12. **Project layout** (optional, below the rule). A `tree`-style code
    block, not prose.
13. **Acknowledgements** (optional). Credit inspirations and
    predecessors.
14. **License** (one line).

## Writing the One-Liner

The one-liner is the hardest sentence in the README. It must:

- State what the tool does (verb phrase, not noun phrase)
- Identify the target user without naming them ("your AI coding agents"
  implies developer)
- Include 2-3 trust signals as compressed noun phrases

Structure: `[Action verb] [what] [across/for what]. [Trust signals].`

Good: "Browse, search, and track costs across all your AI coding agents.
One binary, no accounts, everything local."

- Three actions packed into one clause
- "all your AI coding agents" = breadth
- "One binary, no accounts, everything local" = three trust signals in
  seven words

Bad: "A powerful tool for managing and analyzing your AI coding sessions
with an intuitive interface."

- "Powerful" and "intuitive" are meaningless adjectives
- "Managing and analyzing" is vague
- No trust signals

## Tone

Use direct, factual language. Describe what the tool does, not how the
reader should feel about it.

**Remove these words on sight:** powerful, seamless, game-changing,
revolutionary, cutting-edge, robust, elegant, intuitive, effortless,
next-generation, supercharge, unlock, leverage (as verb).

**Remove these sentence patterns:**
- "Never lose track of..." (emotional manipulation)
- "Say goodbye to..." (infomercial)
- "Whether you're a...or a..." (fence-sitting)
- "With X, you can..." (add indirection; just say what it does)

The agentsview repo learned this early. Its first commit had "Never lose
track of that clever solution your agent came up with three weeks ago."
The next commit replaced the entire intro with "A local web application
for browsing, searching, and analyzing AI agent coding sessions." Direct.
Factual. Better.

## Anti-Patterns

### 1. Config Dump

The README is not a reference manual. When a README accumulates config
snippets, each feature owner adds "just one more example" until the
README is 50+ lines of TOML/YAML that belongs on a docs site.

The agentsview README grew to 370 lines. It included a full Caddy reverse
proxy setup (TLS certs, subnet whitelisting, bind hosts), PostgreSQL
config blocks, desktop env escape hatches, and Linux setcap instructions.
The rewrite cut all of it, replacing each with a one-line link:
"See [PostgreSQL docs](https://agentsview.io/postgresql/) for setup."

**Rule:** If a config example exceeds 5 lines, it belongs in docs, not
the README. Link to it.

### 2. Feature-by-Feature Bloat

Each new feature gets a section. Each section gets examples. The README
grows linearly with the feature set. Eventually nobody reads any of it.

**Rule:** The README covers 2-3 primary features with examples. All
other features get a bullet point or a table row. Details go to docs.

### 3. Marketing Fluff

README language drifts toward marketing copy because contributors want
the project to sound impressive. This backfires: developers distrust
adjective-heavy prose.

**Rule:** If a sentence contains an adjective that could apply to any
software project, delete the adjective. If the sentence is now empty, it
was always empty.

### 4. Audience Collision

User docs and contributor docs interleaved without separation. A reader
looking for install instructions scrolls past build prerequisites and
test commands.

**Rule:** Use a horizontal rule to separate user content (above) from
contributor content (below). Contributors know to scroll down.

### 5. Stale Screenshots

Screenshots checked into the repo as PNGs. They go stale, bloat git
history, and require commits to update.

**Rule:** Host screenshots externally. Reference by URL. They update
without touching the repo.

## Greenfield README Workflow

When writing a README for a new project:

1. **Ask:** What does this do, in one sentence, with no adjectives?
2. **Ask:** What is the single fastest way to install it?
3. **Ask:** What is the single command that shows it working?
4. **Write the billboard** (first 29 lines) using those three answers.
5. **Add evidence:** 1-2 feature sections with usage examples.
6. **Add orientation:** supported platforms/agents/languages as a table.
7. **Add the rule.** Below it: dev setup, project layout, license.
8. **Count lines.** If over 200, audit every section: does it belong
   here, or on a docs site?
9. **Read it as a stranger.** Start at line 1. Can you install and run
   the tool before you lose interest?

## README Rewrite Workflow

When an existing README has grown bloated (150+ lines, config dumps,
marketing language, duplicated docs):

1. **Measure:** Count lines. Note which sections exist. Identify the
   docs site if one exists.
2. **Audit each section** against the hierarchy above. For each section,
   decide: keep, trim, or offload to docs.
3. **Identify the billboard.** Where does install appear? Where is quick
   start? If they are below line 30, the README has structural problems.
4. **Draft the new hierarchy:**
   - Move all config blocks >5 lines to docs
   - Collapse feature sections to bullet lists
   - Replace duplicated docs content with links
   - Remove marketing adjectives and emotional appeals
   - Separate user/contributor content with a rule
5. **Write the rewrite.** Do not edit in place -- draft from scratch
   following the hierarchy, pulling content from the old README.
6. **Compare line counts.** A rewrite typically cuts 40-60%. If the new
   version is longer than the old, something went wrong.
7. **Verify links.** Every link to a docs site must resolve.

The agentsview rewrite went from 370 to 177 lines (52% reduction). It:
- Moved Caddy config, PG setup, reverse proxy docs to the docs site
- Dropped the keyboard shortcuts table (available in-app via `?`)
- Dropped the "Why?" section (the one-liner already answers it)
- Dropped "Build from source" from install (moved to Development)
- Added a Token Usage section (new primary feature, fastest path to
  value -- requires zero setup)
- Compressed Privacy from 12 lines to 4

## README Audit Checklist

Use this checklist to evaluate an existing README:

```
[ ] One-liner exists and contains no adjectives
[ ] Install appears within first 20 lines
[ ] Quick start appears within first 30 lines
[ ] No config blocks longer than 5 lines
[ ] No marketing language (powerful, seamless, etc.)
[ ] Screenshots hosted externally (not in repo)
[ ] User content separated from contributor content
[ ] No duplication of docs-site content
[ ] Total line count under 200 (under 250 with large tables)
[ ] Every external link resolves
[ ] Feature sections ordered by least-setup-required first
[ ] Tables used for scan-friendly data (agents, platforms, shortcuts)
```

## Output Format

When asked to write or rewrite a README, produce:

1. The complete README in a single code block
2. A brief summary of editorial decisions (what was cut and why, what
   was added and why)
3. A line count comparison (before/after for rewrites)

When asked to audit a README, produce:

1. The checklist above with each item marked pass/fail
2. Specific findings with line numbers
3. Recommended changes ranked by impact

## Working with Docs Sites

When a project has a separate documentation site:

- The README links to the docs site, never duplicates it
- Configuration details always live on the docs site
- The README mentions features; the docs site explains them
- Use a compact link block for docs navigation:

```markdown
## Documentation

Full docs at **[example.io](https://example.io)**:
[Quick Start](https://example.io/quickstart/) --
[Usage Guide](https://example.io/usage/) --
[CLI Reference](https://example.io/commands/)
```

This pattern (from agentsview) puts 5 doc links on 4 lines with zero
wasted words.

## Edge Cases

**No docs site exists.** The README must be more comprehensive, but
still not a reference manual. Use collapsible `<details>` sections for
config examples and advanced usage so they do not bloat the scan path.

**The project is a library, not a tool.** Replace Install + Quick Start
with Install + Minimal Usage Example. The code block should show import,
initialization, and one meaningful call. Keep it under 10 lines.

**The project is an API.** Lead with a curl example that returns real
data. Authentication setup goes in a collapsed section or docs link.

**Monorepo with multiple packages.** One top-level README with a table
of packages (name, one-liner, link to package README). Each package
README follows this same hierarchy.
