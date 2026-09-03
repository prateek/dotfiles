# Source

- Upstream: https://github.com/stablyai/agent-slack/tree/dba40572624ef0b81a325fe8b876c7649aa7895f/skills/agent-slack
- APM dependency: `stablyai/agent-slack/skills/agent-slack`
- Ref: `dba40572624ef0b81a325fe8b876c7649aa7895f`
- License: MIT (© 2026 Stably; see https://github.com/stablyai/agent-slack/blob/main/LICENSE).
- Notes: Companion to the `agent-slack` CLI installed via mise (`npm:agent-slack`); it is a CLI, not a subagent. Upstream `main` is ahead of the installed npm release (v0.9.3): this skill documents scheduling (`--schedule-in`, `message scheduled …`) that v0.9.3 lacks; those resolve when `latest` advances. See ~/.agents/docs/slack.md. Refreshed 2026-09-02 to dba4057: adds `--no-unfurl` on `message send|compose` and `--attach` on draft create/update (agent-slack v0.10.x); the installed 0.9.3 lacks both until `mise upgrade npm:agent-slack`.
