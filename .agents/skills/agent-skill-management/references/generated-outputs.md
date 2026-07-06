# Generated Outputs

Committed generated fragments:

- `home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl`: Codex plugin
  config fragment.
- `home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl`: Claude
  plugin settings fragment.
- `home/dot_pi/agent/claude-plugins.json.tmpl`: pi Claude marketplace plugin
  config.

Apply-time generated state:

- `~/.agents/plugins/`: shared local plugin marketplace; the only skill
  projection.
- `~/.agents/skills/`: empty maintained stub for Codex's runtime `.system/`
  skills (reached through the `~/.codex/skills` symlink).
- `~/.claude/skills/`: retired; the root maintainer removes the generated dir.

Codex resolves local plugin source paths from the supported marketplace root,
not from the `marketplace.json` directory. For the live
`~/.agents/plugins/marketplace.json` layout, Codex entries therefore point at
`./.agents/plugins/plugins/<plugin>`. Claude Code entries in
`.claude-plugin/marketplace.json` continue to point at `./plugins/<plugin>`.

`home/.chezmoiscripts/run_onchange_after_35-agent-skill-roots.sh.tmpl` and
`home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl` maintain
that state during `chezmoi apply`. Their template comments include hashes for
the renderer code (and, for the plugin renderer, `home/dot_agents/packages/**`),
so chezmoi reruns them only when inputs change.

Run renderers with explicit temp output paths and `--check` before handoff.
