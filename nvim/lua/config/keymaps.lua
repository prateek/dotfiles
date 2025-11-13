local map = vim.keymap.set
local silent = { silent = true, noremap = true }

-- Swap : and ; like your vimrc
map({ "n", "x", "o" }, ";", ":", { noremap = true })
map({ "n", "x", "o" }, ":", ";", { noremap = true })

-- Window navigation with Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h", silent)
map("n", "<C-j>", "<C-w>j", silent)
map("n", "<C-k>", "<C-w>k", silent)
map("n", "<C-l>", "<C-w>l", silent)

-- Use display lines for j/k
map("n", "j", "gj", silent)
map("n", "k", "gk", silent)
map("n", "gk", "k", silent)
map("n", "gj", "j", silent)

-- Toggle fold (your iTerm remap to <C-U>)
map("n", "<C-U>", "za", silent)

-- Clear search with Enter
map("n", "<CR>", ":nohlsearch<CR>", { silent = true })

-- Quick substitution S (global) for normal and visual
map("n", "S", ":%s//g<LEFT><LEFT>")
map("x", "S", ":s//g<LEFT><LEFT>")

-- Visually select last edited/pasted text
map("n", "gp", "`[v`]")

-- Neotree mappings in place of NERDTree
map("n", "<leader>n", ":Neotree toggle<CR>", { desc = "Toggle file tree", silent = true })
map("n", "<leader>r", ":Neotree reveal<CR>", { desc = "Reveal file in tree", silent = true })

-- Reveal in Finder (plugin)
map("n", "<leader>e", ":Reveal<CR>", { desc = "Reveal in Finder", silent = true })

-- Telescope in place of CtrlP
map("n", "<C-p>", function()
  require("telescope.builtin").find_files({ hidden = true })
end, { desc = "Files" })

-- Flash jump like EasyMotion
map("n", "<C-s>", function()
  pcall(function()
    require("flash").jump()
  end)
end, { desc = "Flash jump" })

-- Change to current file's directory
map("n", "<leader>c", ":cd %:p:h<CR>", { desc = "cd to file dir", silent = true })

-- Edit config quickly
map("n", "cv", ":sp $MYVIMRC<CR>", { desc = "Edit init.lua", silent = true })

-- Lazy equivalents for Plug mappings
map("n", "<leader>pi", ":Lazy<CR>", { desc = "Lazy (plugins)", silent = true })
map("n", "<leader>pu", ":Lazy sync<CR>", { desc = "Lazy sync", silent = true })
map("n", "<leader>pc", ":Lazy clean<CR>", { desc = "Lazy clean", silent = true })

-- Toggle indent guides (IBL is default in LazyVim)
map("n", "coi", function()
  vim.cmd("IBLToggle")
end, { desc = "Toggle indent guides" })

-- Swap visual modes (v and <C-v>) like your vimrc
map("n", "v", "<C-v>", { noremap = true })
map("n", "<C-v>", "v", { noremap = true })

