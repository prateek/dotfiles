---
name: ask
description: Fetch version-matched dependency docs, source, and producer skills with `ask`. Use for library API docs, internal behavior, or source pinned to a project version or ref, especially when recalled knowledge may be stale. Skip when the user supplied the source file.
allowed-tools: Bash(ask:*)
---

# Read Version-Matched Docs and Source with `ask`

Use `ask` when a dependency's installed version or source matters. It resolves npm versions from the project's lockfile (`bun.lock → package-lock.json → pnpm-lock.yaml → yarn.lock → package.json` range fallback), fetches docs or source once, and caches the checkout globally under `~/.ask/` (or `ASK_HOME`). It prints absolute paths to stdout and sends progress and errors to stderr, so command substitution remains safe:

```bash
# Docs — one candidate directory per line
cat "$(ask docs zod | head -n1)"/README.md
rg "parseAsync" $(ask docs zod)

# Source — one absolute path to the checkout root
rg "ZodError" $(ask src zod)
fd -e test.ts . $(ask src zod)

# Producer skills — one /skills/ directory per line
ls $(ask skills vercel/ai)
```

`ask docs` prints candidate documentation directories. It checks publish-time `dist/docs` first, then directories whose basename matches `/doc/i` through depth 4, and uses the checkout root if none match. `ask src` prints exactly one path: the checkout root. Either command fetches on a cache miss; add `--no-fetch` to fail with exit 1 instead. `ask skills <spec>` finds producer-shipped skill directories and is equivalent to `ask skills list <spec>`.

## Choose a spec

Bare package names use the npm ecosystem and the project's lockfile version. Use an explicit ecosystem or ref when needed:

```text
zod                         # bare npm package; resolve from lockfile
npm:next                    # explicit npm ecosystem
npm:@mastra/client-js       # scoped npm package
facebook/react              # GitHub repo; defaults to main
github:vercel/next.js@v14.2.3   # pinned tag
github:owner/repo@main          # pinned branch
```

For npm packages, append `@version` to pin a version, for example `zod@3.22.0` or `npm:next@14.2.3`. For GitHub specs, `@<ref>` pins a tag or branch; bare `owner/repo` defaults to `main`. Reading commands accept mutable refs such as `main` and `master` because they do not persist changes.

All three commands share `ensureCheckout`, so the same spec reuses its cached path. Running `ask docs`, `ask src`, and `ask skills list` for one spec fetches it only once.

The reading forms are `ask docs <spec> [--no-fetch]`, `ask src <spec> [--no-fetch]`, and `ask skills <spec>` (also `ask skills list <spec>`). The first two print one or more paths as described above; the skills form prints one `/skills/` directory per line.

## Pick the right source

- Use docs when you need the installed version's README, guides, or handwritten documentation.
- Use source when behavior, edge cases, error paths, or internal helpers are not settled by the public types or docs.
- Use `ask skills list <spec>` when the library may ship its own agent skills.
- Skip `ask` when TypeScript, LSP, or intellisense answers the question, or when the user supplied the exact source file.

Version-matched material prevents API details from drifting with training data. Lockfiles and pinned refs anchor the read to the dependency the project actually uses.

## Load references when needed

- For cache cleanup, staleness, `--kind` or `--older-than` filters, or legacy v1 layout migration, read [`references/cache.md`](references/cache.md).
- For project-level configuration with `ask.json`, `ask install`, `ask add`, `ask remove`, `ask list`, generated `AGENTS.md`, or per-library `.claude/skills/<name>-docs/SKILL.md`, read [`references/declarative-workflow.md`](references/declarative-workflow.md).
- For vendoring producer skills with `ask skills install`, `--force`, `--agent claude,cursor,opencode,codex`, or `ask skills remove --ignore-missing`, read [`references/skills-vendoring.md`](references/skills-vendoring.md).
