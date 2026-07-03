# Fixture: squash-multi-commit-branch

Core-behavior eval: the branch carries several WIP commits. Tests that the
agent rebases onto the latest master and squashes to a **single** commit
before landing — non-interactively (`git reset --soft origin/master` + one
`git commit`), since `git rebase -i` is unavailable in agent shells — and
gives it one conventional-commit message.

The discriminating signal is the multi-commit log:

```
$ git log --oneline origin/master..HEAD
d4e5f6a address review
c3d4e5f fix typo
b2c3d4e fix
a1b2c3d wip
```

A correct land leaves master with one commit, not four.

Canonical prompt + expectations live in `evals/evals.json`.
