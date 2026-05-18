{
  lib,
  config,
  inputs,
  username,
  ...
}:

let
  data = import ./packages-data.nix;
  profile = data.profiles.${config.profile.install};

  # Normalise the heterogeneous brew/cask entries (strings or attrsets with
  # optional args / link / appdir) to the shape nix-darwin's homebrew module
  # expects. Strings stay strings; attrsets are passed through after
  # translating chezmoi's `appdir` to the homebrew cask `--appdir` arg.
  toBrew =
    item:
    if builtins.isString item then
      item
    else
      { inherit (item) name; }
      // (lib.optionalAttrs (item ? args) { args = item.args; })
      // (lib.optionalAttrs (item ? link) { link = item.link; });

  toCask =
    item:
    if builtins.isString item then
      item
    else
      let
        baseArgs = item.args or [ ];
        withAppdir =
          if item ? appdir then baseArgs ++ [ "--appdir" item.appdir ] else baseArgs;
      in
      { inherit (item) name; }
      // (lib.optionalAttrs (withAppdir != [ ]) { args = withAppdir; })
      // (lib.optionalAttrs (item ? link) { link = item.link; });

  baseBrews = map toBrew profile.brews;
  xcodeBrews =
    lib.optionals (config.profile.installXcode && (profile.xcodeRequiredBrews or [ ]) != [ ])
      (map toBrew profile.xcodeRequiredBrews);
in
{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = username;
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = config.profile.install == "full";
      upgrade = false;
      # Don't yank casks/brews the user installed outside this config during
      # the migration period; flip to "uninstall" once we're confident.
      cleanup = "none";
    };

    taps = profile.taps;
    brews = baseBrews ++ xcodeBrews;
    casks = map toCask profile.casks;

    masApps =
      if config.profile.installMas then
        builtins.listToAttrs (map (m: { name = m.name; value = m.id; }) profile.mas)
      else
        { };
  };

  # gh extensions: nix-darwin's homebrew module doesn't model `gh extension
  # install`. Run them once per name at activation.
  system.activationScripts.ghExtensions.text =
    lib.optionalString config.profile.runInstallScripts ''
      if command -v gh >/dev/null 2>&1; then
        installed="$(gh extension list 2>/dev/null | awk '{print $1}' || true)"
        ${lib.concatMapStringsSep "\n" (ext: ''
          if ! printf '%s\n' "$installed" | grep -qx "${ext}"; then
            echo "[nix-darwin] gh extension install ${ext}"
            sudo -u ${username} gh extension install "${ext}" || \
              echo "[nix-darwin] warn: gh extension install ${ext} failed."
          fi
        '') profile.ghExtensions}
      else
        echo "[nix-darwin] gh not on PATH; skipping gh extensions install." >&2
      fi
    '';
}
