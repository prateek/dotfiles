# Landing decision evaluations

`evals.json` describes portable hypothetical repositories. For each case, load the
skill and provide the shared `context`, case `context`, and user `prompt`. Keep
`expectations` hidden until grading. Ask for ordered actions and the resulting
report or unresolved decision; no case authorizes operating on a real repository.

Judge behavior and action order, not wording or exact command spelling. Record
per-expectation passes/failures with evidence from the response and the model/runtime
used. These are model decision simulations: they do not prove that Git, hosting,
or deployment commands execute successfully. The separate helper CLI suite in
`agent-marketplace/tests/test_land_options.py` exercises real isolated persistence.

The cases cover destination discovery, full change scope, history evidence,
policy, authorization, publication ordering/recovery, configuration, and deployment.
Test-mode cases distinguish skipped suites from other checks, Git hooks, and
required CI, and cover persistence and an explicit return to running tests.
One portable happy path combines squash/attribution, spaced worktree paths, and a
stale ref for the same task. The missing-ref stack case protects scope discovery
independently of a stack tool. Bot PRs, agent reviews, and signatures share a
negative-evidence case; human reviews in formal, external, and discussion records
remain separate so one source cannot hide a missing lookup.

Repository-specific preview details belong to the repository's runbook. The
preview case checks following that guidance, separating unrelated drift, and
honoring deferred application; it deliberately does not assert particular app
paths, hook numbers, package names, or cache internals.
