{
  lib,
  config,
  ...
}:

# Secret-backed file activation. Each entry is keyed by a relative path under
# $HOME; `opRef` is a 1Password ref (`op://vault/item/field`). Empty ref →
# skip silently (matches the chezmoi "secret not configured on this machine"
# behaviour). Activation runs `op read` only if `profile.secrets.enabled` is
# true; otherwise none of these files are written.

let
  inherit (lib) optionalString concatStringsSep mapAttrsToList;

  refs = config.profile.secrets.refs;

  # Same path layout as the old chezmoi licenses + private templates.
  files = {
    "Library/Application Support/BetterTouchTool/license.bttlicense" = {
      opRef = refs.bettertouchtool_license or "";
      mode = "0600";
    };
    "Library/Application Support/Many Tricks/Moom/Registration" = {
      opRef = refs.moom_license or "";
      mode = "0600";
    };
    "Library/Application Support/Alfred/License/Alfred.alfredlicense" = {
      opRef = refs.alfred_license or "";
      mode = "0600";
    };
  };

  mkOpHook =
    path: spec:
    optionalString (spec.opRef != "") ''
      target="$HOME/${path}"
      mkdir -p "$(dirname "$target")"
      if command -v op >/dev/null 2>&1; then
        if op read "${spec.opRef}" > "$target.tmp" 2>/dev/null; then
          mv "$target.tmp" "$target"
          chmod ${spec.mode} "$target"
        else
          rm -f "$target.tmp"
          echo "[home-manager] warn: op read failed for ${path}." >&2
        fi
      else
        echo "[home-manager] op not on PATH; skipping ${path}." >&2
      fi
    '';
in
{
  home.activation.opSecrets = lib.mkIf config.profile.secrets.enabled (
    lib.hm.dag.entryAfter [ "linkGeneration" ] (
      concatStringsSep "\n" (mapAttrsToList mkOpHook files)
    )
  );

  # Clone zinit on first activation (was .chezmoiexternal.toml.tmpl). We
  # use a shallow clone with a tag pin behaviour deferred to zinit itself;
  # zinit will fetch its own ecosystem on first use.
  home.activation.cloneZinit = lib.mkIf config.profile.manageZinitExternal (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ZINIT_DIR="''${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}"
      if [ ! -d "$ZINIT_DIR/.git" ]; then
        mkdir -p "$(dirname "$ZINIT_DIR")"
        run git clone --depth=1 https://github.com/zdharma-continuum/zinit.git \
          "$ZINIT_DIR" \
          || echo "[home-manager] warn: zinit clone failed." >&2
      fi
    ''
  );
}
