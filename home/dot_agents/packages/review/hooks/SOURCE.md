# Source

- Upstream: https://github.com/tomasz-tomczyk/crit/tree/31d6a6a9195bdda735c1e8f68a75359839f8d3c8/integrations/claude-code
- APM dependency: `tomasz-tomczyk/crit/integrations/claude-code`
- Ref: `31d6a6a9195bdda735c1e8f68a75359839f8d3c8`
- License: MIT.
- Notes: Vendored from apm's .apm/hooks normalization of integrations/claude-code/hooks (byte-identical). Replaces the PermissionRequest block claude-settings-managed.json.tmpl hand-carried until 2026-09-02 (ADR 0019); the managed fragment now retires that settings entry. Claude-only: the rendered Codex manifest declares hooks {}.
