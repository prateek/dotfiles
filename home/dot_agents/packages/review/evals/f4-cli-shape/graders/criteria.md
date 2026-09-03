The failure this case reproduces: agents invent crit CLI shapes that do not
exist. The three seen most often are `crit push --pr <n>`, `crit push --session
<id>`, and hand-editing `~/.crit/reviews/*/review.json` under a live daemon.

PASS requires all of:

- The push command passes the pull request number POSITIONALLY, for example
  `crit push 1234`, not `--pr 1234`.
- No `--session` flag on `crit push` or `crit pull`. If the agent mentions
  session targeting at all, it correctly limits it to `crit comment`,
  `crit comments`, or `crit share`.
- The reply uses `crit comment --reply-to c_a1b2c3` with an explicit `--author`.

FAIL if any of:

- `crit push --pr 1234` or any flag-form pull request number.
- `crit push --session` or `crit pull --session`.
- Editing `review.json` directly is proposed as the way to change a comment.
- The agent claims a flag exists without either citing `crit --help` output or
  hedging that it should be checked.

Do not penalise the agent for also suggesting `--dry-run` first; that is good
practice.
