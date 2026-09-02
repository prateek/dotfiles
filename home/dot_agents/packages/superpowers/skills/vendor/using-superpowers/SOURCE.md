# Source

- Upstream: https://github.com/obra/superpowers/tree/b36e0829c6d0140e93cfef2ca599b1b07d4a7797
- APM dependency: `obra/superpowers`
- Ref: `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`
- License: MIT (Copyright (c) 2025 Jesse Vincent); see LICENSE.txt copied from the repository-level license at this ref.
- Notes: Vendored from the upstream marketplace plugin (repo-root dependency). Local delta: LICENSE.txt copies the repository-level MIT notice into this skill root. The package's hooks/ payload carries upstream's SessionStart hook, which injects this skill's body into every Claude session where the plugin is enabled.
