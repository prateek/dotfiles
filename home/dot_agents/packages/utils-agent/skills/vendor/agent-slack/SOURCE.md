# Source

- Upstream: https://github.com/stablyai/agent-slack/tree/80f0e8df0299f4f03bce1bed6f8ef3d3da1b65f7/skills/agent-slack
- APM dependency: `stablyai/agent-slack/skills/agent-slack`
- Ref: `80f0e8df0299f4f03bce1bed6f8ef3d3da1b65f7`
- License: MIT (© 2026 Stably; see https://github.com/stablyai/agent-slack/blob/main/LICENSE).
- Notes: Companion to the `agent-slack` CLI installed via mise (`npm:agent-slack`); it is a CLI, not a subagent. Upstream `main` is ahead of the installed npm release (v0.9.3): this skill documents scheduling (`--schedule-in`, `message scheduled …`) that v0.9.3 lacks; those resolve when `latest` advances. See ~/.agents/docs/slack.md.
