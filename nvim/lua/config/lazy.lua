local fn = vim.fn
local uv = vim.uv or vim.loop

-- Bootstrap lazy.nvim
local lazypath = fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (uv and uv.fs_stat(lazypath)) then
  fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim and its default plugin collection
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- User plugins and overrides
    { import = "plugins" },
  },
  defaults = {
    lazy = false,      -- load plugins during startup by default
    version = false,   -- always use latest git
  },
  install = { colorscheme = { "badwolf", "tokyonight", "catppuccin" } },
  checker = { enabled = true },
})
