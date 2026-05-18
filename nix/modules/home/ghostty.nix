{ lib, config, ... }:

# Ghostty config. The per-app enable toggle lives in apps.nix (one place
# for the full per-app map); this module just consumes it.

lib.mkIf config.profile.apps.ghostty.enable {
  xdg.configFile."ghostty" = {
    source = ../../../home/dot_config/ghostty;
    recursive = true;
  };
}
