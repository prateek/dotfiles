{ lib, config, ... }:

# Pre-activation hook: warn (and refuse) if any managed plist would change
# while its app is currently running. In nix-darwin this runs as part of
# `darwin-rebuild switch` — the operator can flip DOTFILES_SKIP_PLIST_HOOKS=1
# to force.
#
# The chezmoi version of this hook lived in scripts/chezmoi-hooks/, which now
# moves to scripts/hooks/. We invoke the script directly so the logic stays
# in one place rather than rewriting it in nix string-pkgs.

let
  inherit (lib) optionalString;
  guardScript = ../../../scripts/hooks/guard-running-apps.sh;
  postScript = ../../../scripts/hooks/post-apply-plists.sh;
in
{
  system.activationScripts.guardRunningApps.text =
    optionalString config.profile.applyMacosDefaults ''
      if [ "''${DOTFILES_SKIP_PLIST_HOOKS:-0}" != "1" ] && [ -x "${toString guardScript}" ]; then
        "${toString guardScript}" || true
      fi
    '';

  system.activationScripts.postApplyPlists.text =
    optionalString config.profile.applyMacosDefaults ''
      if [ "''${DOTFILES_SKIP_PLIST_HOOKS:-0}" != "1" ] && [ -x "${toString postScript}" ]; then
        "${toString postScript}" || true
      fi
    '';
}
