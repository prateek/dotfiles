# Worktrees

Use Orca when starting isolated work, checking out a PR, or managing worktree
runtime state. Load the `orca-cli` skill before issuing Orca commands; it serves
the version-matched command guide from the running binary.

## Defaults

- Use `ohc` when a repository may not be cloned or registered with Orca.
- Use the Orca UI or `orca worktree create` for a registered repository.
- Create related work as a child worktree. Use an independent worktree when the
  task should start from the repository's default base rather than the current
  branch.
- Prefer Orca worktree and terminal operations over raw `git worktree` and
  ad-hoc PTYs when Orca owns the runtime state.

## Creation

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

Put repo-wide Orca behavior in a committed `orca.yaml` at the repository root.
Orca reads it when creating or archiving worktrees, after the repo has been
trusted on the machine.

Use the repo's `.orca/` directory for per-user overrides. Keep `orca.yaml`
portable and committed only when the behavior should apply to every worktree of
the repo. Read the version-matched Orca guide instead of copying its schema into
this file.

## Completion

- Confirm Orca reports the expected worktree path, branch, parent lineage, and
  runtime state.
- Confirm repository-wide behavior is committed in `orca.yaml` and personal
  overrides remain under `.orca/`.
