# Worktrees

Use Orca when starting isolated work, checking out a PR, selecting a repository's
default worktree base, or managing worktree runtime state. Load the `orca-cli`
skill before issuing Orca commands; it serves the version-matched command guide
from the running binary.

## Defaults

- Use `ohc` when a repository may not be cloned or registered with Orca.
- Use the Orca UI or `orca worktree create` for a registered repository.
- Create related work as a child worktree. Use an independent worktree when the
  task should start from the repository's default base rather than the current
  branch.
- Prefer Orca worktree and terminal operations over raw `git worktree` and
  ad-hoc PTYs when Orca owns the runtime state.

## Creation

Before creating independent work, verify the [default base](#default-worktree-base).
Use `--no-parent` and omit `--base-branch` to use that configured base.
`--no-parent` controls Orca lineage only; it does not select a Git ref. Use an
explicit base for a task-specific override or requested stacked work, without
changing the repository default for that one task.

```sh
ohc <owner>/<repo> [orca worktree create options]
ohc stablyai/orca --name fix-auth --agent claude --prompt 'Fix GH #322'
```

`ohc` clones or updates through `ghc`, registers the repository, and forwards
the remaining arguments to `orca worktree create`. Use `ohc --help` and the
version-matched `orca-cli` guide for the current flags.

The Raycast command `Create Orca Worktree` is a form-based wrapper around `ohc`.
Use it when a form is more convenient than the CLI.

## Layout

Worktrees live here:

```text
~/code/worktrees/<repo>/<name>
```

`<repo>` is the repository directory name. `<name>` is the worktree name Orca
creates for the task.

The canonical clone used by `ghc` lives at:

```text
~/code/github.com/<owner>/<repo>
```

## Repository configuration

Put shared hooks and supported project defaults in a committed `orca.yaml` at
the repository root.
Orca reads it when creating or archiving worktrees, after the repo has been
trusted on the machine.

Use the repo's `.orca/` directory for per-user overrides. Keep `orca.yaml`
portable and committed only when the behavior should apply to every worktree of
the repo. Read the version-matched Orca guide instead of copying its schema into
this file.

### Default worktree base

Orca's **Default Worktree Base** (`worktreeBaseRef`) is a persisted Orca repository
setting. Configure it through the public CLI or repository settings UI. Changing
it does not change GitHub's default branch or rebase existing branches.

1. Identify the intended development trunk from repository instructions, fork
   policy (such as `FORK.md`), or explicit user direction. Inspect policy on the
   relevant ref if the current checkout lacks it. A fork may develop on
   `downstream` while `main` only mirrors upstream. Branch names, the current
   feature branch, and `origin/HEAD` alone do not establish that policy.
2. Confirm the Orca repository's path and ID with `repo show`, inspect its current
   `worktreeBaseRef`, and check Git remote URLs. Choose a remote-tracking ref for
   the intended repository and trunk, such as `origin/downstream`; confirm it
   resolves to a commit, fetching that remote if needed. If policy is absent,
   inspect the intended remote's default branch as a candidate. Resolve ambiguity
   with the user before changing the setting.
3. During authorized repository setup or default correction, use `repo set-base-ref`
   only when the setting differs from the established trunk. Take exact selectors
   and flags from the live `orca-cli` guide. Leave an already-correct value alone;
   assess each repository separately.
4. Read back `repo show` and confirm `worktreeBaseRef` equals the chosen ref.
   After creating a worktree, verify its reported base and Git ancestry as well
   as its parent lineage. A saved setting alone does not prove an existing
   worktree started from it.

## Completion

- Confirm the default base matches repository policy and report whether it changed.
- Confirm Orca reports the expected worktree path, branch, parent lineage, and
  runtime state.
- For hook or project-default changes, confirm shared behavior is committed in
  `orca.yaml` and personal overrides remain under `.orca/`.
