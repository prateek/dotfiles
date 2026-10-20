# Stack surgery

Use only the section for the requested operation. Inspect the stack before and
after changing its shape.

## Adopt existing branches

Track one existing branch against a known base:

```bash
git-spice branch track <branch> --base=<base> --no-prompt
```

For an existing linear chain, name its top branch and track downward:

```bash
git-spice downstack track <top-branch> --no-prompt
```

Completion means `git-spice log short` shows every adopted branch on its
intended base.

## Move dependencies

Move one branch while leaving its former descendants on the old base:

```bash
git-spice branch onto <new-base> --restack --no-prompt
```

Move the current branch and its descendants together:

```bash
git-spice upstack onto <new-base> --no-prompt
```

Use the first form only when leaving the former upstack behind is intended.

## Insert a branch

Config adds `prateek/` to branch-create names, so pass `<bare-name>`. Insert a
new branch above the target and move its existing upstack onto it:

```bash
git add <specific-files>
git-spice branch create <bare-name> --insert -m "<message>" --no-prompt
```

Create below the target and restack the target and its upstack:

```bash
git add <specific-files>
git-spice branch create <bare-name> --below -m "<message>" --no-prompt
```

Use `-t <target>` to name a target other than the current branch. Use
`--no-commit` when the inserted branch should contain no commit.

## Fix up or pick commits

Apply staged changes to a named downstack commit and restack everything above
it:

```bash
git add <specific-files>
git-spice commit fixup <commit> --no-prompt
```

Use fixup only when no other worktree holds the owning branch; rewriting a
held branch fails with a worktree collision. When it is held, amend in that
worktree, then restack descendants that git-spice skipped from their own
worktrees. Fixup also fails without starting the rewrite when staged changes
conflict.

Apply a named commit to the current branch and restack its upstack:

```bash
git-spice commit pick <commit> --no-prompt
```

Use `--from=<branch>` when selecting from another branch or its upstack.

## Reshape one branch

Squash a branch without opening an editor:

```bash
git-spice branch squash -m "<message>" --no-prompt
```

Split at explicit commit boundaries. The create prefix does not apply here, so
provide each full branch name:

```bash
git-spice branch split --at=<commit>:prateek/<new-name> --no-prompt
```

Repeat `--at` for every boundary. Verify commit-to-branch assignments before
running the split.

Fold merges a branch into its base and deletes the folded branch. Run it only
when the user requests that result and the checked-out branch is the intended
target:

```bash
git-spice branch fold --no-prompt
```

Rename with both full names:

```bash
git-spice branch rename prateek/<old-name> prateek/<new-name> --no-prompt
```

Inspect a branch relative to its base with:

```bash
git-spice branch diff --branch=<branch> --no-prompt
```

Completion means the resulting commits and branch relationships match the
requested shape.

## Editor-driven operations

`git-spice branch edit`, `git-spice stack edit`,
`git-spice downstack edit`, and `git-spice commit split` require interactive
selection. Hand the exact operation and intended ordering to the user when no
interactive editor is available. After completion, inspect
`git-spice log short`.

## Delete branches

Deletion requires an explicit request and a verified target list. Delete named
branches and align their descendants with:

```bash
git-spice branch delete <branch> --restack --no-prompt
```

Delete a connected stack or only the current branch's descendants when that
exact scope was requested:

```bash
git-spice stack delete --force --no-prompt
git-spice upstack delete --force --no-prompt
```

Completion means only the requested branches are absent and the surviving
relationships are correct.
