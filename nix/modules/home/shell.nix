{
  lib,
  config,
  pkgs,
  ...
}:

# Shell startup. Almost everything lives in literal files under
# home/dot_config/zsh/; home-manager mounts the directory wholesale via
# xdg.configFile. The only generated file is .zshenv, which has one
# templated value (the dotfiles dir).

let
  zshSrcDir = ../../../home/dot_config/zsh;
  orcaZshrc = ../../../home/dot_zshrc;
in
{
  programs.zsh = {
    enable = true;
    # We manage everything via the files below — don't let home-manager
    # generate a default ~/.zshrc that would conflict.
    dotDir = ".config/zsh";
    # Suppress home-manager's auto-generated content; the real config lives
    # in $ZDOTDIR/.zshrc (managed by xdg.configFile below).
    initContent = "";
    envExtra = "";
  };

  # Replace home-manager's generated .zshenv with our XDG-aware version.
  home.file.".zshenv".text = ''
    # vim:syntax=zsh
    # vim:filetype=zsh
    export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"

    export DOTFILES="''${DOTFILES:-${config.profile.dotfilesDir}}"
    export ZDOTDIR="''${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
    export ZSHCONFIG="''${ZSHCONFIG:-$ZDOTDIR}"

    if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "$ZDOTDIR/.zprofile" ]]; then
      source "$ZDOTDIR/.zprofile"
    fi
  '';

  # Orca shell-ready wrapper workaround (see commentary inside the file).
  home.file.".zshrc".source = orcaZshrc;

  # Whole-tree mount of the zsh config dir. Recursive sources go via
  # readonly symlinks; the inner `dot_*` files were renamed to `.*` on
  # disk so they materialise correctly.
  xdg.configFile."zsh" = {
    source = zshSrcDir;
    recursive = true;
  };
}
