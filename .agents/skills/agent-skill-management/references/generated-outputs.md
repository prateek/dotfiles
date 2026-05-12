# Generated Outputs

Committed generated fragments:

- `home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl`: Codex plugin
  config fragment.
- `home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl`: Claude
  plugin settings fragment.

Apply-time generated live roots:

- `~/.agents/skills/`: Codex root skill projection.
- `~/.claude/skills/`: Claude root skill projection.
- `~/.agents/plugins/`: shared local plugin marketplace.

Codex resolves local plugin source paths from the supported marketplace root,
not from the `marketplace.json` directory. For the live
`~/.agents/plugins/marketplace.json` layout, Codex entries therefore point at
`./.agents/plugins/plugins/<plugin>`. Claude Code entries in
`.claude-plugin/marketplace.json` continue to point at `./plugins/<plugin>`.

`home/.chezmoiscripts/run_onchange_after_35-agent-core-skills.sh.tmpl` and
`home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl` render those
live roots during `chezmoi apply`. Their template comments include hashes for
the renderer code and `home/dot_agents/packages/**`, so chezmoi reruns them only
when inputs change.

Run renderers with explicit temp output paths and `--check` before handoff.
