{ lib, config, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.profile = {
    install = mkOption {
      type = types.enum [
        "core"
        "full"
      ];
      default = "full";
      description = ''
        Package install profile. `core` is the minimum set for a usable Mac
        (formerly `DOTFILES_INSTALL_PROFILE=core`). `full` adds the broader
        developer / multimedia set.
      '';
    };

    installMas = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to install Mac App Store apps via `mas`. Matches the chezmoi
        `DOTFILES_INSTALL_MAS_APPS` opt-in.
      '';
    };

    installXcode = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to install Xcode (via `xcodes`) and the Xcode-only brews.
        Matches `DOTFILES_INSTALL_XCODE`.
      '';
    };

    runInstallScripts = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run install-side scripts (Homebrew bundle, mise install, gh extensions,
        skill renderers, plist merges) at activation. False makes activation a
        pure file-placement pass.
      '';
    };

    applyMacosDefaults = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Apply the `nix-darwin.system.defaults` block plus the imperative
        post-defaults activation (pmset, nvram, mdutil, inline plists).
      '';
    };

    machineType = mkOption {
      type = types.enum [
        "personal"
        "homelab"
        "work"
      ];
      default = "personal";
      description = ''
        Drives the elevation hook. Only `work` uses `jamf-self-service`.
      '';
    };

    elevation = {
      method = mkOption {
        type = types.enum [
          "none"
          "jamf-self-service"
        ];
        default = if config.profile.machineType == "work" then "jamf-self-service" else "none";
        description = ''
          Admin elevation method. nix-darwin activation runs as root via
          `sudo darwin-rebuild`, so this is only relevant for the optional
          mise / brew side-steps that need user sudo on Jamf-managed Macs.
        '';
      };

      jamfPolicyId = mkOption {
        type = types.str;
        default = "";
        description = "Jamf Self Service policy ID for temp admin elevation.";
      };
    };

    dotfilesDir = mkOption {
      type = types.str;
      default = "$HOME/dotfiles";
      description = ''
        Where this repo lives at runtime. Exposed as $DOTFILES in zshenv so
        scripts and editor configs can resolve it without hard-coding.
      '';
    };

    secrets = {
      enabled = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to write secret-backed files (licenses, private app configs)
          using 1Password `op://` refs at activation time. Off by default;
          turn on per-machine in the host config.
        '';
      };

      refs = mkOption {
        type = types.attrsOf types.str;
        default = {
          bettertouchtool_license = "";
          moom_license = "";
          alfred_license = "";
        };
        description = ''
          1Password `op://` references keyed by name. Empty value means
          "not configured" — the consumer skips that file silently.
          Override per-host with real refs.
        '';
      };
    };

    licenses = {
      paths = mkOption {
        type = types.listOf types.str;
        default = [
          "Library/Application Support/BetterTouchTool/license.bttlicense"
          "Library/Application Support/Many Tricks/Moom/Registration"
          "Library/Application Support/Alfred/License/Alfred.alfredlicense"
        ];
        description = ''
          Target paths (relative to $HOME) of license files materialized
          via 1Password refs. Mirrors the old `licenses.toml > paths`.
        '';
      };
    };

    manageZinitExternal = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Clone the zinit repo to ~/.local/share/zinit/zinit.git at
        activation. The chezmoi equivalent was a `.chezmoiexternal.toml`
        git-repo source. nix has no good "vendor a runtime git tree" verb;
        we use a home.activation hook with `refreshPeriod` semantics.
      '';
    };

    agents = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Render the agent skills (`~/.agents/skills`, `~/.claude/skills`)
          and plugin marketplace (`~/.agents/plugins`) on activation. Calls
          the Python renderers under
          `.agents/skills/agent-skill-management/scripts/`.
        '';
      };
    };
  };
}
