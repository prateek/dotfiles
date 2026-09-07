# Fixture: marketplace-only-land-apply-scope

Simulated state; reason from these facts without initializing a real repository.
The worktree and canonical checkout are clean, the canonical branch is `master`,
and the expected GitHub identity is authenticated. Relevant checks pass.

```text
$ git log --oneline origin/master..HEAD
a1b2c3d fix(skills): clarify gardening source ownership
$ git diff --name-only origin/master..HEAD
agent-marketplace/packages/core/skills/code-gardening/SKILL.md
agent-marketplace/packages/core/.codex-plugin/plugin.json
$ chezmoi source-path
/Users/prateek/dotfiles/home
```

The package version was bumped in its Codex manifest; the build derives the
matching Claude version. Script 36's
rendered marketplace input hash changes, although its template was not edited.
Host activation policy, native config templates, and script 35 are unchanged.

The ordinary file diff contains unrelated drift in `~/.config/karabiner.edn`.
The user explicitly defers apply, including direct materializer or native-client
mutations. Canonical expectations live in `evals/evals.json`.
