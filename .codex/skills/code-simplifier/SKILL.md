---
name: code-simplifier
description: Simplify and refine code for clarity, consistency, and maintainability while preserving behavior. Use for refactor/simplify requests, polishing PR diffs, or cleaning up recently modified code without changing outputs.
---

# Code Simplifier

## Goal

Refactor code to be easier to read and maintain without changing what it does. Prefer explicit, straightforward code over clever compactness.

## Scope

- Default to the most recently modified code (current diff/PR, staged changes, or the snippet the user provided).
- Don’t refactor unrelated areas unless explicitly requested.

## Workflow

1. Identify the target
   - Prefer a small, reviewable surface area: touched files/functions/lines.
   - If working in a repo, start from `git diff`/`git status` to find what changed.

2. Preserve behavior
   - Keep inputs/outputs, side effects, error semantics, and public APIs identical.
   - Avoid “refactors” that change ordering, timing, or edge-case handling unless requested.

3. Follow project standards
   - Apply repo-local guidance first (e.g., `AGENTS.md`, `CLAUDE.md`, linters/formatters, adjacent code patterns).
   - Match naming, module boundaries, error handling, and formatting conventions already in use.

4. Simplify for clarity (choose the least disruptive option)
   - Reduce unnecessary nesting and branching; prefer early returns when they clarify flow.
   - Remove redundant code and abstractions; consolidate tightly related logic.
   - Use descriptive names for variables, functions, and types; keep responsibilities focused.
   - Avoid nested ternary operators; use `if/else` chains or `switch` for multi-branch logic.
   - Delete comments that restate obvious code; keep comments that explain “why” or tricky constraints.

5. Validate
   - Run the smallest relevant checks (tests, typecheck, build) if available.
   - Keep diffs focused and easy to review.

## Output expectations

- Make minimal, behavior-preserving changes that improve readability and maintainability.
- Prefer small, local refactors over broad rewrites.
- Summarize only the meaningful structure changes (e.g., simplified control flow, removed redundancy, clearer naming).
