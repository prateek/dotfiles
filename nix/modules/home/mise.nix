{
  lib,
  config,
  pkgs,
  ...
}:

# mise stays as the runtime/CLI manager. nix materialises the config
# under ~/.config/mise/ and (when runInstallScripts is true) runs
# `mise install` at activation so the runtimes / npm-cli pkgs are present.

{
  xdg.configFile."mise" = {
    source = ../../../home/dot_config/mise;
    recursive = true;
  };

  home.activation.miseInstall =
    lib.mkIf config.profile.runInstallScripts (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if command -v mise >/dev/null 2>&1; then
          run mise install --quiet || echo "[home-manager] warn: mise install failed."
        else
          echo "[home-manager] mise not on PATH; skipping mise install." >&2
        fi
      ''
    );
}
