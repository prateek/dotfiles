---
name: skills-searcher
description: Search for installable agent skills across GitHub and skills.sh. Use when Codex needs to find SKILL.md files, compare skill candidates, inspect skill metadata, validate skill-search backends, diagnose GitHub skill-search rate limits, or produce install commands from gh skill search, Sourcegraph, GitHub code search, and npx skills results.
---

# Skills Searcher

Use the bundled CLI instead of hand-rolling GitHub or Sourcegraph queries.

```bash
~/.agents/skills/skills-searcher/scripts/skill-search search <query> --limit 10 --progress
```

If `~/bin/skill-search` is available, use that shorter command. The script is self-contained and uses a `uv run --script` shebang with only Python standard-library code.

## Workflow

1. Run `skill-search doctor` in a new environment.
2. Run `skill-search search <query> --limit 10 --progress`. When popularity is likely the deciding signal — a mainstream framework, language, or tool with an established author/educator ecosystem — also try `--sort-by installs --direction desc` to see the skills.sh ranking inline.
3. Prefer candidates with higher stars, higher installs, and multiple sources. A hit confirmed by 2+ independent backends is the strongest precision signal — each backend indexes a different surface, so agreement is rare and meaningful.
4. Check for an obvious upstream authority before picking a winner: the framework's vendor (Microsoft for Playwright, Vercel for Next.js, Apple for Swift), the platform owner, or a widely-cited domain educator (e.g. `twostraws`/Paul Hudson for SwiftUI, `avanderlee` for Swift concurrency). If a candidate is authored by that authority, prefer it even when a third-party collection has more raw signal. Multi-source agreement breaks ties between peers; it does not override authorship.
5. Read unfamiliar `SKILL.md` files before recommending. For each finalist, state in one sentence whether the SKILL.md scope matches the *narrow* semantics of the query or merely adjacent territory — "anti-slop writing" is narrower than "writing quality"; "React performance" is narrower than "React". Drop adjacent-only matches even if their stars or installs are higher.
6. Apply quality caution thresholds, but treat them as guardrails, not gates:
   - **Install count**: prefer 1K+; treat below 100 with skepticism. Missing values are not a negative signal — install counts come from the `skills-cli` backend only.
   - **Repo stars**: treat skills from repos with fewer than 100 stars with skepticism, unless multi-source agreement compensates.
   - **Niche domains**: when a topic is genuinely small (e.g. chezmoi, plist merge engines, Tart), the install/star bars calibrated for mainstream ecosystems will exclude everything. Don't refuse to recommend — fall back to the strongest multi-source-confirmed candidate with explicit caveats, or say plainly that no candidate meets the bars and offer to help directly (`npx skills init <name>` to scaffold a local skill is fine to suggest).
7. Use the install command from the result row when the user asks to install a skill.

The search command runs all backends automatically and in parallel. Do not ask the user to choose a backend.

Backends — complementary, not redundant. Each reaches a different corner of the ecosystem:

- `gh skill search` — narrow, curated GitHub-native skill index. Highest precision, lowest recall.
- Sourcegraph `src search` — best for skills hosted in registry-style aggregators that the GitHub-native indexes don't cover.
- GitHub code search via `gh api /search/code` — raw `SKILL.md` matches across GitHub, catches dotfiles and tooling repos that haven't been indexed by any registry.
- `npx skills find` — the only backend with install counts; reach for it when popularity matters.

## Commands

```bash
skill-search doctor
skill-search --json doctor
skill-search search "chezmoi dotfiles" --limit 25 --progress
skill-search --json search "react testing" --limit 25 --no-progress
skill-search search "github pr review" --sort-by sources --direction desc
skill-search raw sourcegraph "chezmoi dotfiles"
```

Useful sort fields:

- `stars`
- `installs`
- `sources`
- `file-commits`
- `repo-commits`
- `skill-name`

Use `--no-enrich` when GitHub enrichment is slow or rate-limited. Use `--github-concurrency <n>` to tune parallel GitHub API calls during enrichment; the default is conservative.

## Sourcegraph Query Shape

The Sourcegraph backend uses:

```text
file:(?i)skill\.md <terms> select:file count:<limit> timeout:<seconds>s
```

Each token expands to `(file:<token> OR repo:<token> OR content:/(?m)^(name|description):.*<token>/)`, so a hit must have the term in the SKILL.md path, the repo name, or a frontmatter `name:` / `description:` line. Body-content matches are excluded — they used to surface skills that merely mentioned the term in passing.

Keep `select:file`; it returns file-level matches. `(?i)` keeps filename matching case-insensitive.

## Rate Limits

GitHub skill search and GitHub code search can hit search quotas or secondary rate limits. When that happens:

```bash
gh api rate_limit
skill-search search <query> --no-enrich
```

Use Sourcegraph and `npx skills` results while GitHub recovers. Keep `--limit` small during exploration. Do not retry GitHub search in a tight loop.

## Validation

After editing this skill, run:

```bash
python3 -m py_compile ~/.agents/skills/skills-searcher/scripts/skill-search
zsh ~/.agents/skills/skills-searcher/tests/skill-search.zsh
```

When working from this dotfiles checkout, run:

```bash
zsh home/dot_agents/skills/skills-searcher/tests/skill-search.zsh
```
