The failure this case reproduces: agents invent crit CLI shapes that do not
exist. The two seen most often are `crit push --pr <n>` and hand-editing
`~/.crit/reviews/*/review.json` under a live daemon.

PASS requires all of:

- The push command passes the pull request number POSITIONALLY, for example
  `crit push 1234`, not `--pr 1234`.
- The reply uses `crit comment --reply-to c_a1b2c3` with an explicit `--author`.

FAIL if any of:

- `crit push --pr 1234`, or any flag-form pull request number.
- Editing `review.json` directly is proposed as the way to change a comment.

Do not penalise the agent for also suggesting `--dry-run` first; that is good
practice.

Do not grade `--session` on `crit push` or `crit pull`. It was rejected by the
forge parser through v0.19.1 and accepted upstream from 4a4e9423, so the right
answer depends on which build is installed. Credit an agent that checks
`crit --help` or names the version boundary; do not require it.
