# Engineering Conventions

Use this document for code, configuration, tests, comments, and durable
documentation. Repository-local instructions take precedence.

## Defaults

- Make the smallest coherent change that solves the underlying problem.
- Match the surrounding style and use the repository's native task runner:
  `just` when a `justfile` exists, then `make`, then the documented tool-native
  command.
- Keep names evergreen. Avoid labels such as `new`, `old`, `improved`, or
  `enhanced` unless they describe a lasting domain distinction.
- Prefer XDG paths for application state and configuration. Check the
  application's documentation before inventing an environment-variable
  override.

## Scope and durable state

- Keep implementation changes within the task. Fix a related papercut when it
  is cheap and low-risk; report broader work instead of silently expanding
  scope.
- Keep behavior, tests, comments, docs, examples, and configuration aligned.
  Use the `code-gardening` skill when durable state drifts or intent is unclear.
- Read a durable instruction or configuration file end-to-end before editing
  it. After editing, reread it and validate its parser or generator when one
  exists.
- Remove obsolete code and guidance when no compatibility contract requires
  them. Leave no migration breadcrumbs unless an active compatibility path
  depends on the note.

## Existing code and compatibility

- Modify the existing implementation. Get Prateek's approval before replacing
  a feature or subsystem wholesale.
- Preserve deployed and shared interfaces unless Prateek approves a breaking
  change. For private, experimental, or undeployed work, prefer the clean target
  design over a compatibility shim.
- Keep test doubles inside tests or deterministic harnesses. Product and runtime
  paths should represent real behavior.
- Check for a suitable existing dependency before adding one. Confirm a new
  dependency unless the task already authorizes that class of change.

## Comments

- Preserve pre-existing comments unless evidence shows that they are false.
- Write comments for rationale, constraints, or non-obvious contracts. Keep
  them evergreen; code should carry facts visible from the implementation.
- Run the `decomment` skill after a nontrivial code change to prune comments
  introduced by the change.

## Investigation

- Settle third-party APIs from local types or language-server evidence first,
  then vendored source, then version-matched `ask docs <spec>` or
  `ask src <spec>`.
- When behavior, tests, and docs leave intent unclear, inspect history with
  `git log --follow`, `git log -S`, or `git log -G`; use blame and review
  context only if the cheaper evidence does not settle it.
- Change direction only after the available evidence contradicts the current
  approach or fails to resolve it.

## Testing and completion

- For behavior changes, add or update the smallest meaningful test. Prefer a
  red test first when practical.
- Test observable behavior through stable seams. Enforce architectural rules
  with compiler boundaries, linters, dependency checks, structured metadata,
  or integration coverage.
- For docs, configuration, generated diffs, and review-only work, run the
  lightest check that proves the touched boundary.
- When the local validation path is unclear or incomplete, inspect
  `.github/workflows` and mirror the relevant CI checks when practical.
- Read all test and command output. Claim a check only when its output is clean;
  capture and assert expected errors.
- Finish when the relevant checks pass and every changed durable surface agrees.
  State any skipped validation and its residual risk.
