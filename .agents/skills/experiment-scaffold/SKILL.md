---
name: experiment-scaffold
description: "Create a new experiment workspace directory: initialize git, write an AGENTS.md goal doc, and create references/ with index.md + notes/links markdown plus GitHub repos cloned under references/repos (gitignored). Use when the user asks to spin up a scratch/research/experiment folder and provides repos, links, and/or notes to collect."
---

# Experiment Scaffold

## Gather inputs

- Experiment directory name (a single path segment; no `/`)
- Goal (1–3 sentences: what you’re trying to learn/build/test)
- GitHub repos (repeatable; `owner/repo` or URL)
- Reference URLs (repeatable; blogs/docs/API pages)
- Notes (repeatable; bullets)
- Optional root directory to create the experiment in (default: current directory)

## Run the scaffold script

The helper script is `scripts/create_experiment.py` (next to this SKILL.md). Run it with the extracted inputs.

Example:

```bash
python3 scripts/create_experiment.py \
  --root ~/experiments \
  --name vector-search \
  --goal "Evaluate hybrid search with embeddings vs BM25." \
  --repo openai/openai-python \
  --repo facebookresearch/faiss \
  --url https://platform.openai.com/docs/ \
  --note "Measure latency/recall across configs"
```

## What it creates

- `<root>/<name>/.gitignore` (ignores `references/repos/`)
- `<root>/<name>/AGENTS.md` (goal + pointer to `references/index.md`)
- `<root>/<name>/references/index.md` (inventory + clone status)
- `<root>/<name>/references/notes.md`
- `<root>/<name>/references/links.md`
- `<root>/<name>/references/repos/<owner>/<repo>` (cloned; gitignored)

## Cloning notes (`gh`, multiple accounts, SSH)

- The script tries `gh repo clone` first and prefers SSH; it falls back if SSH/auth fails.
- If a repo fails to clone and you have multiple GitHub accounts, check `gh auth status` and switch with `gh auth switch -u <user>`.
- To default `gh` to SSH cloning, set `gh config set git_protocol ssh`.

## Useful flags

- `--depth N` for a shallow clone (default: 0, which is a full clone with complete history)
- `--no-clone` to generate structure without cloning
- `--strict` to stop on the first clone failure (otherwise record failures in `references/index.md`)

## Fetch reference articles

After the scaffold script finishes, if `--url` flags were provided, download each URL as a local markdown file in `references/articles/`.

1. Create the `references/articles/` directory.
2. For each URL in `references/links.md`:
   - Use the available web-fetch or browsing capability to extract the article as clean, complete markdown. Preserve code snippets, headings, and technical details. Include the title, author, and date if available.
   - If the environment supports a named web tool, prefer the native fetch/read flow for that tool instead of inventing a separate scraper.
   - For GitHub issue/PR URLs, prefer `gh issue view` or `gh pr view` via Bash instead.
   - Write the result to `references/articles/{slug}.md` with YAML frontmatter:
     ```yaml
     ---
     source_url: <original URL>
     fetched_date: <today's date>
     topic: <short topic label>
     ---
     ```
   - Name the file descriptively (e.g., `wkwebview-headless-mode-devto.md`, not `article-1.md`).
3. If a URL fails to fetch (auth wall, timeout, empty response), skip it and note the failure in `references/index.md` under a "Fetch failures" section.
4. Run fetches in parallel when the environment supports it; otherwise fetch them sequentially after scaffold completion.
