# Source

- Upstream: https://github.com/forjd/better-writing/tree/061fe778e8855c4d5c019889e3a6014a4b027adf/skills/better-writing
- APM dependency: `forjd/better-writing/skills/better-writing`
- Ref: `061fe778e8855c4d5c019889e3a6014a4b027adf`
- License: MIT (Copyright (c) 2026 Forjd); `LICENSE` retained in the vendored tree.
- Notes: Vendored from the upstream `skills/better-writing/` subpath, not the repo root. The root double-packages the same skill (nested `skills/better-writing/` plus an `evals/` dev harness), which trips the duplicate-skill-name validator; the subpath deploys one clean skill. Renders into the always-on `core` root alongside `write-for-humans` and `writing-clearly-and-concisely`.
