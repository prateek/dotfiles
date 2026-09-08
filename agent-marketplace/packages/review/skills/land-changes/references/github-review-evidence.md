# GitHub evidence

Use the discovered destination `HOST`, `REPO` (`owner/name`), and `TARGET`.
URL-encode the branch as a path segment into `TARGET_ENCODED`. Keep errors visible
and paginate every list; a failed response is not an empty result.

## Live policy: every landing mode

```sh
gh api --hostname "$HOST" user
gh api --hostname "$HOST" "repos/$REPO"
gh api --hostname "$HOST" "repos/$REPO/branches/$TARGET_ENCODED"
gh api --hostname "$HOST" "repos/$REPO/branches/$TARGET_ENCODED/protection"
gh api --hostname "$HOST" --paginate \
  "repos/$REPO/rules/branches/$TARGET_ENCODED?per_page=100"
```

Resolve canonical repo identity, authenticated actor, and write permission. Check
classic PR/check requirements, restrictions, and admin enforcement alongside
[active branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch).
Evaluate PRs, queues, required checks, and restricted updates for this actual push.
Deletion/force-push restrictions alone permit a normal fast-forward. Required
checks must cover the final commit.

When a direct route depends on bypass, follow each rule's source type/name/ID
to its repository, organization, or enterprise ruleset. Repository rulesets use
`repos/$REPO/rulesets/$ID`. Match `bypass_actors` and `bypass_mode` to the actual
role, team, or app: administrator status alone proves neither eligibility nor
user authorization. Missing details leave policy unknown. A protection 404 can
mean absence of classic protection only when repo/branch access and the other
policy responses establish that interpretation; it does not clear rulesets.

Find open PRs using the source's actual owner, including forks:

```sh
gh api --hostname "$HOST" --method GET --paginate "repos/$REPO/pulls" \
  -f state=open -f base="$TARGET" -f head="$HEAD_OWNER:$BRANCH" -f per_page=100
```

Verify returned head repo/branch and base repo/branch against this landing.

## Historical evidence: `auto` and `confirm`

For every sampled `SHA`, use [commit associations](https://docs.github.com/en/rest/commits/commits#list-pull-requests-associated-with-a-commit)
to find PRs, including squash/rebase merges whose subjects contain no PR number:

```sh
gh api --hostname "$HOST" --paginate "repos/$REPO/commits/$SHA/pulls?per_page=100"
gh api --hostname "$HOST" --paginate "repos/$REPO/commits/$SHA/comments?per_page=100"
```

Keep merged PRs targeting the destination repo and `TARGET`, deduplicating PR
numbers across the sample. Investigate unresolved merge subjects/review links.
For each matching PR:

```sh
gh api --hostname "$HOST" "repos/$REPO/pulls/$NUMBER"
gh api --hostname "$HOST" --paginate "repos/$REPO/pulls/$NUMBER/reviews?per_page=100"
gh api --hostname "$HOST" --paginate "repos/$REPO/pulls/$NUMBER/comments?per_page=100"
gh api --hostname "$HOST" --paginate "repos/$REPO/issues/$NUMBER/comments?per_page=100"
```

[Review records](https://docs.github.com/en/rest/pulls/reviews#list-reviews-for-a-pull-request)
provide reviewer, state, body, `submitted_at`, and `commit_id`. Compare submitted
reviews and substantive inline/conversation feedback with the PR author and
`merged_at`; pending/post-merge reviews do not establish pre-landing review.
Recognize bot account types, known service accounts, and explicit agent markers
even under a User account. Commit comments/external reviews need the same
attribution and content checks; their timestamp alone does not establish when
they occurred relative to landing. Apply the classification and reporting rules
in [review history](review-history.md).
