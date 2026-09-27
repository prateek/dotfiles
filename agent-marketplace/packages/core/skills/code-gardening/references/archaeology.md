# Recover intent

Use history when current behavior, tests, and docs leave the intended contract unclear. Start with the relevant path and search term:

```sh
git status
git diff
git log --follow -- <file>
git log -S 'term' -- <path>
git log -G 'pattern' -- <path>
```

If those do not settle the question, inspect `git blame -w -M -C <file>` and related PRs, reviews, issues, ADRs, or design notes. For a large, contentious, or context-contaminated change, spawn a cold `explorer` pass with a bounded question when delegation is allowed:

```text
Read the current code/tests/docs for <path>. Reconstruct intent from behavior, history, and review context. Return only:
1. durable findings
2. contradictions
3. likely source of truth
4. what should be synced now vs surfaced
```

Finish when the evidence supports a source of truth or the unresolved alternatives are stated. Keep the original task's scope and delegation constraints.
