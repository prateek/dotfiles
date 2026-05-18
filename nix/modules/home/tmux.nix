{ ... }:

{
  xdg.configFile."tmux" = {
    source = ../../../home/dot_config/tmux;
    recursive = true;
  };
}
