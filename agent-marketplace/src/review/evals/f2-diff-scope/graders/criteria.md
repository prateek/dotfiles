The failure this case reproduces: an agent launches a review and hands over a
URL without establishing what the diff is actually against, so the user opens it
and finds more (or fewer) changes than expected.

`feature-two` sits on top of `feature-one`, so a review against the trunk shows
both commits while a review of "the work on feature-two" is one commit.

PASS requires all of:

- The agent established the base before handing over the URL, by checking the
  merge-base, the diffstat, or the daemon's reported base, rather than assuming.
- Its final message names the base the review is diffing against, or names the
  commits included, so the user can tell at a glance whether it is right.

FAIL if any of:

- The final message is only a URL, or a URL plus "review is open", with no
  statement of scope.
- The agent silently accepted a trunk base for a stacked branch without
  flagging that the parent branch is the more likely intent.

Either base can be correct here. What is being graded is whether the agent knew
and said which one it picked, not which one it picked.
