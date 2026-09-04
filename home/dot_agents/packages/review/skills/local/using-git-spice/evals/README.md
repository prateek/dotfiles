# Eval suite

`evals.json` contains the hermetic local suite. Materialize the fixture named
in `files/README.md` before each run:

```bash
evals/setup_fixture.sh <fixture> <fresh-absolute-destination>
```

Run every case against the same explicit fixture config with these arms:

1. no skill
2. `baselines/previous-local-skill.md`
3. `baselines/chronosphere-skill.md`
4. the live `SKILL.md`

Review iterations with `scripts/eval-review.py`. The live skill must avoid
every fail condition and improve on both prior skill arms.

`forge-evals.json` defines E3, E4, E6, E7, and E8. E3, E4, E6, and E7 use the
private `prateek/git-spice-evals` repository:

```bash
evals/forge_fixture.sh setup <e3-fresh|e4-stale|e6-unsubmitted|e7-merged> <fresh-absolute-destination>
# run the matching eval
evals/forge_fixture.sh cleanup <destination>
```

The fixture creates unique branches, records cleanup metadata under `.git/`,
and closes change requests before deleting its remote branches. A local bare
origin cannot exercise submit, even with `--dry-run`.

E8 stays manual. Logging out of GitHub cannot be isolated safely from the
machine credential; do not mutate shared auth merely to run an eval.
