# Package Layout

Human-edited package source lives under `home/dot_agents/packages/<package>/`.

- `package.toml` owns the package display name and `[render]` policy.
- `apm.yml` owns the APM project manifest for remote dependency resolution.
- `skills/local/` stores repo-authored skill trees.
- `skills/vendor/` stores reviewed remote skill copies plus their source notes.

Do not add committed source trees at `home/dot_agents/skills/`,
`home/dot_claude/skills/`, or `home/dot_agents/plugins/`. `chezmoi apply`
regenerates the live projections from package source.
