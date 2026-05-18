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

    # BetterTouchTool config is owned by the app itself (huge runtime blob)
    # and is not file-managed by this repo. The license file is written by
    # secrets.nix when a 1Password ref is configured; preferences are
    # merged via the .plist activation hook.

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

    (mkIf config.profile.apps.yojam.enable {
      # Yojam config uses partial-merge semantics (preserve auto-discovered
      # browsers etc.). Activation invokes the yojam-config-merge helper
      # with the desired fragment.
      home.activation.yojamConfigMerge = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        merger="${toString ../../../scripts/merge/yojam-config-merge}"
        fragment="${toString ../../../home/dot_config/yojam/desired-fragment.json}"
        target="$HOME/Library/Application Support/Yojam/config.json"
        if [ -x "$merger" ] && command -v uv >/dev/null 2>&1; then
          run "$merger" "$fragment" "$target" \
            || echo "[home-manager] warn: yojam-config-merge failed." >&2
        fi
      '';
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

    (mkIf config.profile.apps.nvalt.enable {
      # nvALT color list: built from a JSON source via scripts/macos/build-nvalt-colorlist.
      # The .clr is a binary NSKeyedArchiver plist, not a literal file
      # placement candidate.
      home.activation.buildNvaltColorlist = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        builder="${toString ../../../scripts/macos/build-nvalt-colorlist}"
        src="${toString ../../../home/macos/nvalt/nvALT.clr.json}"
        target="$HOME/Library/Colors/nvALT.clr"
        if [ -x "$builder" ] && command -v uv >/dev/null 2>&1; then
          run "$builder" --source "$src" --target "$target" \
            || echo "[home-manager] warn: nvALT colorlist build failed." >&2
        fi
      '';
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
