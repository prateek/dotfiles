{ lib, config, ... }:

# Per-app file placements. Each block is one logical app and gated on a
# per-app `profile.apps.<name>.enable` toggle. Defaults mirror the chezmoi
# `package-cask-enabled.tmpl` decisions: enabled unless the cask is absent
# from the active profile (toggled in nix/hosts/<host>.nix).

let
  inherit (lib) mkOption types mkIf mkMerge;
in
{
  options.profile.apps = {
    ghostty.enable = mkOption { type = types.bool; default = true; };
    cmux.enable = mkOption { type = types.bool; default = true; };
    zed.enable = mkOption { type = types.bool; default = true; };
    leaderKey.enable = mkOption { type = types.bool; default = true; };
    yojam.enable = mkOption { type = types.bool; default = true; };
    hammerspoon.enable = mkOption { type = types.bool; default = true; };
    bettertouchtool.enable = mkOption { type = types.bool; default = true; };
    karabiner.enable = mkOption { type = types.bool; default = true; };
    kanata.enable = mkOption { type = types.bool; default = true; };
    borders.enable = mkOption { type = types.bool; default = true; };
    worktrunk.enable = mkOption { type = types.bool; default = true; };
    grm.enable = mkOption { type = types.bool; default = true; };
    gemini.enable = mkOption { type = types.bool; default = true; };
    code.enable = mkOption { type = types.bool; default = true; };
    nvalt.enable = mkOption { type = types.bool; default = true; };
    bin.enable = mkOption { type = types.bool; default = true; };
  };

  config = mkMerge [
    (mkIf config.profile.apps.cmux.enable {
      xdg.configFile."cmux/preferences.json".source =
        ../../../home/dot_config/cmux/preferences.json;
    })

    (mkIf config.profile.apps.zed.enable {
      xdg.configFile."zed/settings.json".source =
        ../../../home/dot_config/zed/settings.json;
    })

    (mkIf config.profile.apps.leaderKey.enable {
      home.file."Library/Application Support/Leader Key".source =
        ../../../home/Library/Application Support/Leader Key;
      home.file."Library/Application Support/Leader Key".recursive = true;
    })

    (mkIf config.profile.apps.bettertouchtool.enable {
      home.file."Library/Application Support/BetterTouchTool".source =
        ../../../home/Library/Application Support/BetterTouchTool;
      home.file."Library/Application Support/BetterTouchTool".recursive = true;
    })

    (mkIf config.profile.apps.karabiner.enable {
      xdg.configFile."karabiner/karabiner.json".source =
        ../../../home/dot_config/karabiner/karabiner.json;
    })

    (mkIf config.profile.apps.kanata.enable {
      xdg.configFile."kanata" = {
        source = ../../../home/dot_config/kanata;
        recursive = true;
      };
    })

    (mkIf config.profile.apps.borders.enable {
      xdg.configFile."borders/bordersrc".source =
        ../../../home/dot_config/borders/bordersrc;
    })

    (mkIf config.profile.apps.worktrunk.enable {
      xdg.configFile."worktrunk/config.toml".source =
        ../../../home/dot_config/worktrunk/config.toml;
    })

    (mkIf config.profile.apps.grm.enable {
      xdg.configFile."grm/config.toml".source =
        ../../../home/dot_config/grm/config.toml;
    })

    (mkIf config.profile.apps.gemini.enable {
      xdg.configFile."gemini-meeting-sync/config.json".source =
        ../../../home/dot_config/gemini-meeting-sync/config.json;
    })

    (mkIf config.profile.apps.code.enable {
      home.file."Library/Application Support/Code".source =
        ../../../home/Library/Application Support/Code;
      home.file."Library/Application Support/Code".recursive = true;
    })

    (mkIf (config.profile.apps.nvalt.enable && config.profile.applyMacosDefaults) {
      # nvALT color list lives under Library/Colors/. The chezmoi side
      # used a modify_ stub that generated the .clr file; if you need the
      # generator, port modify_nvALT.clr.tmpl manually. Until then, we
      # mount the static asset if it exists.
      home.file."Library/Colors/nvALT.clr".source =
        lib.mkIf (builtins.pathExists ../../../home/.chezmoiassets/Library/Colors/nvALT.clr)
          ../../../home/.chezmoiassets/Library/Colors/nvALT.clr;
    })

    (mkIf config.profile.apps.bin.enable {
      # The bin/ tree was 7 symlink_*.tmpl files, each pointing at
      # $DOTFILES/bin/<name>. With nix-darwin's flake-based install, the
      # repo lives at a known place; we materialise each shim as a
      # symlink target via home.file.
      home.file."bin/gh".source = ../../../bin/gh;
      home.file."bin/grmrepo".source = ../../../bin/grmrepo;
      home.file."bin/grmrepo-refresh".source = ../../../bin/grmrepo-refresh;
      home.file."bin/repo-index".source = ../../../bin/repo-index;
      home.file."bin/gemini-meeting-sync".source = ../../../bin/gemini-meeting-sync;
      # skill-search and wt-hook-sparse: the chezmoi templates pointed at
      # `$DOTFILES/bin/<name>`; both exist in the bin/ tree at the repo
      # root and are materialised the same way.
      home.file."bin/wt-hook-sparse".source = ../../../bin/wt-hook-sparse;
      # skill-search lives inside an agent skill package; point at the source.
      home.file."bin/skill-search".source =
        ../../../home/dot_agents/packages/utils-agent/skills/local/skills-searcher/scripts/skill-search;
    })
  ];
}
