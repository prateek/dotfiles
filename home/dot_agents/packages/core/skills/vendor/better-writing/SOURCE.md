# Source

- Upstream: https://github.com/forjd/better-writing/tree/dd9d0a50581a7652fb38f03b7b751741ed917993
- APM dependency: `forjd/better-writing`
- Ref: `dd9d0a50581a7652fb38f03b7b751741ed917993`
- License: MIT (Copyright (c) 2026 Forjd); `LICENSE` retained in the vendored tree.
- Notes: Vendored from the repo root, not the `skills/better-writing/` subpath: that subpath is all symlinks into the root, which apm's sparse-cone subdir materialization leaves dangling (install fails with ENOENT). Local delta: the nested `skills/` alias copy is deleted after re-vendoring because it double-packages the same skill and trips the duplicate-skill-name validator. chezmoi rename: `evals/run_evals.py` and `evals/run_skill.py` are checked in as `literal_run_evals.py` and `literal_run_skill.py` to escape chezmoi's `run_` script-prefix interpretation. Local delta: the skill is made user-invoked only, so it costs no listing budget in the always-on `core` root while `writing-for-humans` routes to it and the human can still invoke it by name — `disable-model-invocation: true` in the frontmatter covers Claude Code, pi, and cursor-agent, and `agents/openai.yaml` flips `policy.allow_implicit_invocation` from upstream's `true` to `false` for Codex, which ignores the frontmatter key. Renders into `core` alongside `write-for-humans` and `writing-clearly-and-concisely`.
