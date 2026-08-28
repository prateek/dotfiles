# Source

- Upstream: https://github.com/forjd/better-writing/tree/0f6ea786b644928b2c047cf0407ba6f2f3190c6e
- APM dependency: `forjd/better-writing`
- Ref: `0f6ea786b644928b2c047cf0407ba6f2f3190c6e`
- License: MIT (Copyright (c) 2026 Forjd); `LICENSE` retained in the vendored tree.
- Notes: Vendored from the repo root, not the `skills/better-writing/` subpath: that subpath is all symlinks into the root, which apm's sparse-cone subdir materialization leaves dangling (install fails with ENOENT). Local delta: the nested `skills/` alias copy is deleted after re-vendoring because it double-packages the same skill and trips the duplicate-skill-name validator. chezmoi rename: `evals/run_evals.py` is checked in as `literal_run_evals.py` to escape chezmoi's `run_` script-prefix interpretation. Renders into the always-on `core` root alongside `write-for-humans` and `writing-clearly-and-concisely`.
