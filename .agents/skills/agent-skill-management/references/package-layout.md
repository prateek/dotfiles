# Package Layout

Human-edited package source lives under `home/dot_agents/packages/<package>/`.

- `package.toml` owns the package display name, `[render]` policy, and the
  optional `default_loaded` flag (default `true`; set `false` to ship the
  package installed but with `enabledPlugins[<pkg>] = false`).
- `apm.yml` owns the APM project manifest for remote dependency resolution.
- `skills/local/` stores repo-authored skill trees.
- `skills/vendor/` stores reviewed remote skill copies plus their source notes.
- `hooks/`, `commands/`, `agents/`, and `.mcp.json` are optional plugin
  payloads passed through to the rendered plugin verbatim. `hooks/` holds
  `hooks.json` and the scripts it runs; when APM vendored it, `hooks/SOURCE.md`
  records the provenance.

Do not add committed source trees at `home/dot_agents/skills/`,
`home/dot_claude/skills/`, or `home/dot_agents/plugins/`. `chezmoi apply`
regenerates the live projections from package source.
