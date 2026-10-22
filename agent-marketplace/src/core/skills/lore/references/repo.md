# Repo surface

The codebase and its forge: commits, blame, comments, tests, in-repo ADRs and
changelogs, pull requests, review threads, issues, discussions, and ownership
files. The record sits closest to the code, and review-time rationale is
usually the best Direct evidence available.

## Anchor recipe

Bound every command's output (`--oneline`, a path, a date range); unscoped
`log -p` floods context.

```sh
git blame -w -M -C -L <start>,<end> -- <file>   # last touch per line, ignoring moves and whitespace
git log --follow --oneline -- <file>            # history through renames
git log -S '<exact text>' --oneline -- <path>   # commits that added or removed the text
git log -G '<regex>' --oneline -- <path>        # commits whose diff matches
git log -L <start>,<end>:<file> --no-patch --oneline   # commits that shaped a line range
git log -1 --format=%B <sha>                    # full message and trailers
git show <sha> -- <file>                        # what the commit changed in the file
git show <sha>^:<file>                          # the file as it was before the commit
```

Pass `--ignore-revs-file .git-blame-ignore-revs` to blame when that file
exists. A blame or pickaxe hit only locates a candidate commit. Confirm it by
reading the commit's diff against its parent; the last toucher is often a
reformat, move, or merge rather than the author of the decision.

Find a commit's pull request through the forge, which also works for merge and
rebase workflows where the subject carries no `(#123)`:

```sh
gh api repos/{owner}/{repo}/commits/<sha>/pulls --jq '.[] | {number, title, html_url}'
gh pr view <n> --json title,body,author,mergedAt,labels,closingIssuesReferences,comments,reviews
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments   # every inline review comment
gh issue view <n> --comments
```

Then read nearby: comments and TODOs around the target, tests that exercise
it (their names and cases often encode the motivating edge case), files that
changed in the same commits, `docs/adr/` or similar, and changelog entries.
Record ticket IDs, URLs, and quoted error strings from every message and body;
they seed the other surfaces.

Check the clone before trusting history:

- **Shallow** (`git rev-parse --is-shallow-repository` prints `true`): history
  stops at the clone boundary, so the earliest commit, blame, and pickaxe are
  silently wrong. Use the forge API (`gh api
  repos/{owner}/{repo}/commits?path=<file>`, `gh search prs`) for anything older.
- **Partial** (`git config remote.origin.promisor` prints `true`): history is
  complete, but blame and pickaxe fetch missing objects one by one and can run
  for an hour. Run history reads with `GIT_NO_LAZY_FETCH=1`, scoped to a path
  and range; a missing-object error calls for a narrow fetch or the forge API,
  which also suits repo-wide text searches.

Without forge access (no `gh` auth or a non-GitHub remote), record the
forge fields as unreachable and continue from git alone.

## Question shapes

- **Why / bug or deliberate**: the commit message, PR body, and review threads
  of the commit that introduced the shape. A review comment that raised the
  alternative and was answered is the strongest "deliberate" signal.
- **Provenance of a number or setting**: pickaxe on the literal, then the PR
  that introduced it and anything it links (benchmarks, load tests, incidents).
- **Precedent** ("how did we do X before"): `git log --grep`, `gh search prs`
  with the task's terms, and the diff shape of the earlier change.
- **Ownership**: `CODEOWNERS` and similar files, frequent recent committers
  (`git shortlog -sn --since=<date> -- <path>`), and recent reviewers.
- **In-flight work**: `gh pr list --search '<path or symbol>'` for open PRs
  touching the same code.

## Pitfalls

- **Recency bias.** The latest commit is rarely the decision; trace back to the
  first appearance of the shape.
- **Blame is not authorship.** Squashes, reformats, vendoring, and moves
  reassign lines.
- **Mechanics are not motivation.** A diff shows what changed; only text an
  author wrote shows why.
