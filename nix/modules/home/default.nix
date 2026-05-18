{ ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./tools.nix
    ./mise.nix
    ./tmux.nix
    ./ghostty.nix
    ./neovim.nix
    ./hammerspoon.nix
    ./agents.nix
    ./apps.nix
    ./secrets.nix
  ];

  home.stateVersion = "24.11";
}
