# Source

- Upstream: https://github.com/forjd/better-writing/tree/dd9d0a50581a7652fb38f03b7b751741ed917993
- APM dependency: none since 2026-09-03 (was `forjd/better-writing` in core/apm.yml); copied by hand into the writing-for-humans references at the ref below, pending the ADR 0016 vendor mapping
- Ref: `dd9d0a50581a7652fb38f03b7b751741ed917993`
- License: MIT (Copyright (c) 2026 Forjd); `LICENSE` retained in the vendored tree.
- Notes: Vendored from the repo root, not the `skills/better-writing/` subpath: that subpath is all symlinks into the root, which apm's sparse-cone subdir materialization leaves dangling (install fails with ENOENT). Local delta: the nested `skills/` alias copy is deleted after re-vendoring because it double-packages the same skill and trips the duplicate-skill-name validator. chezmoi rename: `evals/run_evals.py` and `evals/run_skill.py` are checked in as `literal_run_evals.py` and `literal_run_skill.py` to escape chezmoi's `run_` script-prefix interpretation. Renders into the always-on `core` root alongside `write-for-humans` and `writing-clearly-and-concisely`.
