# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.

## 2026-10-20: agent-marketplace sorted by origin, one plugin set for every harness

Branch `prateek/agent-marketplace` carries out
[the layout plan](docs/plans/agent-marketplace-layout-plan.md), recorded in
[ADR 0059](docs/adr/0059-one-plugin-set-for-every-harness.md) and
[ADR 0060](docs/adr/0060-one-root-marketplace-manifest.md). Three checks never
ran on work-mbp. Run each on a personal machine:

1. **Codex installs a Claude-format upstream catalog.** ADR 0059 relies on
   this, so far from Codex source only.
   - Use an isolated `CODEX_HOME`, then run
     `codex plugin marketplace add raintree-technology/apple-hig-skills` and
     `codex plugin add apple-hig-skills@apple-hig-skills`.
   - Done when the plugin lists its skills, and stays disabled after a
     `reconcile-upstream-agent-plugins --apply --agent codex` run with
     `default_loaded = false`.
2. **Console write tests and the agent Bats lane are green.** Both need
   `build/test-libraries`, which work-mbp can't fetch.
   - Run `mise run test-tools`, then `just test-python -p 'test_console_*.py'`
     and `just test-shell tests/bats/agents`.
   - The console now edits `agent-marketplace/marketplace.toml` as text
     (`_bump_plugin_version`, `_remove_selection` in `skill_console/decisions.py`).
     A failure there most likely means a fixture expectation the move missed.
3. **Cursor's `prateek-local` directory entry is still needed.** Cursor already
   loads the plugins Claude has installed and enabled.
   - List Cursor's loaded plugins. If each local plugin appears once and
     disabled ones are absent, remove the entry from
     `home/.chezmoitemplates/cursor-cli-config-managed.json.tmpl`.
   - Leave cursor-agent's worker-server running; it brokers auth.

Suggested skills: `agent-skill-management` for any of the three, and
`land-changes` once they pass.
