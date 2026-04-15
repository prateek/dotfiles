---
name: code-gardening
description: Continuous codebase-health workflow for existing repositories. Use when code, tests, docs, comments, examples, config, generated files, plans, or agent instructions may be out of sync; when a task touches `AGENTS.md`, `CLAUDE.md`, `README`, `SKILL.md`, plan/progress/spec docs, build/config files, or parser-facing metadata; when a parser, validator, or config error suggests stale state; when a failure may be pre-existing; or when a bugfix or command/config change should sync nearby durable docs, tests, or config. Do not use for ordinary read-only code review, isolated implementation with no state-sync risk, or pure brainstorming unless drift, provenance, or durable-state updates are part of the task.
---

# Code Gardening

## Overview

Use this skill to keep touched codebases trustworthy without turning every task into a cleanup project.

Gardening means:
- fix cheap local drift
- recover intent before changing ambiguous behavior
- update durable state when facts change
- surface broader drift instead of quietly routing around it

Gardening does not mean unrelated churn, stealth rewrites, or long essays in root instruction files.

## Trigger Check

Use this skill when any of these are true:

- Code, tests, docs, comments, examples, or config disagree.
- The task touches `AGENTS.md`, `CLAUDE.md`, `README`, `SKILL.md`, plan/progress/spec docs, or build/config files.
- A parser, validator, or config error hints at stale state.
- A failure may be pre-existing.
- The same confusion or bug has appeared more than once.
- You are closing out a non-trivial change and need to sync durable state.

Skip this skill for greenfield brainstorming, pure research, or tiny isolated edits with no durable-state impact.

## Trigger Boundaries

Should trigger:

- `I changed this CLI command. Update the README, examples, and any stale comments or agent docs.`
- `This skill's frontmatter stopped parsing after I edited SKILL.md and openai.yaml. Fix the drift and validate it.`
- `The test is failing, but I do not trust that my change caused it. Check what is pre-existing before we patch around it.`
- `I fixed the behavior in this module. Make sure nearby tests, docs, and config still match.`

Should not trigger by itself:

- `Review this diff for bugs only. Do not suggest unrelated cleanup.`
- `Implement this isolated feature in a new module.`
- `Brainstorm three approaches for this greenfield feature.`
- `Do a cold read of this spec and tell me what the repo is trying to do.`

If another skill already owns the task shape, keep that skill primary. Use gardening only when drift, provenance, or state sync becomes part of the work.

## Workflow

### 1. Go See The Work

- Read the actual file, not just the excerpt.
- Run the actual command, test, build, parser, or validator when feasible.
- Inspect logs and outputs before speculating.

If the file is large, shared, or foundational, read the whole thing before editing.

### 2. Classify The Drift

Fix now:
- stale nearby comment or docstring
- renamed command/example mismatch
- small style mismatch in code you are already touching
- missing state update tightly coupled to the task
- stale plan/progress entry when the prompt explicitly uses those docs

Surface before leaving:
- cross-cutting or behavior-changing drift
- unclear authority between code, docs, comments, and tests
- parser/config failures you cannot confidently fix in scope
- anything that would require a rewrite or broad cleanup to resolve

### 3. Pick The Working Edge

When multiple surfaces disagree, decide what is authoritative before editing.

Usual order:
1. Observed behavior and passing tests
2. Tool-native truth such as parsers, compilers, `git check-ignore`, generated outputs, or schema validators
3. Current docs/specs that still match the system
4. Comments and stale prose

Do not treat comments as stronger evidence than the system they describe.

### 4. Run Archaeology When Intent Is Fuzzy

Start cheap:
- `git status`
- `git diff`
- `git log --follow -- <file>`
- `git log -S 'term' -- <path>`
- `git log -G 'pattern' -- <path>`

Escalate when provenance is still unclear:
- `git blame -w -M -C <file>`
- related PRs, review comments, issues, ADRs, or design notes

When the change is large, contentious, or context-contaminated, spawn an `explorer` for a cold archaeology pass.

Use a bounded prompt like:

```text
Read the current code/tests/docs for <path>. Reconstruct intent from behavior, history, and review context. Return only:
1. durable findings
2. contradictions
3. likely source of truth
4. what should be synced now vs surfaced
```

Do not default to archaeology on every task. Use it when local reading and normal verification are not enough.

### 5. Sync Durable State

State includes:
- code and tests
- comments and docstrings
- README/docs/examples
- plans, progress logs, and specs when they are part of the workflow
- config, build files, generated-file policy, and validator expectations
- agent guidance such as `AGENTS.md`, `CLAUDE.md`, and skill docs

If you change durable vocabulary, workflow, invariants, or operating assumptions, update the nearest durable state in the same task.

When editing prose humans will read, apply the `writing-clearly-and-concisely` guidance.

### 6. Validate The Boundary You Touched

- Use tool-native checks instead of regex guesses.
- After editing a skill, run its validator or parser immediately.
- If a failure may be pre-existing, baseline it early.
- Before commit or handoff on non-trivial work, run the smallest matching verification.

Examples:
- `git check-ignore` instead of hand-parsing `.gitignore`
- repo parser/validator instead of assuming frontmatter is valid
- skill validator after touching `SKILL.md` or `agents/openai.yaml`
- focused test target instead of claiming a regression without a baseline

### 7. Close With A Short Maintenance Note

Before finishing, ask:
- What drift did I fix?
- What drift remains?
- What durable state changed?
- Does a recurring lesson belong in `AGENTS.md` or a skill?

Keep this short. The goal is to leave the next reader with a trustworthy surface, not a diary.

## Do Not

- Use gardening as cover for unrelated cleanup.
- Rewrite ambiguous systems from scratch without permission.
- Bury uncertainty behind a “cleanup” label.
- Stuff one-off incident notes into `AGENTS.md`.
- Trust stale comments over observed behavior.
- Leave parser or validator drift unverified after touching skill or config files.
