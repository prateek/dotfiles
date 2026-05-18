{
  lib,
  config,
  pkgs,
  username,
  ...
}:

# Personal Mac host config. Inherits the `core` / `full` defaults from
# nix/modules/common.nix and the apps modules; override here for any per-host
# tweaks.

{
  # Profile selection (was DOTFILES_INSTALL_PROFILE).
  profile = {
    install = "full";
    installMas = false;
    installXcode = false;
    runInstallScripts = true;
    applyMacosDefaults = true;
    machineType = "personal";
    dotfilesDir = "$HOME/dotfiles";
    # Secrets: refs live in 1Password and are looked up per-machine; the
    # default empty values produce no-op hooks until you fill them in.
    secrets.enabled = false;
    agents.enable = true;
    manageZinitExternal = true;
  };

  # System identity.
  system.primaryUser = username;
  networking.hostName = "prateek-mac";
  networking.computerName = "prateek-mac";

  # Required nix-darwin attributes.
  system.stateVersion = 6;

  # Use Apple Silicon by default; override at the flake level for x86_64.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Define the user. home-manager attaches its modules to this user via the
  # darwinModules.home-manager wiring in flake.nix.
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Enable nix daemon settings; this is conservative — adjust as needed.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
