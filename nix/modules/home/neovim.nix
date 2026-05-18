{ ... }:

{
  xdg.configFile."nvim" = {
    source = ../../../home/dot_config/nvim;
    recursive = true;
  };
}
