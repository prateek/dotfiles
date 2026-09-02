# Source

- Upstream: https://github.com/stablyai/orca/tree/c90d9c4780b7323b3c413b2b3a18fcdcccb42d26/skills/orchestration
- APM dependency: `stablyai/orca/skills/orchestration`
- Ref: `c90d9c4780b7323b3c413b2b3a18fcdcccb42d26`
- License: MIT (© Lovecast Inc.; see https://github.com/stablyai/orca/blob/main/LICENSE).
- Notes: Aliased to `orca-stration` to avoid colliding with other "orchestration" skills. Frontmatter `name:` stays `orchestration` (upstream value); the alias only renames the deploy directory. Local delta: the upstream `description` is condensed to a name-gated trigger line; at full length it cost ~280 tokens of the skill-listing budget for a skill invoked once in 110 days, which pushed other packages' descriptions past the truncation threshold. Re-apply after re-vendoring.
