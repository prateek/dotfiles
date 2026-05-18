{ lib, config, ... }:

# Hammerspoon. The source of truth is init.fnl (Fennel); make compiles to
# build/hammerspoon/init.generated.lua. If the compiled file exists, we
# materialise it; otherwise we fall back to the checked-in init.lua.

let
  generated = ../../../build/hammerspoon/init.generated.lua;
  fallback = ../../../home/dot_hammerspoon/init.lua;
  fennel = ../../../home/dot_hammerspoon/init.fnl;
in
{
  home.file.".hammerspoon/init.lua".source =
    if builtins.pathExists generated then generated else fallback;

  home.file.".hammerspoon/init.fnl".source = fennel;
}
