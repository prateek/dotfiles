{ ... }:

{
  # The repo's gitconfig is a tiny user-block; everything else lives in
  # ~/.config/git/. We mount both verbatim — no need to translate to
  # programs.git.* options because there's nothing else to compose with.
  home.file.".gitconfig".source = ../../../home/dot_gitconfig;

  xdg.configFile."git" = {
    source = ../../../home/dot_config/git;
    recursive = true;
  };
}
