-- Set leader early
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Base options and user config
require("config.options")
require("config.autocmds")
require("config.keymaps")

-- Bootstrap LazyVim/lazy.nvim via our config loader
require("config.lazy")
