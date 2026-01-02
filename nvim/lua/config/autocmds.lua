local aug = vim.api.nvim_create_augroup
local auc = vim.api.nvim_create_autocmd

-- Treat .hql as SQL
auc({ "BufNewFile", "BufRead" }, {
  group = aug("filetypes_custom", { clear = true }),
  pattern = "*.hql",
  callback = function()
    vim.bo.filetype = "sql"
  end,
})

-- Fast escape timings (match your vimrc behavior)
local grp = aug("fast_escape", { clear = true })
auc("InsertEnter", { group = grp, callback = function() vim.opt.timeoutlen = 0 end })
auc("InsertLeave", { group = grp, callback = function() vim.opt.timeoutlen = 1000 end })

-- Auto-reload when saving init.lua
auc("BufWritePost", {
  group = aug("nvim_reload", { clear = true }),
  pattern = vim.fn.expand("$MYVIMRC"),
  command = "source $MYVIMRC",
})

-- Prefer absolute line numbers by default (LazyVim defaults to relative)
auc("VimEnter", {
  group = aug("line_numbers_default", { clear = true }),
  callback = function()
    vim.opt.number = true
    vim.opt.relativenumber = false
  end,
})

-- Map <C-e> to run quick scripts via :Dispatch for specific filetypes
local ft_stdout = {
  bash = "bash",
  javascript = "node",
  nodejs = "node",
  perl = "perl",
  php = "php",
  python = "python",
  ruby = "ruby",
  sh = "sh",
}
local ft_exec = {
  c = "gcc -o %:r -Wall -std=c99 % && ./%:r",
  markdown = "open -app Marked2.app %",
  applescript = "osascript %",
}

for ft, cmd in pairs(ft_stdout) do
  auc("FileType", {
    pattern = ft,
    callback = function()
      vim.keymap.set("n", "<C-e>", ":Dispatch " .. cmd .. " %<CR>", { buffer = true, silent = true })
    end,
  })
end
for ft, cmd in pairs(ft_exec) do
  auc("FileType", {
    pattern = ft,
    callback = function()
      vim.keymap.set("n", "<C-e>", ":Dispatch " .. cmd .. "<CR>", { buffer = true, silent = true })
    end,
  })
end
