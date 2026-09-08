# Review history

Use this procedure for `auto` and `confirm`. Inspect the last `X` first-parent
commits from the fetched target `BASE`: 20 by default, or the positive count
specified by the user/repository. Keep the requested count unchanged.

```sh
git -C "$WT" rev-list --first-parent --max-count="$X" "$BASE"
git -C "$WT" log --first-parent --max-count="$X" --format=fuller "$BASE"
git -C "$WT" rev-parse --is-shallow-repository
```

A sample is complete after X commits, or every available commit back to a verified
non-shallow root. Report shorter complete history as "N of X requested; all
available history". Missing ancestry, inaccessible pages, failed lookups, and
uncertain attribution remain unknown; attempt available read-only resolution.

For each sampled commit, inspect merged PR/MR associations targeting this repo
and branch, submitted reviews, substantive discussion, and commit comments.
Follow review trailers, available external review links, and documented Git-note
conventions. GitHub's concrete lookups are in
[GitHub evidence](github-review-evidence.md); use equivalent records on other hosts.

A human reviewing someone else's code is a signal, including an owner reviewing
a bot's change or giving substantive feedback outside a formal review. Check the
author, content, timing, and automation attribution. Historical criticism and
dismissed reviews count as review activity, not approval of the landed revision.
A `Reviewed-by`/`Acked-by` trailer remains a signal if its backing record is missing.
Signatures, `Signed-off-by`, co-authorship, and passing CI do not establish review.

PR use alone does not establish human review. Owner/automation-only PRs can fit a
solo workflow after their evidence lookups succeed. Known bots and attributed
agents do not count as humans; `type=User` alone does not prove human authorship.
Resolve other human participation before calling the workflow solo. Repository
ownership and a single commit author alone are insufficient.

Report requested/inspected counts and `BASE`, commits with merged-PR associations,
human-review signals, and unknowns separately, with representative SHAs/links.
Say "no human-review signals found in N inspected commits" when applicable;
available records cannot rule out offline review. Use the route in `SKILL.md`.
