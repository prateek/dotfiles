---
name: skills-searcher
description: Search for installable agent skills across GitHub and skills.sh. Use when Codex needs to find SKILL.md files, compare candidates, inspect skill metadata, validate search backends, diagnose GitHub search rate limits, or produce install commands from gh skill search, Sourcegraph, GitHub code search, and npx skills results.
---

# Skills Searcher

Use the bundled CLI to search all backends together. Its script is self-contained and uses only Python's standard library through a `uv run --script` shebang. Paths in this skill are relative to its base directory.

Use the short command when it is installed:

```bash
~/bin/skill-search search <query> --limit 10 --progress
```

Otherwise run the bundled script:

```bash
scripts/skill-search search <query> --limit 10 --progress
```

## Search and rank candidates

1. In a new environment, run `skill-search doctor` first to check local tools and backend connectivity.
2. Search with `skill-search search <query> --limit 10 --progress`. The CLI queries all available backends in parallel; do not ask the user to choose one.
3. Use `--sort-by installs --direction desc` as a second view when popularity is likely to help decide among skills for a mainstream framework, language, or tool. Installs come only from the skills.sh backend.
4. Compare stars, installs, and source count as signals. Agreement from at least two independent backends is the strongest precision signal because each indexes a different part of the ecosystem.
5. Check authorship before choosing a winner. Prefer the framework vendor, platform owner, or a widely cited domain educator when they authored a candidate. Authorship can outweigh a third-party collection's stronger raw counts; use multi-source agreement to break ties between peers.

## Inspect finalists

Read each finalist's `SKILL.md` before recommending it. Say in one sentence whether its scope matches the query's narrow meaning or covers only adjacent territory. For example, “anti-slop writing” is narrower than “writing quality,” and “React performance” is narrower than “React.” Drop adjacent-only matches even when their stars or install counts are higher.

Treat these thresholds as caution signals, not hard gates:

- Prefer skills with at least 1K installs; scrutinize counts below 100. A missing install count is neutral because only the skills.sh backend provides it.
- Scrutinize skills from repositories with fewer than 100 stars unless agreement across sources compensates.
- For niche topics such as chezmoi, plist merge engines, or Tart, mainstream thresholds can exclude every candidate. Recommend the strongest candidate confirmed by multiple sources with clear caveats, or say that none meets the usual thresholds and offer direct help. Suggest `npx skills init <name>` when scaffolding a local skill would help.

When the user asks to install a skill, use the install command shown in that result row.

## Commands

```bash
skill-search doctor
skill-search --json doctor
skill-search search "chezmoi dotfiles" --limit 25 --progress
skill-search --json search "react testing" --limit 25 --no-progress
skill-search search "github pr review" --sort-by sources --direction desc
skill-search raw sourcegraph "chezmoi dotfiles"
```

The `--json` option emits structured JSON for search and doctor. The search output includes preview and install commands alongside each result.

Sort fields are `stars`, `installs`, `sources`, `file-commits`, `repo-commits`, and `skill-name`.

Use `--no-enrich` when GitHub enrichment is slow or rate-limited. Use `--github-concurrency <n>` to tune parallel GitHub API calls during enrichment; the default is conservative.

## Backends

Each backend reaches a different part of the ecosystem:

- `gh skill search` is a narrow, curated GitHub-native index with high precision and lower recall.
- Sourcegraph `src search` finds skills in registry-style aggregators that GitHub-native indexes may miss.
- GitHub code search through `gh api /search/code` finds raw `SKILL.md` matches, including dotfiles and tooling repositories that registries have not indexed.
- `npx skills find` is the only source of install counts; use it when popularity matters.

## Sourcegraph query shape

The Sourcegraph backend builds queries in this form:

```text
file:(?i)skill\.md <terms> select:file count:<limit> timeout:<seconds>s
```

Each term expands to `(file:<term> OR repo:<term> OR content:/(?m)^(name|description):.*<term>/)`. Results must match a term in the `SKILL.md` path, repository name, or frontmatter `name:`/`description:` line. Body matches are excluded because they surfaced skills that only mentioned a term in passing. Keep `select:file` so Sourcegraph returns file-level matches, and `(?i)` so filename matching is case-insensitive.

## Rate limits

GitHub skill search and GitHub code search may hit search quotas or secondary rate limits. Check the quota. If GitHub enrichment calls are rate-limited, retry with `--no-enrich` to skip them; a search backend that is itself rate-limited may remain unavailable:

```bash
gh api rate_limit
skill-search search <query> --no-enrich
```

While GitHub recovers, use Sourcegraph and `npx skills` results. Keep `--limit` small during exploration, and avoid tight retry loops against GitHub.

## Validation

After editing this skill, run:

```bash
python3 -m py_compile scripts/skill-search
zsh tests/skill-search.zsh
```

From the dotfiles checkout, run:

```bash
zsh agent-marketplace/packages/utils-agent/skills/skills-searcher/tests/skill-search.zsh
```
