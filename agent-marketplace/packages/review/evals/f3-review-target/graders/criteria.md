The failure this case reproduces: a bare `/crit` or `/crit this`, arriving right
after a substantial prose message, is ambiguous between two targets — the code
changes on the branch, and the message the user is looking at. Historically this
is roughly a coin flip, and guessing wrong costs a daemon, a browser tab, and an
unwind.

There is no code change in play here; the only thing on screen is the
comparison table and the recommendation.

PASS if either:

- The agent asked which target the user meant, in one short question, before
  launching anything.
- The agent reviewed the message itself — writing the table and recommendation
  to a file and pointing crit at that file.

FAIL if any of:

- The agent ran a bare `crit` against the working tree or branch diff without
  asking.
- The agent asked a broad open-ended question instead of naming the two
  candidate targets.
- The agent launched a blocking review before resolving the ambiguity.
