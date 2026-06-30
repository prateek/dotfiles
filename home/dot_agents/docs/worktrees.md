# Worktrees

Orca creates and manages Git worktrees on this machine. Use it when starting a
new task, checking out a PR in isolation, or switching between active branches.

## Create a worktree

Use `ohc` when the repo may not already be cloned or registered in Orca:

```sh
ohc <owner>/<repo> [orca worktree create options]
ohc stablyai/orca --name fix-auth --agent claude --prompt 'Fix GH #322'
```

`ohc` clones or updates the repo through `ghc`, registers the repo in Orca, then
creates the worktree. Pass the GitHub repo as the first argument. Options after
that are forwarded to `orca worktree create`; run `ohc --help` and
`orca worktree create --help` for the current flag list.

For repos Orca already knows about, create the worktree in the Orca UI or run:

```sh
orca worktree create
```

The Raycast command `Create Orca Worktree` is a form-based wrapper around `ohc`.
It is useful when you want to set the repo, worktree name, agent, prompt, and
common Orca options without typing the command by hand.

## Layout

Worktrees live here:

```text
~/code/worktrees/<repo>/<name>
```

`<repo>` is the repository directory name. `<name>` is the worktree name Orca
creates for the task.

The canonical clone used by `ghc` lives separately under:

```text
~/code/github.com/<owner>/<repo>
```

## Per-worktree actions

Put repo-wide Orca behavior in a committed `orca.yaml` at the repository root.
Orca reads it when creating or archiving worktrees, after the repo has been
trusted on the machine.

Recognized keys:

- `scripts.setup`: shell script run after worktree creation.
- `scripts.archive`: shell script run before a worktree is archived.
- `issueCommand`: command Orca can use for issue-linked worktrees.
- `defaultTabs[]`: terminal tab definitions. Each item may contain `title`,
  `command`, and `color`.

Example:

```yaml
scripts:
  setup: |
    mise install
    direnv allow
  archive: |
    echo "archiving $ORCA_WORKTREE_PATH"
issueCommand: gh issue view
defaultTabs:
  - title: agent
    command: claude
    color: "#7c3aed"
  - title: dev
    command: just dev
  - title: shell
```

Use the repo's `.orca/` directory for per-user overrides. Keep `orca.yaml`
portable and committed only when the behavior should apply to every worktree of
the repo.
