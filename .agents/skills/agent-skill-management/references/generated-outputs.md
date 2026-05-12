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

`home/.chezmoiscripts/run_onchange_after_35-agent-core-skills.sh.tmpl` and
`home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl` render those
live roots during `chezmoi apply`. Their template comments include hashes for
the renderer code and `home/dot_agents/packages/**`, so chezmoi reruns them only
when inputs change.

Run renderers with explicit temp output paths and `--check` before handoff.
