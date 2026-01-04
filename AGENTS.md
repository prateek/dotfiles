# Agent Notes (personal)

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
