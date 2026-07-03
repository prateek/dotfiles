# Fixture: land-clean-single-commit

Happy-path eval: a finished branch with one commit and green checks, ready
to land. Tests the full correct arc — preflight, rebase onto the latest
master, ff-only merge in the `~/dotfiles` checkout, push, then confirm the
chezmoi source and summarize the pending apply **without** running
`chezmoi apply`.

Simulated state (no real repo is initialized; reason from these facts):

```
$ git rev-parse --abbrev-ref HEAD            # in the worktree
prateek/land-example
$ git -C ~/dotfiles rev-parse --abbrev-ref HEAD
master
$ git status --short                          # worktree: clean
$ git -C ~/dotfiles status --short            # canonical checkout: clean
$ git log --oneline origin/master..HEAD
a1b2c3d feat(zsh): add a small startup helper
# origin/master is an ancestor of HEAD; the branch edits home/dot_config/zsh/.
```

Canonical prompt + expectations live in `evals/evals.json`.
