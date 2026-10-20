---
name: readme-craft
description: |
  Write, rewrite, or audit READMEs for fast adoption. Use for new, bloated,
  stale, or marketing-heavy READMEs, especially when install and quick-start
  guidance is buried or duplicated by a docs site.
---

# README Craft

Treat a README as a plain-text landing page. Help a new reader understand the project, install it, and see it work before asking them to read further. Keep reference detail on the documentation site when one exists.

## README order

Use this hierarchy, moving optional material lower or into docs. The first 29 lines should orient and activate a reader; install should appear within 20 lines and quick start within 30.

1. **Title and one-liner** (2–3 lines): say what the project does and why it matters in one or two factual sentences. Name the audience through the use case and include concrete trust signals; avoid generic adjectives.
2. **Hero image or screenshot** (optional, one): show the product rather than its logo. For public projects, prefer an externally hosted image so updates do not add binary files to Git history.
3. **Install** (5–8 lines): show the fastest route from zero to installed in one code block, or two when separating platforms such as macOS/Linux and Windows. Put build-from-source instructions under Development.
4. **Quick start** (3–5 lines): show one or two commands that produce visible output. Put short explanations in inline comments.
5. **Primary features**: order by the path requiring the least setup. Give one or two sections with brief introductions, 3–5 real commands where useful, and scannable capability bullets.
6. **Screenshots** (optional): use a 2×2 or 2×1 table to control layout. Skip explanatory prose; a screenshot should make the interface clear.
7. **Secondary features** (optional, 1–2): use the same short example-and-bullets pattern.
8. **Compatibility**: show supported platforms, agents, or languages in a table.
9. **Privacy and security** (when relevant): state the facts in 3–5 sentences.
10. **Documentation**: link to the docs site without repeating its content.
11. **Contributor material**: put a horizontal rule before Development, then list only essential prerequisites, build and test commands (about 10–15 lines). Project layout and acknowledgements are optional; put the license in one line.

A reader who stops after the opening should still know what the project does and how to try it. For example:

````markdown
# agentsview

Browse, search, and track costs across your AI coding agents. One binary,
no accounts, everything local.

## Install

```bash
curl -fsSL https://agentsview.io/install.sh | bash
```

## Quick Start

```bash
agentsview                 # start server, open web UI
agentsview usage daily     # print daily cost summary
```
````

## Write the one-liner

Use an action verb and concrete object, identify the target user through the use case, and compress trust signals into specific facts:

> Browse, search, and track costs across all your AI coding agents. One binary, no accounts, everything local.

Avoid vague noun phrases and claims such as “powerful” or “intuitive.” “Managing and analyzing your AI coding sessions with an intuitive interface” says little about the actual behavior and offers no evidence.

## Keep the copy factual

Describe what the project does and what the reader can do. Remove generic sales language such as “powerful,” “seamless,” “game-changing,” “revolutionary,” “cutting-edge,” “robust,” “elegant,” “intuitive,” “effortless,” “next-generation,” “supercharge,” “unlock,” and “leverage” as a verb.

Replace emotional or indirect patterns with direct statements:

- “Never lose track of…” → state the feature.
- “Say goodbye to…” → state the behavior.
- “Whether you’re a…or a…” → name the supported audience or cases.
- “With X, you can…” → begin with what X does.

For example, replace “Never lose track of that clever solution your agent came up with three weeks ago” with “A local web application for browsing, searching, and analyzing AI agent coding sessions.”

## Keep the README focused

- **Config dumps:** the README is not a reference manual. Move configuration examples longer than five lines to the docs and link to them. A project README once carried Caddy TLS and subnet rules, PostgreSQL blocks, desktop environment overrides, and Linux `setcap` instructions; one-line links to the relevant guides serve readers better.
- **Feature sprawl:** show 2–3 primary features with examples. Summarize the rest in bullets or table rows and link to details.
- **Marketing copy:** delete adjectives that could describe any software project. If the sentence becomes empty, it was not conveying useful information.
- **Audience collision:** separate user instructions from contributor instructions with `---` so install guidance is easy to find.
- **Stale screenshots:** prefer externally hosted screenshots referenced by URL. Checked-in images can become stale and add to Git history.

When a docs site exists, the README names features and links to explanations; setup details and configuration belong on the site. A compact navigation block works well:

```markdown
## Documentation

Full docs at **[example.io](https://example.io)**:
[Quick Start](https://example.io/quickstart/) --
[Usage Guide](https://example.io/usage/) --
[CLI Reference](https://example.io/commands/)
```

## Write a new README

1. Identify the project in one factual sentence, without generic adjectives.
2. Find the fastest install path and the one command that demonstrates the project working.
3. Draft the opening hierarchy: title, one-liner, install, and quick start.
4. Add one or two feature sections with useful examples, then a compatibility table.
5. Put contributor setup below a horizontal rule; add layout, acknowledgements, or license only when useful.
6. If the README exceeds 200 lines, inspect each section for material that belongs in docs.
7. Read from the top as a new visitor. Confirm the purpose, install path, and working example are clear before attention runs out.

## Rewrite an existing README

Use this workflow when the README is bloated (typically 150+ lines), contains configuration dumps or marketing language, or repeats a docs site:

1. Count lines, inventory sections, and identify the docs site.
2. Decide for each section whether to keep, trim, or move it to docs. Check where install and quick start appear; if either is below line 30, fix the hierarchy.
3. Draft a new structure from the old README’s useful facts. Move config blocks longer than five lines to docs, compress secondary features, link instead of duplicating docs, remove sales language, and separate user and contributor sections.
4. Write the new draft from scratch, carrying over accurate details and links.
5. Compare line counts. A typical rewrite cuts 40–60%; if it grows, review what was added and why.
6. Verify every link, including external docs links.

A worked `agentsview` rewrite went from 370 to 177 lines (52% shorter): it moved Caddy, PostgreSQL, and reverse-proxy setup to the docs site; removed keyboard shortcuts available in-app via `?`; dropped a “Why?” section already covered by the one-liner; moved source builds to Development; promoted zero-setup token usage; and shortened Privacy from 12 lines to 4.

## Audit a README

Evaluate every item and mark it pass or fail. Report failed items with line numbers and rank the recommended changes by impact.

```text
[ ] One-liner exists and contains no generic adjectives
[ ] Install appears within the first 20 lines
[ ] Quick start appears within the first 30 lines
[ ] No configuration block exceeds 5 lines
[ ] No marketing language
[ ] Screenshots are hosted externally, not stored in the repository
[ ] User content is separated from contributor content
[ ] Docs-site content is not duplicated
[ ] Total length is under 200 lines (under 250 with large tables)
[ ] Every external link resolves
[ ] Features are ordered by least setup required
[ ] Tables present scan-friendly data such as agents, platforms, or shortcuts
```

## Return the requested deliverable

- **Write or rewrite:** provide the complete README in one code block, a brief summary of editorial decisions (what changed and why), and for rewrites a before/after line count.
- **Audit:** provide the checklist with each item marked pass or fail, specific findings with line numbers, and recommendations ranked by impact.

## Adapt to project type

- **No docs site:** include enough detail to use the project without turning the README into a reference manual. Put advanced usage and configuration in collapsible `<details>` sections.
- **Library:** replace Install + Quick Start with Install + Minimal Usage Example. Show import, initialization, and one meaningful call in fewer than 10 lines.
- **API:** lead with a `curl` example that returns real data. Put authentication setup in a collapsed section or docs link.
- **Monorepo:** use one top-level README with a table of package names, one-line descriptions, and links to each package README. Each package README follows this hierarchy.
