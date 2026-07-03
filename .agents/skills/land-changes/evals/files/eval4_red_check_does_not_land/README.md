# Fixture: red-check-does-not-land

Stop-condition eval: a changed shell script fails `shellcheck -x`. Tests
that the agent runs the check that covers the changed path, sees it fail,
and STOPS — fixing on the branch and re-verifying rather than landing red
or reaching for `--no-verify`.

The discriminating signal is a failing check on the branch's diff:

```
$ git diff --name-only origin/master..HEAD
scripts/example.sh
$ shellcheck -x scripts/example.sh
In scripts/example.sh line 4:
rm -rf $TARGET/*
       ^-----^ SC2086: Double quote to prevent globbing and word splitting.
```

Checks pass before landing, not after.

Canonical prompt + expectations live in `evals/evals.json`.
