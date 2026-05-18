{ ... }:

# Single-file dotfiles that don't deserve their own module. vimrc, inputrc,
# lesskey, mcp.json. Each maps a chezmoi-prefixed source to its natural home.

{
  home.file = {
    ".vimrc".source = ../../../home/dot_vimrc;
    ".inputrc".source = ../../../home/dot_inputrc;
    ".lesskey".source = ../../../home/dot_lesskey;
    # The `private_` prefix is dropped here; the file content has no secret,
    # the prefix only meant "don't world-read at the chezmoi target".
    ".mcp.json".source = ../../../home/private_dot_mcp.json;
  };
}
