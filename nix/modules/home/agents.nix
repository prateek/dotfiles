{
  lib,
  config,
  pkgs,
  ...
}:

# Agent skills & plugin marketplace. We keep the existing Python renderers
# under .agents/skills/agent-skill-management/scripts/ and invoke them via
# home-manager activation hooks. After rendering, two more activation hooks
# deep-merge the generated plugin-config fragments into ~/.claude/settings.json
# and ~/.codex/config.toml using the standalone JSON/TOML mergers.

let
  inherit (lib) optionalString;

  # Source paths captured at evaluation time.
  agentsRepoRoot = ../../../home/dot_agents;
  agentsPackagesDir = ../../../home/dot_agents/packages;
  coreRenderer =
    ../../../.agents/skills/agent-skill-management/scripts/render-agent-core-skills;
  pluginRenderer =
    ../../../.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace;
  claudeFragment =
    ../../../home/dot_agents/templates/claude-plugin-settings.json;
  codexFragment =
    ../../../home/dot_agents/templates/codex-config-managed.toml;
  pluginCodexFragment =
    ../../../home/dot_agents/templates/codex-plugin-config.toml;
  jsonMerger = ../../../scripts/merge/json-deep-merge;
  tomlMerger = ../../../scripts/merge/toml-deep-merge;

  # Static (non-template) files in the agent surface.
  agentsAgentsMd = ../../../home/dot_agents/AGENTS.md;
  claudeSettingsLocal = ../../../home/dot_claude/settings.local.json;
  claudeCommands = ../../../home/dot_claude/commands;
in
{
  # Single source of truth for the package sources. The renderers consume
  # this tree to produce the live skills + plugins surfaces.
  home.file.".agents/packages" = {
    source = agentsPackagesDir;
    recursive = true;
  };

  home.file.".agents/AGENTS.md".source = agentsAgentsMd;
  home.file.".claude/CLAUDE.md".source = agentsAgentsMd; # was symlink_CLAUDE.md
  home.file.".claude/settings.local.json".source = claudeSettingsLocal;
  home.file.".claude/commands" = {
    source = claudeCommands;
    recursive = true;
  };

  # ~/.codex/skills was symlink_skills → ../.agents/skills. home-manager
  # doesn't allow targeting a relative symlink target via home.file;
  # achieve the same with mkOutOfStoreSymlink to an absolute path.
  home.file.".codex/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";

  home.activation = lib.mkIf config.profile.agents.enable {
    # Render core + claude skills. The renderers reset their destinations
    # internally, so re-running is idempotent.
    renderAgentSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -x "${toString coreRenderer}" ] && command -v uv >/dev/null 2>&1; then
        run "${toString coreRenderer}" \
          --codex-root "$HOME/.agents/skills" \
          --claude-root "$HOME/.claude/skills" \
          || echo "[home-manager] warn: render-agent-core-skills failed." >&2
      else
        echo "[home-manager] skipping agent core skill render (renderer or uv missing)." >&2
      fi
    '';

    renderAgentPlugins = lib.hm.dag.entryAfter [ "renderAgentSkills" ] ''
      if [ -x "${toString pluginRenderer}" ] && command -v uv >/dev/null 2>&1; then
        run "${toString pluginRenderer}" \
          --plugins-root "$HOME/.agents/plugins" \
          --skip-config-templates \
          || echo "[home-manager] warn: render-agent-plugin-marketplace failed." >&2
      else
        echo "[home-manager] skipping agent plugin render (renderer or uv missing)." >&2
      fi
    '';

    mergeClaudeSettings = lib.hm.dag.entryAfter [ "renderAgentPlugins" ] ''
      if [ -x "${toString jsonMerger}" ] && command -v uv >/dev/null 2>&1; then
        tmp="$(mktemp -t claude-settings.XXXXXX.json)"
        sed "s|__HOME__|$HOME|g" "${toString claudeFragment}" > "$tmp"
        run "${toString jsonMerger}" "$tmp" "$HOME/.claude/settings.json" \
          || echo "[home-manager] warn: claude settings merge failed." >&2
        rm -f "$tmp"
      fi
    '';

    mergeCodexConfig = lib.hm.dag.entryAfter [ "renderAgentPlugins" ] ''
      if [ -x "${toString tomlMerger}" ] && command -v uv >/dev/null 2>&1; then
        # Concatenate the managed config + the plugin fragment, substituting
        # the __HOME__ placeholder in the plugin section.
        tmp="$(mktemp -t codex-managed.XXXXXX.toml)"
        cat "${toString codexFragment}" > "$tmp"
        echo "" >> "$tmp"
        sed "s|__HOME__|$HOME|g" "${toString pluginCodexFragment}" >> "$tmp"
        run "${toString tomlMerger}" "$tmp" "$HOME/.codex/config.toml" \
          || echo "[home-manager] warn: codex config merge failed." >&2
        rm -f "$tmp"
      fi
    '';
  };
}
