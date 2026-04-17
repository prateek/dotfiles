# Agent Notes (personal)

This file is the durable repo contract for coding agents working in this dotfiles repo.
Keep it short. Put recurring maintenance workflow in `$code-gardening`, not in long prose.

## Gardening

- Treat drift as real work. If code, tests, comments, docs, examples, or tooling disagree, do not just route around it.
- If the fix is cheap and clearly part of the task, do it now. If it is broader, riskier, cross-cutting, or unclear, call it out explicitly.
- Keep durable state in sync when facts change. That includes behavior, tests, comments, docs, examples, config, and agent instructions.
- Use `$code-gardening` when you are touching durable state, hit a parser or config error, suspect a failure may be pre-existing, or do not trust your read of the code yet.
- When writing prose for humans, keep it short, concrete, and clear. Use the `writing-clearly-and-concisely` guidance.

## Archaeology

- If intent feels fuzzy, weird, or out of step with comments or docs, stop and do archaeology before changing behavior.
- Read the whole file or doc before making large edits or when the local snippet feels misleading.
- Check current behavior and tests first. Then use `git log --follow`, `git log -S`, and `git log -G` to recover intent.
- Escalate to `git blame -w -M -C` and PR/review context when the provenance is still murky.
- If the repo has PRs, review comments, issues, ADRs, or design notes, use them when history alone is not enough.
- When history, comments, and behavior disagree, decide what is authoritative and sync the rest. Do not guess.

## State Updates

- Keep the root instruction file lean. Put repeatable maintenance workflow in `$code-gardening`, not in a giant wall of policy.
- Update `AGENTS.md` when you learn a durable convention, recurring gotcha, or workflow change that future agents will actually need.
- Do not put one-off session chatter or temporary debugging notes here. Those belong in task output, issues, or other working notes.
- After editing a skill, validate it. Skill frontmatter and parser drift have bitten us enough times that this should be automatic.

## Shell Startup

- Keep baseline `PATH` entries in `zprofile`'s `path=(...)` array, not ad hoc `export PATH=...` snippets in `zshrc`.
- Prefer explicit directories like `$HOME/go/bin` over indirect env vars like `$GOPATH/bin` when the goal is just shell PATH setup.
- When startup only needs `mise` shims, add `$HOME/.local/share/mise/shims` to `zprofile` instead of running `mise activate --shims` on every shell.
- Reserve `zshrc` PATH mutations for truly interactive or late overlays only.
- Prefer autoloaded wrappers for optional or conflicting CLIs instead of source-time aliases when the command is not needed on every shell startup.
- For zoxide, prefer lazy wrappers plus `zoxide init zsh --cmd j` over eager startup `eval`s; keep `zi` reserved for zinit.
- Avoid source-time command substitutions such as `$(brew --prefix)` in shell startup files. Prefer `HOMEBREW_PREFIX`, `whence -p`, or resolution at call time.
- When sourcing shell widgets or key-binding scripts, guard them behind `[[ -o zle ]]` so non-ZLE interactive shells like `zsh -ic` do not throw option or widget errors.
- For shell widget or keymap debugging, prefer a real PTY login shell over `zsh -ic`; the latter can report `zle` as on without a tty and can miss deferred plugin state.
- If syncing `PATH` into `launchctl`, compare against the live `launchctl getenv PATH` value instead of trusting a persistent cache file across GUI sessions.
- Keep repeatable shell benchmarking guidance in `skills/benchmark-zsh-startup`, not loose repo docs.

## Python deps (pyproject + type stubs + build system)

- When adding a new Python import, declare the dependency in `pyproject.toml` (runtime vs test/dev/optional).
- If type checking is enabled (e.g. Pyright/Mypy), add the appropriate stub package when required (`types-<pkg>` / `<pkg>-stubs`) and keep it in the test/dev optional dependency group.
- If the repo mirrors Python deps into a build-system list (e.g. Bazel `virtual_deps` / requirements targets), update **all** relevant targets (runtime lib + tests + typecheck target) to include:
  - the runtime package
  - the stub package (when needed)
- Watch out for name normalization mismatches between ecosystems (common patterns: `-` → `_`, `.` → `_`, lowercase normalization). Use whatever naming convention the repo’s build rules expect.
- After updating deps, run the smallest local checks that match CI: dependency validation + typecheck, before pushing.

## Gazelle / generated BUILD file diffs

- If CI fails with “run the build file generator” and shows a patch/diff, apply that diff and commit it (don’t ignore generator-required changes).
- If you can’t run the generator locally (auth/network/private module issues), use the CI-provided diff/artifact as the source of truth and patch only what it requires.
- Prefer minimal, targeted BUILD updates (avoid unrelated reformatting or broad generator churn unless the diff explicitly includes it).
