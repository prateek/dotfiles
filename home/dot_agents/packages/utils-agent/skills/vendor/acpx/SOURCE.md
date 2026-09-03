# Source

- Upstream: https://github.com/openclaw/acpx/tree/95a9466b9b80603198cd448c62c80c08bb0c5558/skills/acpx
- APM dependency: `openclaw/acpx/skills/acpx`
- Ref: `95a9466b9b80603198cd448c62c80c08bb0c5558`
- License: MIT (© openclaw; see https://github.com/openclaw/acpx/blob/main/LICENSE).
- Notes: Companion to the `acpx` CLI installed via mise (`npm:acpx`); it is a headless ACP client, not a subagent. Custom model shortcut families (`agpt*`/`aopus*`/`afable*`/`agemini`) live in `~/.acpx/config.json`, each gated on its backing CLI via machines.toml `agent_clis`. See ~/.agents/docs/acpx.md. Refreshed 2026-09-02 to 95a9466: documents session-control reconciliation after model switches and reconnect (acpx v0.13.2) and fixes the raw ACP JSON automation example; matches the installed acpx 0.13.2.
