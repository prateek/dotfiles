---
name: llms-txt-from-website
description: Generate `llms.txt` and `llms-full.txt` for a docs/product website from just a URL. Detect and reuse an existing `/llms.txt`, discover the docs source repo via “Edit this page”/GitHub links, fall back to `sitemap.xml` or an internal crawl when needed, and optionally use Context7 when the target is a known library.
---

# llms.txt from Website

Generate a high-signal `llms.txt` (curated manifest) plus `llms-full.txt` (full text bundle) even when you don’t know the site stack and there’s no sitemap.

## Quick start

```bash
python "<path-to-skill>/scripts/generate_llms_files.py" \
  --url "https://docs.example.com/" \
  --out "./llms-out"
```

Outputs:

- `./llms-out/<slug>/llms.txt`
- `./llms-out/<slug>/llms-full.txt`
- `./llms-out/<slug>/metadata.json`

Print generation metadata (useful for debugging / chaining):

```bash
python "<path-to-skill>/scripts/generate_llms_files.py" --url "<url>" --out "./llms-out" --json
```

## Workflow (decision order)

### 1) Reuse existing files (best case)

- Fetch and reuse `/<root>/llms.txt` (also try the exact docs subpath root the user gave you).
- If `llms-full.txt` exists too, download it.
- If only `llms.txt` exists, generate `llms-full.txt` by converting the linked pages (prefer `*.md` endpoints when the site supports them; else use `uvx markitdown`).

### 2) Prefer docs source over crawling (higher quality)

- Fetch the homepage HTML and look for:
  - “Edit this page”, “View source”, “GitHub”, “Repository” links
  - Any `github.com/<owner>/<repo>` references
- Clone the repo (shallow) and extract docs markdown (`.md`, `.mdx`, `.rst`).
- If the repo is huge, use `repomix` with include patterns to pack only the docs subtree.
- If repo discovery fails but you strongly suspect a public repo exists, do a quick web search for “<project> docs github” and re-run with the docs URL (the script discovers repos from the site HTML).

### 3) Fall back to sitemap, then crawl

- Try `robots.txt` for `Sitemap:` hints and `/sitemap.xml`.
- If no sitemap, crawl internal links starting from the provided URL (cap pages/depth).

### 4) Produce outputs

`llms.txt`:

- Follow the common manifest shape:
  - `# <Project/Docs name>`
  - `> <1 sentence summary>`
  - (no headings) a few lines of context
  - `##` sections containing bullet lists: `- [Name](URL)`
  - Put non-essential links under `## Optional`
- Use absolute URLs in link targets (avoid local file paths).
- Keep traceability (repo file paths, etc.) out of `llms.txt` by default; use `metadata.json` and/or `--include-source-links` when you need provenance.

`llms-full.txt`:

- If a docs repo was found: pack the docs sources (prefer raw markdown) into one file (repomix or concatenation).
- Else: convert top pages to markdown (`uvx markitdown <url>`) and concatenate them with clear separators.

## Optional: Context7 (library docs)

Use this when the target is a known software library/framework and Context7 MCP is available.

- Resolve a library ID:
  - tool: `resolve-library-id`
  - inputs: `libraryName`, `query`
- Retrieve relevant docs:
  - tool: `query-docs`
  - inputs: `libraryId`, `query`
- Use Context7 output to fill gaps (e.g., missing API reference) and to cross-check the repo/crawl outputs.

## Script options

- `--max-pages`: cap for sitemap/crawl (default is conservative)
- `--full-scope all|selected`: include all docs sources or only the curated subset
- `--max-full-bytes`: safety cap before falling back to `selected` (unless `--force-full`)
- `--no-crawl`: stop after “existing llms” + “repo discovery” attempts
- `--include-source-links`: add absolute “source” URLs (e.g. GitHub blob) next to each link in `llms.txt`
