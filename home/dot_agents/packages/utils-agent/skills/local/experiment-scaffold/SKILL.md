---
name: experiment-scaffold
description: "Create a new experiment workspace directory: initialize git, write an AGENTS.md goal doc, and create references/ with index.md + notes/links markdown plus local repo copies under references/repos (gitignored). Prefer canonical GRM clones when available, otherwise seed from a shared experiment cache. Use when the user asks to spin up a scratch/research/experiment folder and provides repos, links, and/or notes to collect."
---

# Experiment Scaffold

## Gather inputs

- Experiment directory name (a single path segment; no `/`)
- Goal (1–3 sentences: what you’re trying to learn/build/test)
- GitHub repos (repeatable; `owner/repo` or URL)
- Optional sparse checkout paths for large repos (`repo=path[,path...]`, repeatable)
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
  --repo langchain-ai/langchain \
  --repo-sparse langchain-ai/langchain=libs/langchain,cookbook \
  --repo facebookresearch/faiss \
  --url https://python.langchain.com/docs/concepts/retrievers/ \
  --note "Measure latency/recall across configs"
```

## What it creates

- `<root>/<name>/.gitignore` (ignores `references/repos/`)
- `<root>/<name>/AGENTS.md` (goal + pointer to `references/index.md`)
- `<root>/<name>/references/index.md` (inventory + clone status)
- `<root>/<name>/references/notes.md`
- `<root>/<name>/references/links.md`
- `<root>/<name>/references/repos/<owner>/<repo>` (local repo copy; gitignored)

## Repo materialization behavior

- If GRM is available and a canonical clone exists at `~/code/github.com/<owner>/<repo>`, the script fetches that clone and seeds the experiment copy from it.
- Otherwise it uses a shared cache under `~/code/experiments/reference-cache/<host>/<owner>/<repo>`, cloning there once and reusing it for later experiments.
- Experiment-local copies under `references/repos/` are made with `fastcp` when available for APFS copy-on-write behavior, then normalized to a clean default-branch checkout.
- Repos with `--repo-sparse REPO=PATH[,PATH...]` avoid full working-tree copies. If a canonical/cache repo already exists, the script creates a sparse shared clone from it. If no seed exists, it makes a direct sparse partial clone instead of populating the full shared cache.
- If a repo cannot be parsed as `owner/repo` or URL form, the script falls back to a direct clone into `references/repos/`.

## Cloning notes (`gh`, multiple accounts, SSH)

- Cache population still uses `gh repo clone` first and prefers SSH; it falls back if SSH/auth fails.
- If a repo fails to populate the cache and you use multiple GitHub accounts, check `gh auth status` and switch with `gh auth switch -u <user>`.
- To default `gh` to SSH cloning, set `gh config set git_protocol ssh`.

## Useful flags

- `--depth N` for a shallow clone (default: 0, which is a full clone with complete history)
- `--repo-sparse REPO=PATH[,PATH...]` to sparse-checkout only the listed repo-relative paths for one `--repo`; repeat it for more paths or repos
- `--no-clone` to generate structure without cloning
- `--strict` to stop on the first clone failure (otherwise record failures in `references/index.md`)
- `--canonical-root PATH` to override the canonical clone root
- `--cache-root PATH` to override the shared experiment cache root
- `--grm-mode auto|on|off` to control whether canonical reuse requires GRM

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
